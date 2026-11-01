// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

/// The audio and subtitle tracks a viewer picked by hand, carried to the
/// next file of the same series — and to the same film opened again.
///
/// Without this every new file came up on libmpv's own choice, "auto", which
/// is whatever the muxer flagged: a viewer who switched episode one to the
/// Japanese audio with English subtitles did it again on episode two, and on
/// every episode after. Jellyfin's own clients remember per series, and so
/// does this.
///
/// Kept by language and title, not by track index: index 2 is Japanese in
/// one file and commentary in the next, while "jpn" and "Signs & Songs" mean
/// the same thing across a season.
library;

import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/languages.dart';
import 'playback_state.dart';

/// One remembered track: what it was called, or that subtitles were off.
@immutable
class RememberedTrack {
  const RememberedTrack({this.language, this.title = '', this.off = false});

  const RememberedTrack.off() : language = null, title = '', off = true;

  factory RememberedTrack.of(MediaTrack track) => RememberedTrack(
    language: canonicalLanguage(track.language),
    title: track.label,
  );

  factory RememberedTrack.fromJson(Map<String, dynamic> json) =>
      RememberedTrack(
        language: json['language'] as String?,
        title: json['title'] as String? ?? '',
        off: json['off'] as bool? ?? false,
      );

  /// Canonical two-letter code, or null when the track did not say.
  final String? language;
  final String title;

  /// Subtitles switched off on purpose — remembered too, or an episode whose
  /// muxer flagged a default subtitle would switch them back on.
  final bool off;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'language': language,
    'title': title,
    'off': off,
  };

  @override
  bool operator ==(Object other) =>
      other is RememberedTrack &&
      other.language == language &&
      other.title == title &&
      other.off == off;

  @override
  int get hashCode => Object.hash(language, title, off);
}

/// What was picked for one series or film.
@immutable
class RememberedTracks {
  const RememberedTracks({this.audio, this.subtitle});

  factory RememberedTracks.fromJson(Map<String, dynamic> json) {
    RememberedTrack? read(Object? v) =>
        v is Map<String, dynamic> ? RememberedTrack.fromJson(v) : null;
    return RememberedTracks(
      audio: read(json['audio']),
      subtitle: read(json['subtitle']),
    );
  }

  final RememberedTrack? audio;
  final RememberedTrack? subtitle;

  Map<String, dynamic> toJson() => <String, dynamic>{
    if (audio != null) 'audio': audio!.toJson(),
    if (subtitle != null) 'subtitle': subtitle!.toJson(),
  };
}

/// The track in [tracks] that [remembered] means, or null for none.
///
/// The same title in the same language first — "English (SDH)" over plain
/// "English" when that is what was picked — then the language alone. A
/// remembered track with no language matches by title only, and a language
/// the file does not carry matches nothing: switching to a stranger track
/// would be worse than leaving the file's own choice.
MediaTrack? matchRemembered(
  List<MediaTrack> tracks,
  RememberedTrack remembered,
) {
  final real = tracks.where((t) => !t.isAuto && !t.isOff).toList();

  final exact = real.firstWhereOrNull(
    (t) =>
        t.label == remembered.title &&
        canonicalLanguage(t.language) == remembered.language,
  );
  if (exact != null) return exact;

  final language = remembered.language;
  if (language == null) {
    return real.firstWhereOrNull((t) => t.label == remembered.title);
  }
  return real.firstWhereOrNull(
    (t) => canonicalLanguage(t.language) == language,
  );
}

/// Remembered choices, keyed by series id for an episode and by item id for
/// anything else.
final rememberedTracksProvider =
    AsyncNotifierProvider<
      RememberedTracksController,
      Map<String, RememberedTracks>
    >(RememberedTracksController.new);

class RememberedTracksController
    extends AsyncNotifier<Map<String, RememberedTracks>> {
  static const _prefsKey = 'remembered_tracks_v1';

  /// Enough for every series anyone is part-way through, without the list
  /// growing for ever; the least recently changed go first.
  static const limit = 200;

  @override
  Future<Map<String, RememberedTracks>> build() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return const <String, RememberedTracks>{};
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return <String, RememberedTracks>{
        for (final MapEntry<String, dynamic> e in decoded.entries)
          if (e.value is Map<String, dynamic>)
            e.key: RememberedTracks.fromJson(e.value as Map<String, dynamic>),
      };
    } catch (e) {
      // A damaged entry costs the viewer one re-pick, not the player.
      debugPrint('Unreadable remembered tracks: $e');
      return const <String, RememberedTracks>{};
    }
  }

  Future<RememberedTracks?> forGroup(String group) async =>
      (await future)[group];

  /// "Auto" forgets the audio, handing the choice back to the file.
  Future<void> rememberAudio(String group, MediaTrack track) => _update(
    group,
    (old) => RememberedTracks(
      audio: track.isAuto ? null : RememberedTrack.of(track),
      subtitle: old?.subtitle,
    ),
  );

  /// Null, or the "no" track, remembers subtitles off.
  Future<void> rememberSubtitle(String group, MediaTrack? track) => _update(
    group,
    (old) => RememberedTracks(
      audio: old?.audio,
      subtitle: track == null || track.isOff
          ? const RememberedTrack.off()
          : RememberedTrack.of(track),
    ),
  );

  Future<void> _update(
    String group,
    RememberedTracks Function(RememberedTracks? old) change,
  ) async {
    final current = await future;
    // Re-inserted, so the most recently changed sit at the end and the cap
    // drops the stalest.
    final next = <String, RememberedTracks>{
      for (final MapEntry<String, RememberedTracks> e in current.entries)
        if (e.key != group) e.key: e.value,
      group: change(current[group]),
    };
    while (next.length > limit) {
      next.remove(next.keys.first);
    }
    state = AsyncValue<Map<String, RememberedTracks>>.data(next);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode(<String, dynamic>{
        for (final MapEntry<String, RememberedTracks> e in next.entries)
          e.key: e.value.toJson(),
      }),
    );
  }
}
