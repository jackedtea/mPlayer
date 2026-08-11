// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';

/// Languages the app ships. Adding one means adding an ARB file and an entry
/// here; [AppLocalizations.supportedLocales] stays the source of truth for
/// what Flutter will actually resolve.
const supportedLanguages = <Locale>[
  Locale('en'),
  Locale('vi'),
];

/// Selected language, or null for "follow the system".
///
/// Null is the default and is not the same as English: a Vietnamese device
/// should open in Vietnamese without the user configuring anything.
final localeProvider =
    NotifierProvider<LocaleController, Locale?>(LocaleController.new);

class LocaleController extends Notifier<Locale?> {
  static const _prefsKey = 'locale_language_code';

  @override
  Locale? build() {
    // Loads behind the first frame; the system locale is already correct in
    // the meantime, so there is nothing to flash.
    Future<void>.microtask(_restore);
    return null;
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_prefsKey);
    if (code == null || code.isEmpty) return;

    // A code that no longer ships falls back to the system rather than
    // leaving the app in a language with no translations.
    final match = supportedLanguages
        .where((l) => l.languageCode == code)
        .firstOrNull;
    if (match != null) state = match;
  }

  /// Pass null to follow the system.
  Future<void> setLocale(Locale? locale) async {
    state = locale;

    final prefs = await SharedPreferences.getInstance();
    if (locale == null) {
      await prefs.remove(_prefsKey);
    } else {
      await prefs.setString(_prefsKey, locale.languageCode);
    }
  }

  /// Label for the settings row, in the language it names — a user looking
  /// for "Tiếng Việt" should not have to recognise "Vietnamese".
  static String labelFor(Locale? locale, AppLocalizations l10n) {
    return switch (locale?.languageCode) {
      'en' => l10n.languageEnglish,
      'vi' => l10n.languageVietnamese,
      _ => l10n.languageSystem,
    };
  }
}
