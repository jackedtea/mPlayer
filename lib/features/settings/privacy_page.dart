// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';

import '../../app/tokens.dart';
import '../../l10n/app_localizations.dart';
import 'settings_widgets.dart';

/// Screen 1m, Privacy.
///
/// Every claim on this page is one the code actually keeps, and each is
/// checkable in the source. If a future change breaks one of them, this page
/// is what has to change with it — a privacy statement that has drifted from
/// the code is worse than none.
class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  static List<(IconData, String, String)> _promisesFor(AppLocalizations l10n) {
    return <(IconData, String, String)>[
      (
        Icons.cloud_off_rounded,
        l10n.privacyNoTelemetry,
        l10n.privacyNoTelemetryBody,
      ),
      (Icons.devices_rounded, l10n.privacyLocal, l10n.privacyLocalBody),
      (Icons.key_rounded, l10n.privacyKeychain, l10n.privacyKeychainBody),
      (
        Icons.system_update_rounded,
        l10n.privacyUpdates,
        l10n.privacyUpdatesBody,
      ),
      (
        Icons.wifi_tethering_rounded,
        l10n.privacyCasting,
        l10n.privacyCastingBody,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final scheme = context.colors;

    return SettingsScaffold(
      title: l10n.privacy,
      children: <Widget>[
        for (final (IconData icon, String title, String body)
            in _promisesFor(l10n))
          Padding(
            padding: EdgeInsets.fromLTRB(
              spacing.screenHorizontal(context.windowSize),
              spacing.md,
              spacing.screenHorizontal(context.windowSize),
              0,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(icon, color: scheme.primary),
                SizedBox(width: spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(title, style: context.texts.titleSmall),
                      SizedBox(height: spacing.xs),
                      Text(
                        body,
                        style: context.texts.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            spacing.screenHorizontal(context.windowSize),
            spacing.xl,
            spacing.screenHorizontal(context.windowSize),
            spacing.lg,
          ),
          child: Text(
            l10n.privacyFooter,
            style: context.texts.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
