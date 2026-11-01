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
import 'current_server_card.dart';
import 'settings_widgets.dart';

/// Screen 1l — the settings index: the current server, then two sections.
///
/// **App settings** change this installation only, in the design's fixed
/// order: Appearance, General, Player, Audio, Subtitle, About. **Server
/// settings** change the server for everyone on it, and appear only for an
/// administrator.
class SettingsIndexPage extends ConsumerWidget {
  const SettingsIndexPage({super.key});

  /// Order is fixed by the design. `route` is null for the one section that
  /// has no page yet; it follows the same section+tile pattern and is built
  /// when its settings actually exist.
  ///
  static List<_SettingsEntry> _appEntries(AppLocalizations l10n) {
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

  /// Absent rather than disabled for anyone but an administrator: a
  /// permanently greyed section inviting a user to administer a server they
  /// cannot is worse than no section.
  ///
  /// Every path is outside `/settings`, because these belong to the server
  /// rather than to this installation.
  static List<_SettingsEntry> _serverEntries(AppLocalizations l10n) {
    return <_SettingsEntry>[
      _SettingsEntry(
        title: l10n.settingsAdmin,
        subtitle: l10n.settingsAdminSub,
        icon: Icons.admin_panel_settings_rounded,
        path: '/admin',
      ),
      _SettingsEntry(
        title: l10n.adminUsers,
        icon: Icons.people_rounded,
        path: '/admin/users',
      ),
      _SettingsEntry(
        title: l10n.adminTasks,
        icon: Icons.schedule_rounded,
        path: '/admin/tasks',
      ),
      _SettingsEntry(
        title: l10n.adminActivity,
        icon: Icons.history_rounded,
        path: '/admin/activity',
      ),
      _SettingsEntry(
        title: l10n.adminPlugins,
        icon: Icons.extension_rounded,
        path: '/admin/plugins',
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
      // No back arrow: Settings is a navigation destination now, not a
      // screen pushed over another one, so there is nothing behind it to pop
      // to. Leaving it means pressing another destination in the bottom bar.
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        children: <Widget>[
          const CurrentServerCard(),
          SettingsSection(title: l10n.settingsSectionApp),
          for (final _SettingsEntry e in _appEntries(l10n)) _tile(context, e),
          if (isAdministrator) ...<Widget>[
            SettingsSection(title: l10n.settingsSectionServer),
            for (final _SettingsEntry e in _serverEntries(l10n))
              _tile(context, e),
          ],
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

  Widget _tile(BuildContext context, _SettingsEntry e) {
    final spacing = context.spacing;
    final scheme = context.colors;
    final l10n = AppLocalizations.of(context);
    final subtitle = e.subtitle;

    return ListTile(
      contentPadding: spacing.screenPadding(context.windowSize),
      minVerticalPadding: spacing.lg,
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: scheme.primaryContainer,
        child: Icon(e.icon, size: 22, color: scheme.onPrimaryContainer),
      ),
      title: Text(e.title),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: Icon(Icons.chevron_right_rounded, color: scheme.outline),
      onTap: e.destination == null
          ? () => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.notImplemented(e.title))),
              )
          : () => context.push(e.destination!),
    );
  }
}

@immutable
class _SettingsEntry {
  const _SettingsEntry({
    required this.title,
    this.subtitle,
    required this.icon,
    this.route,
    this.path,
  });

  final String title;
  final String? subtitle;
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
