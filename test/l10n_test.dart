// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mplayer/app/locale_controller.dart';
import 'package:mplayer/l10n/app_localizations.dart';

/// Resolves the delegate for [locale] the way MaterialApp would.
Future<AppLocalizations> load(Locale locale) =>
    AppLocalizations.delegate.load(locale);

void main() {
  group('supported locales', () {
    test('ships exactly English and Vietnamese', () {
      expect(
        AppLocalizations.supportedLocales.map((l) => l.languageCode).toSet(),
        <String>{'en', 'vi'},
      );
      expect(
        supportedLanguages.map((l) => l.languageCode),
        <String>['en', 'vi'],
      );
    });

    test('every shipped locale is loadable', () async {
      for (final Locale locale in AppLocalizations.supportedLocales) {
        expect(await load(locale), isNotNull, reason: '$locale');
      }
    });

    test('the delegates include the Flutter material translations', () {
      // Without these, stock widgets (date pickers, text selection menus)
      // stay English no matter what the app says.
      expect(
        AppLocalizations.localizationsDelegates,
        contains(GlobalMaterialLocalizations.delegate),
      );
    });
  });

  group('translations', () {
    test('Vietnamese actually differs from English', () async {
      final en = await load(const Locale('en'));
      final vi = await load(const Locale('vi'));

      expect(en.navStorage, 'Files');
      expect(vi.navStorage, isNot(en.navStorage));
      expect(vi.settings, isNot(en.settings));
      expect(vi.noServerTitle, isNot(en.noServerTitle));
    });

    test('the product name is not translated', () async {
      final vi = await load(const Locale('vi'));
      expect(vi.appTitle, 'mPlayer');
    });

    test('placeholders survive translation', () async {
      final en = await load(const Locale('en'));
      final vi = await load(const Locale('vi'));

      expect(en.notImplemented('Cast'), contains('Cast'));
      expect(vi.notImplemented('Cast'), contains('Cast'));

      expect(en.connectionOk(3, 12), contains('3'));
      expect(vi.connectionOk(3, 12), allOf(contains('3'), contains('12')));

      expect(vi.showMoreFrom(6, 'NAS'), allOf(contains('6'), contains('NAS')));
      expect(vi.minutes(30), contains('30'));

      // The transport buttons follow the skip amounts from Player settings,
      // so these two carry a number rather than naming a fixed 10 and 30.
      expect(en.back10(15), contains('15'));
      expect(vi.forward30(60), contains('60'));

      expect(vi.playingOn('Living room TV'), contains('Living room TV'));
      expect(vi.rotationValue('Auto'), contains('Auto'));
    });

    test('every English key has a Vietnamese translation', () async {
      // `l10n_untranslated.json` reports this at build time, but only when
      // someone reads it. A missing key is an English word appearing in the
      // middle of a Vietnamese screen, which is worth failing a test over.
      final enArb = jsonDecode(
        await File('lib/l10n/app_en.arb').readAsString(),
      ) as Map<String, dynamic>;
      final viArb = jsonDecode(
        await File('lib/l10n/app_vi.arb').readAsString(),
      ) as Map<String, dynamic>;

      final missing = enArb.keys
          .where((k) => !k.startsWith('@') && !viArb.containsKey(k))
          .toList();

      expect(missing, isEmpty, reason: 'Untranslated: ${missing.join(', ')}');
    });
  });

  group('language labels', () {
    test('each language is named in its own language', () async {
      final en = await load(const Locale('en'));

      // Someone hunting for Vietnamese should see "Tiếng Việt", not
      // "Vietnamese", whatever the current UI language is.
      expect(LocaleController.labelFor(const Locale('vi'), en), 'Tiếng Việt');
      expect(LocaleController.labelFor(const Locale('en'), en), 'English');
    });

    test('a null locale reads as following the system', () async {
      final en = await load(const Locale('en'));
      final vi = await load(const Locale('vi'));

      expect(LocaleController.labelFor(null, en), en.languageSystem);
      expect(LocaleController.labelFor(null, vi), vi.languageSystem);
      expect(en.languageSystem, isNot(vi.languageSystem));
    });
  });
}
