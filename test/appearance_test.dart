// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mplayer/app/appearance_settings.dart';
import 'package:mplayer/app/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  group('defaults', () {
    test('follow the system and use the design seed', () {
      const s = AppearanceSettings();

      expect(s.mode, ThemeMode.system);
      expect(s.accent, seedColor);
      expect(s.dynamicColour, isFalse);
      expect(s.pureBlack, isFalse);
    });
  });

  group('json', () {
    test('round-trips every field', () {
      const s = AppearanceSettings(
        mode: ThemeMode.dark,
        accentIndex: 2,
        dynamicColour: true,
        pureBlack: true,
      );

      final back = AppearanceSettings.fromJson(s.toJson());

      expect(back.mode, ThemeMode.dark);
      expect(back.accentIndex, 2);
      expect(back.dynamicColour, isTrue);
      expect(back.pureBlack, isTrue);
    });

    test('an accent index a newer build wrote falls back to the seed', () {
      final s = AppearanceSettings.fromJson(<String, dynamic>{
        'accentIndex': 99,
      });

      expect(s.accentIndex, 0);
      expect(s.accent, seedColor);
    });

    test('an unknown theme mode falls back to the system', () {
      final s = AppearanceSettings.fromJson(<String, dynamic>{
        'mode': 'sepia',
      });

      expect(s.mode, ThemeMode.system);
    });
  });

  group('persistence', () {
    test('a choice survives a restart', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(appearanceSettingsProvider.notifier).update(
            const AppearanceSettings(mode: ThemeMode.dark, accentIndex: 3),
          );

      // A second container stands in for the next launch.
      final restarted = ProviderContainer();
      addTearDown(restarted.dispose);
      restarted.read(appearanceSettingsProvider);
      await Future<void>.delayed(Duration.zero);

      final restored = restarted.read(appearanceSettingsProvider);
      expect(restored.mode, ThemeMode.dark);
      expect(restored.accentIndex, 3);
    });

    test('settings written by a newer build do not stop the app starting',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'appearance_settings_v1': jsonEncode(<String, Object>{'mode': 42}),
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(appearanceSettingsProvider);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(appearanceSettingsProvider).mode, ThemeMode.system);
    });
  });

  group('buildTheme', () {
    test('the design seed keeps the palette the spec pins role by role', () {
      final pinned = buildTheme(Brightness.light);
      final explicit = buildTheme(Brightness.light, accent: seedColor);

      // The spec's exact primary, not whatever fromSeed generates for it.
      expect(pinned.colorScheme.primary, const Color(0xFF00658F));
      expect(explicit.colorScheme.primary, pinned.colorScheme.primary);
      expect(explicit.colorScheme.surface, pinned.colorScheme.surface);
    });

    test('another accent generates its own scheme', () {
      final theme = buildTheme(Brightness.light, accent: accentPresets[3]);

      expect(theme.colorScheme.primary, isNot(const Color(0xFF00658F)));
      // The tokens are what the widgets read, so they have to survive.
      expect(theme.extensions, isNotEmpty);
    });

    test('pure black only applies to dark', () {
      final dark = buildTheme(Brightness.dark, pureBlack: true);
      final light = buildTheme(Brightness.light, pureBlack: true);

      expect(dark.colorScheme.surface, const Color(0xFF000000));
      expect(dark.scaffoldBackgroundColor, const Color(0xFF000000));
      expect(light.colorScheme.surface, isNot(const Color(0xFF000000)));
    });

    test('a wallpaper scheme wins over the accent', () {
      final wallpaper = ColorScheme.fromSeed(
        seedColor: const Color(0xFFB3261E),
        brightness: Brightness.dark,
      );
      final theme = buildTheme(
        Brightness.dark,
        accent: seedColor,
        dynamicScheme: wallpaper,
      );

      expect(theme.colorScheme.primary, isNot(const Color(0xFF82CFFF)));
    });
  });
}
