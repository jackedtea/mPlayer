// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

/// Everything the Player and Subtitle settings pages control.
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
    this.swipeGestures = true,
    this.subtitleTextScale = 1.0,
    this.subtitleBackgroundOpacity = 0.55,
    this.subtitleColour = const Color(0xFFFFFFFF),
    this.subtitleDelay = Duration.zero,
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
      swipeGestures: json['swipeGestures'] as bool? ?? true,
      subtitleTextScale:
          (json['subtitleTextScale'] as num?)?.toDouble() ?? 1.0,
      subtitleBackgroundOpacity:
          (json['subtitleBackgroundOpacity'] as num?)?.toDouble() ?? 0.55,
      subtitleColour: Color(json['subtitleColour'] as int? ?? 0xFFFFFFFF),
      subtitleDelay:
          Duration(milliseconds: json['subtitleDelayMs'] as int? ?? 0),
    );
  }

  final HardwareDecoding hardwareDecoding;
  final Duration skipBack;
  final Duration skipForward;
  final bool autoPlayNext;
  final bool autoSkipIntro;

  /// Brightness and volume drags. Off makes the player ignore them entirely.
  final bool swipeGestures;

  final double subtitleTextScale;
  final double subtitleBackgroundOpacity;
  final Color subtitleColour;
  final Duration subtitleDelay;

  /// mpv's default subtitle size, which the scale multiplies.
  static const _baseSubtitleSize = 55;

  int get mpvSubtitleFontSize =>
      (_baseSubtitleSize * subtitleTextScale).round().clamp(10, 200);

  /// mpv wants `#AARRGGBB`.
  String get mpvSubtitleColour => _mpvColour(subtitleColour, 1);

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
        'swipeGestures': swipeGestures,
        'subtitleTextScale': subtitleTextScale,
        'subtitleBackgroundOpacity': subtitleBackgroundOpacity,
        'subtitleColour': subtitleColour.toARGB32(),
        'subtitleDelayMs': subtitleDelay.inMilliseconds,
      };

  PlayerSettings copyWith({
    HardwareDecoding? hardwareDecoding,
    Duration? skipBack,
    Duration? skipForward,
    bool? autoPlayNext,
    bool? autoSkipIntro,
    bool? swipeGestures,
    double? subtitleTextScale,
    double? subtitleBackgroundOpacity,
    Color? subtitleColour,
    Duration? subtitleDelay,
  }) {
    return PlayerSettings(
      hardwareDecoding: hardwareDecoding ?? this.hardwareDecoding,
      skipBack: skipBack ?? this.skipBack,
      skipForward: skipForward ?? this.skipForward,
      autoPlayNext: autoPlayNext ?? this.autoPlayNext,
      autoSkipIntro: autoSkipIntro ?? this.autoSkipIntro,
      swipeGestures: swipeGestures ?? this.swipeGestures,
      subtitleTextScale: subtitleTextScale ?? this.subtitleTextScale,
      subtitleBackgroundOpacity:
          subtitleBackgroundOpacity ?? this.subtitleBackgroundOpacity,
      subtitleColour: subtitleColour ?? this.subtitleColour,
      subtitleDelay: subtitleDelay ?? this.subtitleDelay,
    );
  }
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
