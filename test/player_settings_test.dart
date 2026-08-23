// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mplayer/features/settings/player_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  group('defaults', () {
    test('match what the design states', () {
      const s = PlayerSettings();

      expect(s.skipBack, const Duration(seconds: 10));
      expect(s.skipForward, const Duration(seconds: 30));
      expect(s.autoPlayNext, isTrue);
      // Opt-in, per the design: skipping ahead uninvited is worse than not.
      expect(s.autoSkipIntro, isFalse);
      expect(s.swipeGestures, isTrue);
      expect(s.hardwareDecoding, HardwareDecoding.auto);
    });
  });

  group('mpv values', () {
    test('hardware decoding maps to mpv hwdec names', () {
      expect(HardwareDecoding.auto.mpvValue, 'auto-safe');
      expect(HardwareDecoding.yes.mpvValue, 'auto');
      expect(HardwareDecoding.no.mpvValue, 'no');
    });

    test('text scale multiplies mpv default size and stays sane', () {
      expect(const PlayerSettings().mpvSubtitleFontSize, 55);
      expect(
        const PlayerSettings(subtitleTextScale: 2.0).mpvSubtitleFontSize,
        110,
      );
      // A slider at its extremes must not produce an unreadable or absurd size.
      expect(
        const PlayerSettings(subtitleTextScale: 0.01).mpvSubtitleFontSize,
        greaterThanOrEqualTo(10),
      );
      expect(
        const PlayerSettings(subtitleTextScale: 99).mpvSubtitleFontSize,
        lessThanOrEqualTo(200),
      );
    });

    test('colours are #AARRGGBB, which is what mpv parses', () {
      const s = PlayerSettings(subtitleColour: Color(0xFF82CFFF));

      expect(s.mpvSubtitleColour, '#FF82CFFF');
      expect(RegExp(r'^#[0-9A-F]{8}$').hasMatch(s.mpvSubtitleColour), isTrue);
    });

    test('background opacity becomes the alpha of a black backdrop', () {
      expect(
        const PlayerSettings(subtitleBackgroundOpacity: 0)
            .mpvSubtitleBackColour,
        '#00000000',
      );
      expect(
        const PlayerSettings(subtitleBackgroundOpacity: 1)
            .mpvSubtitleBackColour,
        '#FF000000',
      );
    });
  });

  group('persistence', () {
    test('a changed setting survives a restart', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(playerSettingsProvider.notifier).update(
            const PlayerSettings(
              skipForward: Duration(seconds: 60),
              autoSkipIntro: true,
              subtitleTextScale: 1.5,
            ),
          );

      // A second container reads what the first wrote, which is what a
      // relaunch does.
      final restarted = ProviderContainer();
      addTearDown(restarted.dispose);
      restarted.read(playerSettingsProvider);
      await Future<void>.delayed(Duration.zero);

      final restored = restarted.read(playerSettingsProvider);
      expect(restored.skipForward, const Duration(seconds: 60));
      expect(restored.autoSkipIntro, isTrue);
      expect(restored.subtitleTextScale, 1.5);
    });

    test('unreadable stored settings fall back to defaults', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'player_settings_v1': 'not json',
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(playerSettingsProvider);
      await Future<void>.delayed(Duration.zero);

      // Settings written by a newer build must not stop the app starting.
      expect(container.read(playerSettingsProvider).skipBack,
          const Duration(seconds: 10));
    });

    test('round-trips through JSON', () {
      const original = PlayerSettings(
        hardwareDecoding: HardwareDecoding.no,
        skipBack: Duration(seconds: 5),
        swipeGestures: false,
        subtitleColour: Color(0xFFFFE082),
        subtitleDelay: Duration(milliseconds: -500),
        pipOnLeave: false,
        backgroundAudio: false,
        preferredLanguage: 'vi',
        smartSubtitles: false,
      );

      final restored = PlayerSettings.fromJson(original.toJson());

      expect(restored.hardwareDecoding, HardwareDecoding.no);
      expect(restored.skipBack, const Duration(seconds: 5));
      expect(restored.swipeGestures, isFalse);
      expect(restored.subtitleColour.toARGB32(), 0xFFFFE082);
      expect(restored.subtitleDelay, const Duration(milliseconds: -500));
      expect(restored.pipOnLeave, isFalse);
      expect(restored.backgroundAudio, isFalse);
      expect(restored.preferredLanguage, 'vi');
      expect(restored.smartSubtitles, isFalse);
    });

    test('settings stored before these fields existed keep their defaults', () {
      // What an upgrade actually reads: a JSON blob written by the build
      // before picture in picture and smart subtitles were added.
      final restored = PlayerSettings.fromJson(<String, dynamic>{
        'skipBackSeconds': 5,
      });

      expect(restored.skipBack, const Duration(seconds: 5));
      expect(restored.pipOnLeave, isTrue);
      expect(restored.backgroundAudio, isTrue);
      expect(restored.preferredLanguage, isNull);
      expect(restored.smartSubtitles, isTrue);
    });
  });

  group('preferred language', () {
    test('is clearable, which a null argument alone cannot express', () {
      const chosen = PlayerSettings(preferredLanguage: 'vi');

      // A plain null means "leave it alone" for every other field here, so
      // "no preference" needs a flag of its own.
      expect(chosen.copyWith().preferredLanguage, 'vi');
      expect(chosen.copyWith(preferredLanguage: 'en').preferredLanguage, 'en');
      expect(
        chosen.copyWith(clearPreferredLanguage: true).preferredLanguage,
        isNull,
      );
    });
  });
}
