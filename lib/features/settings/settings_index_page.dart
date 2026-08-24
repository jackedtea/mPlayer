// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/tokens.dart';
import '../../l10n/app_localizations.dart';

/// Screen 1l — the settings index.
///
/// Section order is fixed by the design: Appearance, General, Player, Audio,
/// Subtitle, About. Each destination page arrives with build step 7; the rows
/// exist now so the shell is navigable and the order is locked in.
class SettingsIndexPage extends StatelessWidget {
  const SettingsIndexPage({super.key});

  /// Order is fixed by the design. `route` is null for the one section that
  /// has no page yet; it follows the same section+tile pattern and is built
  /// when its settings actually exist.
  static List<_SettingsEntry> _entriesFor(AppLocalizations l10n) {
    return <_SettingsEntry>[
      _SettingsEntry(
        title: l10n.settingsAppearance,
        subtitle: l10n.settingsAppearanceSub,
        icon: Icons.palette_rounded,
        route: 'appearance',
      ),
      _SettingsEntry(
        title: l10n.settingsGeneral,
        subtitle: l10n.settingsGeneralSub,
        icon: Icons.tune_rounded,
        route: 'general',
      ),
      _SettingsEntry(
        title: l10n.settingsPlayer,
        subtitle: l10n.settingsPlayerSub,
        icon: Icons.play_circle_rounded,
        route: 'player',
      ),
      _SettingsEntry(
        title: l10n.settingsAudio,
        subtitle: l10n.settingsAudioSub,
        icon: Icons.graphic_eq_rounded,
        route: 'audio',
      ),
      _SettingsEntry(
        title: l10n.settingsSubtitle,
        subtitle: l10n.settingsSubtitleSub,
        icon: Icons.subtitles_rounded,
        route: 'subtitle',
      ),
      _SettingsEntry(
        title: l10n.settingsAbout,
        subtitle: l10n.settingsAboutSub,
        icon: Icons.info_rounded,
        route: 'about',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final scheme = context.colors;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: l10n.actionBack,
          onPressed: () => context.pop(),
        ),
        title: Text(l10n.settings),
      ),
      body: ListView(
        children: <Widget>[
          for (final _SettingsEntry e in _entriesFor(l10n))
            ListTile(
              contentPadding: spacing.screenPadding(context.windowSize),
              minVerticalPadding: spacing.lg,
              leading: CircleAvatar(
                radius: 20,
                backgroundColor: scheme.primaryContainer,
                child: Icon(e.icon, size: 22, color: scheme.onPrimaryContainer),
              ),
              title: Text(e.title),
              subtitle: Text(e.subtitle),
              trailing: Icon(Icons.chevron_right_rounded, color: scheme.outline),
              onTap: e.route == null
                  ? () => ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.notImplemented(e.title)),
                        ),
                      )
                  : () => context.push('/settings/${e.route}'),
            ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: spacing.screenHorizontal(context.windowSize),
              vertical: spacing.sm,
            ),
            child: const Divider(),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: spacing.screenHorizontal(context.windowSize),
              vertical: spacing.sm,
            ),
            child: Text(
              'mPlayer 1.0.0 · build 1',
              style: context.texts.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

@immutable
class _SettingsEntry {
  const _SettingsEntry({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.route,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  /// Relative to `/settings`; null means the page does not exist yet.
  final String? route;
}
