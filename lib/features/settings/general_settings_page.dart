// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/locale_controller.dart';
import '../../l10n/app_localizations.dart';
import 'settings_widgets.dart';

/// Screen 1l, General. The design lists language here.
class GeneralSettingsPage extends ConsumerWidget {
  const GeneralSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(localeProvider);

    return SettingsScaffold(
      title: l10n.settingsGeneral,
      children: <Widget>[
        SettingsSection(title: l10n.settingsGeneral),
        SettingsValueRow(
          title: l10n.language,
          value: LocaleController.labelFor(locale, l10n),
          onTap: () => _pickLanguage(context, ref, locale),
        ),
        SettingsValueRow(
          title: l10n.defaultLibraryView,
          value: l10n.viewGrid,
        ),
      ],
    );
  }

  Future<void> _pickLanguage(
    BuildContext context,
    WidgetRef ref,
    Locale? current,
  ) async {
    final l10n = AppLocalizations.of(context);

    // Null first: following the device is the default, and a Vietnamese phone
    // should already be in Vietnamese without anyone choosing anything.
    final options = <Locale?>[null, ...supportedLanguages];

    final chosen = await showModalBottomSheet<_LocaleChoice>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => SafeArea(
        // RadioGroup owns the selection; the per-tile groupValue/onChanged
        // pair is deprecated.
        child: RadioGroup<String>(
          groupValue: current?.languageCode ?? '',
          onChanged: (code) => Navigator.of(sheetContext).pop(
            _LocaleChoice(
              options.firstWhere(
                (l) => (l?.languageCode ?? '') == code,
                orElse: () => null,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (final Locale? option in options)
                RadioListTile<String>(
                  value: option?.languageCode ?? '',
                  title: Text(LocaleController.labelFor(option, l10n)),
                ),
            ],
          ),
        ),
      ),
    );

    if (chosen == null) return;
    await ref.read(localeProvider.notifier).setLocale(chosen.locale);
  }
}

/// Wrapper so "follow the system" (a null locale) can be distinguished from
/// the sheet being dismissed, which also yields null.
@immutable
class _LocaleChoice {
  const _LocaleChoice(this.locale);
  final Locale? locale;
}
