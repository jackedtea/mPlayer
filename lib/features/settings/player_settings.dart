// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../servers/media_library_source.dart';

/// How mpv should pick a decoder.
enum HardwareDecoding {
  auto('Auto (safe)', 'auto-safe'),
  yes('Prefer hardware', 'auto'),
  no('Software only', 'no');

  const HardwareDecoding(this.label, this.mpvValue);

  final String label;

  /// What `hwdec` is set to. `auto-safe` is mpv's own conservative pick.
  final String mpvValue;
}

/// How hard mpv should try to play one file into the next without a gap.
///
/// Three states rather than a switch because mpv has three, and the middle
/// one is its default: gapless only where the next file's format matches, so
/// nothing has to be reinitialised. Forcing it always can resample.
enum GaplessAudio {
  off('no'),
  automatic('weak'),
  always('yes');

  const GaplessAudio(this.mpvValue);

  final String mpvValue;
}

/// What to do when playback reaches a stretch the server has labelled.
///
/// Three states rather than a switch because skipping silently and offering
/// to skip are genuinely different products: one is for a viewer rewatching a
/// series who never wants to see the titles again, the other for someone who
/// would rather be asked.
enum SegmentAction {
  /// Leave it alone. Nothing appears and nothing seeks.
  nothing,

  /// Show a pill for as long as the segment lasts; seek only if it is
  /// pressed.
  askToSkip,

  /// Seek past it the moment playback runs into it.
  ///
  /// **Only when playing into it**, never when the user seeks in. Someone who
  /// drags the scrubber into the opening titles meant to be there, and
  /// bouncing them straight back out is a player fighting its user.
  skip,
}

/// What each kind of segment does, out of the box.
///
/// Intro and outro ask; the rest do nothing. The two the user has an opinion
/// about are the two worth interrupting for, and a recap or a preview seeking
/// itself away on a first watch is a scene the viewer never got to decide
/// about.
const defaultSegmentActions = <MediaSegmentKind, SegmentAction>{
  MediaSegmentKind.intro: SegmentAction.askToSkip,
  MediaSegmentKind.outro: SegmentAction.askToSkip,
  MediaSegmentKind.preview: SegmentAction.nothing,
  MediaSegmentKind.recap: SegmentAction.nothing,
  MediaSegmentKind.commercial: SegmentAction.nothing,
};

/// A segment shorter than this is never seeked past.
///
/// A one-second jump costs a decoder more than it saves the viewer: the
/// picture stalls, the audio re-syncs, and the thing being skipped was over
/// before either finished.
const minimumSkippableSegment = Duration(seconds: 1);

/// Everything the Player, Audio and Subtitle settings pages control.
///
/// One object rather than a scattering of keys so the player reads a single
/// value and nothing can drift out of step. Persisted as JSON in
/// `shared_preferences`; the Drift schema is still ahead of us and this is a
/// handful of scalars.
@immutable
class PlayerSettings {
  const PlayerSettings({
    this.hardwareDecoding = HardwareDecoding.auto,
    this.skipBack = const Duration(seconds: 10),
    this.skipForward = const Duration(seconds: 30),
    this.autoPlayNext = true,
    this.autoSkipIntro = false,
    this.segmentActions = defaultSegmentActions,
    this.swipeGestures = true,
    this.pipOnLeave = false,
    this.backgroundAudio = false,
    this.preferredLanguage,
    this.smartSubtitles = true,
    this.subtitleTextScale = 1.0,
    this.subtitleBackgroundOpacity = 0.55,
    this.subtitleColour = const Color(0xFFFFFFFF),
    this.subtitleDelay = Duration.zero,
    this.audioDelay = Duration.zero,
    this.audioPassthrough = false,
    this.volumeBoost = 100,
    this.gapless = GaplessAudio.automatic,
  });

  factory PlayerSettings.fromJson(Map<String, dynamic> json) {
    return PlayerSettings(
      hardwareDecoding: HardwareDecoding.values.firstWhere(
        (h) => h.name == json['hardwareDecoding'],
        orElse: () => HardwareDecoding.auto,
      ),
      skipBack: Duration(seconds: json['skipBackSeconds'] as int? ?? 10),
      skipForward: Duration(seconds: json['skipForwardSeconds'] as int? ?? 30),
      autoPlayNext: json['autoPlayNext'] as bool? ?? true,
      autoSkipIntro: json['autoSkipIntro'] as bool? ?? false,
      segmentActions: _segmentActionsFromJson(json['segmentActions']),
      swipeGestures: json['swipeGestures'] as bool? ?? true,
      pipOnLeave: json['pipOnLeave'] as bool? ?? false,
      backgroundAudio: json['backgroundAudio'] as bool? ?? false,
      preferredLanguage: json['preferredLanguage'] as String?,
      smartSubtitles: json['smartSubtitles'] as bool? ?? true,
      subtitleTextScale:
          (json['subtitleTextScale'] as num?)?.toDouble() ?? 1.0,
      subtitleBackgroundOpacity:
          (json['subtitleBackgroundOpacity'] as num?)?.toDouble() ?? 0.55,
      subtitleColour: Color(json['subtitleColour'] as int? ?? 0xFFFFFFFF),
      subtitleDelay:
          Duration(milliseconds: json['subtitleDelayMs'] as int? ?? 0),
      audioDelay: Duration(milliseconds: json['audioDelayMs'] as int? ?? 0),
      audioPassthrough: json['audioPassthrough'] as bool? ?? false,
      volumeBoost: json['volumeBoost'] as int? ?? 100,
      gapless: GaplessAudio.values.firstWhere(
        (g) => g.name == json['gapless'],
        orElse: () => GaplessAudio.automatic,
      ),
    );
  }

