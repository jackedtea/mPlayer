// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme.dart';

/// The design's four accent presets. The first is the app's own seed, and
/// picking it puts the spec's pinned palette back — see [buildTheme].
const accentPresets = <Color>[
  seedColor,
  Color(0xFF00629E),
  Color(0xFF00696E),
  Color(0xFF6750A4),
];

/// Everything screen 1m (Appearance) controls.
///
/// One object persisted as a single JSON key, the same shape
/// `PlayerSettings` uses — the app reads one value and nothing can drift out
/// of step between the theme and the page that edits it.
@immutable
class AppearanceSettings {
  const AppearanceSettings({
    this.mode = ThemeMode.system,
    this.accentIndex = 0,
    this.dynamicColour = false,
    this.pureBlack = false,
  });

  factory AppearanceSettings.fromJson(Map<String, dynamic> json) {
    return AppearanceSettings(
      mode: ThemeMode.values.firstWhere(
        (m) => m.name == json['mode'],
        orElse: () => ThemeMode.system,
      ),
      // An index written by a build with more presets must not throw.
      accentIndex: switch (json['accentIndex']) {
        final int i when i >= 0 && i < accentPresets.length => i,
        _ => 0,
      },
      dynamicColour: json['dynamicColour'] as bool? ?? false,
      pureBlack: json['pureBlack'] as bool? ?? false,
    );
  }

  /// Light / dark / follow the system.
  final ThemeMode mode;

  /// Index into [accentPresets]. Ignored while [dynamicColour] is on.
  final int accentIndex;

  /// Seed the scheme from the system wallpaper instead. Only Android 12+
  /// supplies one; everywhere else this falls back to [accent].
  final bool dynamicColour;

  /// True black surfaces in dark mode, for OLED screens.
  final bool pureBlack;

  Color get accent => accentPresets[accentIndex];

  Map<String, dynamic> toJson() => <String, dynamic>{
        'mode': mode.name,
        'accentIndex': accentIndex,
        'dynamicColour': dynamicColour,
        'pureBlack': pureBlack,
      };

  AppearanceSettings copyWith({
    ThemeMode? mode,
    int? accentIndex,
    bool? dynamicColour,
    bool? pureBlack,
  }) {
    return AppearanceSettings(
      mode: mode ?? this.mode,
      accentIndex: accentIndex ?? this.accentIndex,
      dynamicColour: dynamicColour ?? this.dynamicColour,
      pureBlack: pureBlack ?? this.pureBlack,
    );
  }
}

final appearanceSettingsProvider =
    NotifierProvider<AppearanceSettingsController, AppearanceSettings>(
  AppearanceSettingsController.new,
);

class AppearanceSettingsController extends Notifier<AppearanceSettings> {
  static const _prefsKey = 'appearance_settings_v1';

  @override
  AppearanceSettings build() {
    // Defaults paint immediately and the stored choice arrives a frame
    // later. Restoring synchronously would mean blocking the first frame on
    // a disk read to avoid a flash most users never see.
    Future<void>.microtask(_restore);
    return const AppearanceSettings();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return;

    try {
      state = AppearanceSettings.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (e) {
      // Settings written by a newer build must not stop the app starting.
      debugPrint('Unreadable appearance settings, using defaults: $e');
    }
  }

  Future<void> update(AppearanceSettings settings) async {
    state = settings;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(settings.toJson()));
  }
}
