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
import '../../servers/server_profile.dart';
import '../../servers/server_registry.dart';
import '../servers/pin_lock.dart';
import '../servers/server_library.dart';
import 'current_server_card.dart';
import 'quick_connect_dialog.dart';
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
        title: l10n.downloadSettings,
        subtitle: l10n.downloadSettingsSub,
        icon: Icons.download_for_offline_rounded,
        route: 'downloads',
      ),
      // Not under `/settings`: the remote is a screen used from the sofa, and
      // it outlives the settings branch it is reached from.
      _SettingsEntry(
        title: l10n.remoteTitle,
        subtitle: l10n.remoteSettingsSub,
        icon: Icons.settings_remote_rounded,
        path: '/remote',
      ),
    ];
  }

  /// Last on the page, under the server section for an administrator: it is
  /// about the app as a whole, and the version it carries is the real one —
  /// which is why the page no longer prints a version line of its own.
  static _SettingsEntry _aboutEntry(AppLocalizations l10n) => _SettingsEntry(
        title: l10n.settingsAbout,
        subtitle: l10n.settingsAboutSub,
        icon: Icons.info_rounded,
        route: 'about',
      );

  /// Absent rather than disabled for anyone but an administrator: a
  /// permanently greyed section inviting a user to administer a server they
  /// cannot is worse than no section.
  ///
  /// **One row, into the dashboard**, which is the one place that lists the
  /// administration screens. Shortcuts to each of them used to sit here as
  /// well; they duplicated the dashboard and drifted from it as soon as a
  /// screen was added to one and not the other.
  ///
  /// The path is outside `/settings`, because it belongs to the server rather
  /// than to this installation.
  static List<_SettingsEntry> _serverEntries(AppLocalizations l10n) {
    return <_SettingsEntry>[
      _SettingsEntry(
        title: l10n.settingsAdmin,
        subtitle: l10n.settingsAdminSub,
        icon: Icons.admin_panel_settings_rounded,
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
      // No back arrow: Settings is a navigation destination now, not a
      // screen pushed over another one, so there is nothing behind it to pop
      // to. Leaving it means pressing another destination in the bottom bar.
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        children: <Widget>[
          const CurrentServerCard(),
          // Only with a server open: approving a code signs another device
          // in as the user this app is signed in as.
          if (ref.watch(connectedServerProvider) != null)
            ListTile(
              contentPadding: spacing.screenPadding(context.windowSize),
              leading: CircleAvatar(
                radius: 20,
                backgroundColor: scheme.secondaryContainer,
                child: Icon(
                  Icons.phonelink_lock_rounded,
                  size: 22,
                  color: scheme.onSecondaryContainer,
                ),
              ),
              title: Text(l10n.quickConnectTitle),
              subtitle: Text(l10n.quickConnectRowSub),
              trailing: Icon(Icons.chevron_right_rounded, color: scheme.outline),
              onTap: () => showQuickConnectDialog(context),
            ),
          if (ref.watch(connectedServerProvider) != null &&
              ref.watch(serverRegistryProvider).active != null)
            _PinRow(profile: ref.watch(serverRegistryProvider).active!),
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
          _tile(context, _aboutEntry(l10n)),
          SizedBox(height: spacing.lg),
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

  /// A destination outside `/settings` — the administration section, which
  /// changes the server rather than this installation, and the remote.
  final String? path;

  /// Where the row goes, or null when it goes nowhere yet.
  String? get destination => path ?? (route == null ? null : '/settings/$route');
}

/// Whether the current server asks for a PIN, and the way to change that.
class _PinRow extends ConsumerWidget {
  const _PinRow({required this.profile});

  final ServerProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = context.spacing;
    final scheme = context.colors;
    final l10n = AppLocalizations.of(context);

    return ListTile(
      contentPadding: spacing.screenPadding(context.windowSize),
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: scheme.secondaryContainer,
        child: Icon(
          profile.pinProtected ? Icons.lock_rounded : Icons.lock_open_rounded,
          size: 22,
          color: scheme.onSecondaryContainer,
        ),
      ),
      title: Text(l10n.pinLockTitle),
      subtitle: Text(profile.pinProtected ? l10n.pinLockOn : l10n.pinLockOff),
      trailing: Icon(Icons.chevron_right_rounded, color: scheme.outline),
      onTap: () => managePin(context, ref, profile),
    );
  }
}