  final HardwareDecoding hardwareDecoding;
  final Duration skipBack;
  final Duration skipForward;
  final bool autoPlayNext;
  final bool autoSkipIntro;

  /// What to do about each kind of server-supplied segment.
  ///
  /// Separate from [autoSkipIntro], which governs the *container* heuristic —
  /// a chapter a rip happened to name "Opening". The two never both fire on
  /// one file: a source that supplies segments supplies the authority with
  /// them, and the heuristic stands down.
  final Map<MediaSegmentKind, SegmentAction> segmentActions;

  /// What to do with a segment of [kind], defaulting to leaving it alone.
  SegmentAction actionFor(MediaSegmentKind kind) =>
      segmentActions[kind] ?? SegmentAction.nothing;

  /// Brightness and volume drags. Off makes the player ignore them entirely.
  final bool swipeGestures;

  /// Shrink into a picture-in-picture window when the user leaves mid-play.
  /// Android only; inert everywhere else.
  ///
  /// **Off by default.** A window that follows you out of the app is a
  /// surprise the first time it happens, and the setting is there for people
  /// who want it rather than a behaviour to be opted out of.
  final bool pipOnLeave;

  /// Keep playing with the screen off or the app in the background, with a
  /// media notification to control it.
  ///
  /// Off by default for the same reason: leaving a video player should stop
  /// the video. Turning this on is a deliberate choice, and the notification
  /// then makes it obvious and controllable.
  final bool backgroundAudio;

  /// Canonical language code the user reads in — see `core/languages.dart`.
  /// Null means no preference, which turns [smartSubtitles] off with it.
  final String? preferredLanguage;

  /// Subtitles on only when the audio is *not* in [preferredLanguage].
  ///
  /// The point of the pairing: a film in your own language should play
  /// without subtitles, and a foreign one should turn them on by itself.
  final bool smartSubtitles;

  final double subtitleTextScale;
  final double subtitleBackgroundOpacity;
  final Color subtitleColour;
  final Duration subtitleDelay;

  /// Shifts the audio against the video, for a file whose streams were muxed
  /// out of step. Positive plays the audio later.
  final Duration audioDelay;

  /// Send AC3/DTS/E-AC3/TrueHD to the amplifier untouched instead of decoding
  /// them here.
  ///
  /// Off by default, and it has to be: a device with no receiver on the other
  /// end of the cable plays **silence**, which is a worse first impression
  /// than a downmix nobody asked for.
  final bool audioPassthrough;

  /// Ceiling for the volume slider, as a percentage. 100 is the recorded
  /// level; above it mpv amplifies, which is what rescues a quiet film.
  final int volumeBoost;

  final GaplessAudio gapless;

  /// mpv's default subtitle size, which the scale multiplies.
  static const _baseSubtitleSize = 55;

  int get mpvSubtitleFontSize =>
      (_baseSubtitleSize * subtitleTextScale).round().clamp(10, 200);

  /// mpv wants `#AARRGGBB`.
  String get mpvSubtitleColour => _mpvColour(subtitleColour, 1);

  /// The formats handed to the amplifier untouched, or an empty list.
  ///
  /// Only lossy-or-bitstreamable codecs are listed: mpv passes these through
  /// as-is, and anything else it must decode anyway.
  String get mpvSpdif => audioPassthrough ? 'ac3,dts,eac3,truehd' : '';

  String get mpvSubtitleBackColour =>
      _mpvColour(const Color(0xFF000000), subtitleBackgroundOpacity);

