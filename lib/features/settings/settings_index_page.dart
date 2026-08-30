// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../admin/admin_providers.dart';

/// Screen 1l — the settings index.
///
/// Section order is fixed by the design: Appearance, General, Player, Audio,
/// Subtitle, About. Each destination page arrives with build step 7; the rows
/// exist now so the shell is navigable and the order is locked in.
class SettingsIndexPage extends ConsumerWidget {
  const SettingsIndexPage({super.key});

  /// Order is fixed by the design. `route` is null for the one section that
  /// has no page yet; it follows the same section+tile pattern and is built
  /// when its settings actually exist.
  ///
  /// [isAdministrator] adds one row at the end. It is absent rather than
  /// disabled for anyone else: a permanently greyed row inviting a user to
  /// administer a server they cannot is worse than no row.
  static List<_SettingsEntry> _entriesFor(
    AppLocalizations l10n, {
    bool isAdministrator = false,
  }) {
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
      if (isAdministrator)
        _SettingsEntry(
          title: l10n.settingsAdmin,
          subtitle: l10n.settingsAdminSub,
          icon: Icons.admin_panel_settings_rounded,
          // Outside `/settings`, because it belongs to the server rather than
          // to this installation — every other row here changes something on
          // this device only.
          path: '/admin',
        ),
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = context.spacing;
    final scheme = context.colors;
    final l10n = AppLocalizations.of(context);
    final isAdministrator = ref.watch(isAdministratorProvider);

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
          for (final _SettingsEntry e
              in _entriesFor(l10n, isAdministrator: isAdministrator))
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
              onTap: e.destination == null
                  ? () => ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.notImplemented(e.title)),
                        ),
                      )
                  : () => context.push(e.destination!),
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
    this.path,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  /// Relative to `/settings`; null means the page does not exist yet, or that
  /// [path] names it instead.
  final String? route;

  /// A destination outside `/settings` — the administration section is the
  /// only one, because it changes the server rather than this installation.
  final String? path;

  /// Where the row goes, or null when it goes nowhere yet.
  String? get destination => path ?? (route == null ? null : '/settings/$route');
}