  static String _mpvColour(Color colour, double opacity) {
    final a = (opacity.clamp(0.0, 1.0) * 255).round();
    final r = (colour.r * 255).round();
    final g = (colour.g * 255).round();
    final b = (colour.b * 255).round();
    String hex(int v) => v.toRadixString(16).padLeft(2, '0').toUpperCase();
    return '#${hex(a)}${hex(r)}${hex(g)}${hex(b)}';
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'hardwareDecoding': hardwareDecoding.name,
        'skipBackSeconds': skipBack.inSeconds,
        'skipForwardSeconds': skipForward.inSeconds,
        'autoPlayNext': autoPlayNext,
        'autoSkipIntro': autoSkipIntro,
        'segmentActions': <String, String>{
          for (final MapEntry<MediaSegmentKind, SegmentAction> e
              in segmentActions.entries)
            e.key.name: e.value.name,
        },
        'swipeGestures': swipeGestures,
        'pipOnLeave': pipOnLeave,
        'backgroundAudio': backgroundAudio,
        'preferredLanguage': preferredLanguage,
        'smartSubtitles': smartSubtitles,
        'subtitleTextScale': subtitleTextScale,
        'subtitleBackgroundOpacity': subtitleBackgroundOpacity,
        'subtitleColour': subtitleColour.toARGB32(),
        'subtitleDelayMs': subtitleDelay.inMilliseconds,
        'audioDelayMs': audioDelay.inMilliseconds,
        'audioPassthrough': audioPassthrough,
        'volumeBoost': volumeBoost,
        'gapless': gapless.name,
      };

  PlayerSettings copyWith({
    HardwareDecoding? hardwareDecoding,
    Duration? skipBack,
    Duration? skipForward,
    bool? autoPlayNext,
    bool? autoSkipIntro,
    Map<MediaSegmentKind, SegmentAction>? segmentActions,
    bool? swipeGestures,
    bool? pipOnLeave,
    bool? backgroundAudio,
    String? preferredLanguage,
    bool? clearPreferredLanguage,
    bool? smartSubtitles,
    double? subtitleTextScale,
    double? subtitleBackgroundOpacity,
    Color? subtitleColour,
    Duration? subtitleDelay,
    Duration? audioDelay,
    bool? audioPassthrough,
    int? volumeBoost,
    GaplessAudio? gapless,
  }) {
    return PlayerSettings(
      hardwareDecoding: hardwareDecoding ?? this.hardwareDecoding,
      skipBack: skipBack ?? this.skipBack,
      skipForward: skipForward ?? this.skipForward,
      autoPlayNext: autoPlayNext ?? this.autoPlayNext,
      autoSkipIntro: autoSkipIntro ?? this.autoSkipIntro,
      segmentActions: segmentActions ?? this.segmentActions,
      swipeGestures: swipeGestures ?? this.swipeGestures,
      pipOnLeave: pipOnLeave ?? this.pipOnLeave,
      backgroundAudio: backgroundAudio ?? this.backgroundAudio,
      // "No preference" has to be expressible, and a null argument already
      // means "leave it alone" for every other field here.
      preferredLanguage: clearPreferredLanguage ?? false
          ? null
          : preferredLanguage ?? this.preferredLanguage,
      smartSubtitles: smartSubtitles ?? this.smartSubtitles,
      subtitleTextScale: subtitleTextScale ?? this.subtitleTextScale,
      subtitleBackgroundOpacity:
          subtitleBackgroundOpacity ?? this.subtitleBackgroundOpacity,
      subtitleColour: subtitleColour ?? this.subtitleColour,
      subtitleDelay: subtitleDelay ?? this.subtitleDelay,
      audioDelay: audioDelay ?? this.audioDelay,
      audioPassthrough: audioPassthrough ?? this.audioPassthrough,
      volumeBoost: volumeBoost ?? this.volumeBoost,
      gapless: gapless ?? this.gapless,
    );
  }
}

/// Restores the action map, falling back per key rather than wholesale.
///
/// A stored map written before a segment kind existed is missing that key,
/// not corrupt — dropping the whole map for it would silently reset choices
/// the user made about the other four.
Map<MediaSegmentKind, SegmentAction> _segmentActionsFromJson(Object? raw) {
  if (raw is! Map) return defaultSegmentActions;

  return <MediaSegmentKind, SegmentAction>{
    for (final MediaSegmentKind kind in supportedSegmentKinds)
      kind: SegmentAction.values.firstWhere(
        (a) => a.name == raw[kind.name],
        orElse: () =>
            defaultSegmentActions[kind] ?? SegmentAction.nothing,
      ),
  };
}

final playerSettingsProvider =
    NotifierProvider<PlayerSettingsController, PlayerSettings>(
  PlayerSettingsController.new,
);

class PlayerSettingsController extends Notifier<PlayerSettings> {
  static const _prefsKey = 'player_settings_v1';

  @override
  PlayerSettings build() {
    // Defaults render immediately; the stored values arrive a frame later
    // rather than blocking the first paint.
    Future<void>.microtask(_restore);
    return const PlayerSettings();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return;

    try {
      state = PlayerSettings.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (e) {
      // Settings written by a newer build must not stop the app starting.
      debugPrint('Unreadable player settings, using defaults: $e');
    }
  }

  Future<void> update(PlayerSettings settings) async {
    state = settings;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(settings.toJson()));
  }
}
