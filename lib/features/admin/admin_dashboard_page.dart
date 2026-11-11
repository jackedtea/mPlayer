// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../servers/server_admin.dart';
import '../../servers/server_registry.dart';
import '../../widgets/section_header.dart';
import '../player/playback_state.dart' show formatDuration;
import 'admin_session_sheet.dart';
import 'admin_providers.dart';
import 'admin_widgets.dart';

/// The administration home: what the server is, who is on it, and the way in
/// to everything else.
///
/// Sessions live here rather than on a screen of their own because they are
/// the reason an administrator opens this at all — "who is watching, and can
/// I stop it" is the question, and burying it one tap down answers it slower
/// than the web dashboard does.
class AdminDashboardPage extends ConsumerWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;

    final info = ref.watch(systemInfoProvider);
    final sessions = ref.watch(adminSessionsProvider);

    return AdminScaffold(
      title: l10n.adminTitle,
      onRefresh: () async {
        ref
          ..invalidate(systemInfoProvider)
          ..invalidate(adminSessionsProvider);
        await ref.read(adminSessionsProvider.future);
      },
      actions: <Widget>[_ServerMenu(info: info.value)],
      child: AdminList(
        children: <Widget>[
          _ServerCard(info: info.value),
          if (info.value case final ServerSystemInfo i when i.hasPendingRestart)
            _RestartBanner(info: i),
          SizedBox(height: spacing.md),

          // The screens this one is the way in to, grouped as the web
          // dashboard groups them, so an administrator who knows one knows
          // where to look in the other.
          for (final _NavSection section in _navSections(l10n)) ...<Widget>[
            SectionHeader(title: section.title),
            for (final _NavEntry entry in section.entries)
              if (entry.children.isEmpty)
                _NavRow(
                  icon: entry.icon,
                  label: entry.label,
                  onTap: () => context.push(entry.path!),
                )
              else
                _NavGroup(entry: entry),
          ],

          SizedBox(height: spacing.sectionGap),
          SectionHeader(title: l10n.adminSessions),
          if (sessions.isLoading && (sessions.value?.isEmpty ?? true))
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (sessions.value?.isEmpty ?? true)
            Padding(
              padding: EdgeInsets.symmetric(vertical: spacing.lg),
              child: AdminNote(text: l10n.adminNoSessions),
            )
          else
            for (final AdminSession session in sessions.value!)
              _SessionRow(session: session),
        ],
      ),
    );
  }
}

/// What the server is, and how long it has been it.
class _ServerCard extends ConsumerWidget {
  const _ServerCard({required this.info});

  final ServerSystemInfo? info;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = context.spacing;
    final scheme = context.colors;
    final profile = ref.watch(serverRegistryProvider).active;

    final resolved = info;
    final lines = <String>[
      if (resolved != null && resolved.version.isNotEmpty)
        'Jellyfin ${resolved.version}',
      if (resolved != null)
        <String>[
          resolved.operatingSystem,
          resolved.architecture,
        ].where((s) => s.isNotEmpty).join(' · '),
      if (profile != null) profile.uri,
    ].where((s) => s.isNotEmpty).toList();

    // Inset from the app bar above as well as from the sides: flush against
    // the bar, the card read as part of it.
    return Padding(
      padding: EdgeInsets.fromLTRB(
        spacing.screenHorizontal(context.windowSize),
        spacing.md,
        spacing.screenHorizontal(context.windowSize),
        0,
      ),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(spacing.lg),
        // A tinted container rather than a surface tone: the surface tones
        // sit a step from the page and the app bar, and the card vanished
        // between them on a dark theme.
        decoration: BoxDecoration(
          color: scheme.secondaryContainer,
          borderRadius: context.radii.cardAll,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            CircleAvatar(
              backgroundColor: scheme.primary,
              child: Icon(Icons.dns_rounded, color: scheme.onPrimary),
            ),
            SizedBox(width: spacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    resolved?.name.isNotEmpty ?? false
                        ? resolved!.name
                        : profile?.name ?? '',
                    style: context.texts.titleLarge?.copyWith(
                      color: scheme.onSecondaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  for (final String line in lines) ...<Widget>[
                    SizedBox(height: spacing.xs),
                    Text(
                      line,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.texts.bodyMedium?.copyWith(
                        color: scheme.onSecondaryContainer.withValues(
                          alpha: 0.8,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rename, restart, shut down.
///
/// An overflow rather than three buttons on the screen: two of them take the
/// server away from everyone watching, and a control that destructive should
/// take a deliberate second tap to even reach.
class _ServerMenu extends ConsumerWidget {
  const _ServerMenu({required this.info});

  final ServerSystemInfo? info;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final serverName = ref.watch(serverRegistryProvider).active?.name ?? '';

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded),
      itemBuilder: (menuContext) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'scan',
          child: Text(l10n.adminScanLibraries),
        ),
        PopupMenuItem<String>(value: 'rename', child: Text(l10n.adminRename)),
        // Absent, not disabled, where the server says it cannot: a menu item
        // that explains why it does nothing is a menu item nobody wanted.
        if (info?.canRestart ?? false)
          PopupMenuItem<String>(
            value: 'restart',
            child: Text(l10n.adminRestart),
          ),
        if (info?.canShutdown ?? false)
          PopupMenuItem<String>(
            value: 'shutdown',
            child: Text(l10n.adminShutdown),
          ),
      ],
      onSelected: (value) => switch (value) {
        'scan' => _scan(context, ref, l10n),
        'rename' => _rename(context, ref, l10n, serverName),
        'restart' => _restart(context, ref, l10n, serverName),
        'shutdown' => _shutdown(context, ref, l10n, serverName),
        _ => null,
      },
    );
  }

  Future<void> _scan(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    await runAdminAction(
      context,
      ref,
      action: (admin) => admin.scanLibraries(),
      success: l10n.adminScanStarted,
      // A scan reports itself as a scheduled task, which is where its
      // progress actually shows.
      refresh: () => ref.invalidate(scheduledTasksProvider),
    );
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    String current,
  ) async {
    final controller = TextEditingController(text: current);

    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.adminRename),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: l10n.adminRenameHint),
          onSubmitted: (v) => Navigator.of(dialogContext).pop(v),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: Text(l10n.actionSave),
          ),
        ],
      ),
    );

    controller.dispose();
    if (name == null || name.trim().isEmpty || !context.mounted) return;

    await runAdminAction(
      context,
      ref,
      action: (admin) => admin.setServerName(name),
      success: l10n.adminRenamed,
      refresh: () => ref.invalidate(systemInfoProvider),
    );
  }

  Future<void> _restart(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    String name,
  ) async {
    final go = await confirmAdminAction(
      context,
      title: l10n.adminRestartQuestion(name),
      body: l10n.adminRestartBody,
      confirmLabel: l10n.adminRestart,
    );
    if (!go || !context.mounted) return;

    await runAdminAction(
      context,
      ref,
      action: (admin) => admin.restartServer(),
      success: l10n.adminRestarting,
    );
  }

  Future<void> _shutdown(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    String name,
  ) async {
    final go = await confirmAdminAction(
      context,
      title: l10n.adminShutdownQuestion(name),
      body: l10n.adminShutdownBody,
      confirmLabel: l10n.adminShutdown,
    );
    if (!go || !context.mounted) return;

    await runAdminAction(
      context,
      ref,
      action: (admin) => admin.shutdownServer(),
      success: l10n.adminShuttingDown,
    );
  }
}

/// Says a restart is waiting, and offers it where the server can do one.
///
/// A plugin installed or updated does nothing until then, and the web
/// dashboard's own notice is easy to miss from a phone that never opens it.
class _RestartBanner extends ConsumerWidget {
  const _RestartBanner({required this.info});

  final ServerSystemInfo info;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final warning = context.semantic.warning;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.screenHorizontal(context.windowSize),
        vertical: spacing.sm,
      ),
      child: Card.outlined(
        margin: EdgeInsets.zero,
        child: ListTile(
          leading: Icon(Icons.restart_alt_rounded, color: warning),
          title: Text(l10n.adminRestartPending),
          subtitle: Text(l10n.adminRestartPendingBody),
          trailing: info.canRestart
              ? TextButton(
                  onPressed: () async {
                    final go = await confirmAdminAction(
                      context,
                      title: l10n.adminRestartQuestion(info.name),
                      body: l10n.adminRestartBody,
                      confirmLabel: l10n.adminRestart,
                    );
                    if (!go || !context.mounted) return;
                    await runAdminAction(
                      context,
                      ref,
                      action: (admin) => admin.restartServer(),
                      success: l10n.adminRestarting,
                      refresh: () => ref.invalidate(systemInfoProvider),
                    );
                  },
                  child: Text(l10n.adminRestartNow),
                )
              : null,
        ),
      ),
    );
  }
}

/// One heading of the dashboard and the screens under it.
class _NavSection {
  const _NavSection(this.title, this.entries);
  final String title;
  final List<_NavEntry> entries;
}

/// A screen, or a group of them that opens in place like the web's.
class _NavEntry {
  const _NavEntry(this.icon, this.label, {this.path, this.children = const []});
  final IconData icon;
  final String label;
  final String? path;
  final List<_NavEntry> children;
}

List<_NavSection> _navSections(AppLocalizations l10n) => <_NavSection>[
  _NavSection(l10n.adminSectionServer, <_NavEntry>[
    _NavEntry(
      Icons.people_outline_rounded,
      l10n.adminUsers,
      path: '/admin/users',
    ),
    _NavEntry(
      Icons.video_library_outlined,
      l10n.adminLibraries,
      children: <_NavEntry>[
        _NavEntry(
          Icons.video_library_outlined,
          l10n.adminLibraries,
          path: '/admin/libraries',
        ),
        _NavEntry(
          Icons.view_module_outlined,
          l10n.adminDisplay,
          path: '/admin/settings/display',
        ),
        _NavEntry(
          Icons.travel_explore_rounded,
          l10n.adminMetadataSettings,
          path: '/admin/settings/metadata',
        ),
        _NavEntry(
          Icons.description_outlined,
          l10n.adminNfo,
          path: '/admin/settings/nfo',
        ),
      ],
    ),
    _NavEntry(
      Icons.play_circle_outline_rounded,
      l10n.adminPlayback,
      children: <_NavEntry>[
        _NavEntry(
          Icons.transform_rounded,
          l10n.adminTranscodingSettings,
          path: '/admin/settings/transcoding',
        ),
        _NavEntry(
          Icons.history_rounded,
          l10n.adminResume,
          path: '/admin/settings/resume',
        ),
        _NavEntry(
          Icons.wifi_tethering_rounded,
          l10n.adminStreaming,
          path: '/admin/settings/streaming',
        ),
        _NavEntry(
          Icons.burst_mode_outlined,
          l10n.adminTrickplay,
          path: '/admin/settings/trickplay',
        ),
      ],
    ),
    _NavEntry(Icons.storage_rounded, l10n.adminStorage, path: '/admin/storage'),
  ]),
  _NavSection(l10n.adminSectionDevices, <_NavEntry>[
    _NavEntry(Icons.devices_rounded, l10n.adminDevices, path: '/admin/devices'),
    _NavEntry(
      Icons.receipt_long_rounded,
      l10n.adminActivity,
      path: '/admin/activity',
    ),
  ]),
  _NavSection(l10n.adminLiveTv, <_NavEntry>[
    _NavEntry(Icons.live_tv_rounded, l10n.adminLiveTv, path: '/admin/livetv'),
    _NavEntry(
      Icons.fiber_dvr_outlined,
      l10n.adminDvr,
      path: '/admin/settings/dvr',
    ),
  ]),
  _NavSection(l10n.adminPlugins, <_NavEntry>[
    _NavEntry(
      Icons.extension_outlined,
      l10n.adminPlugins,
      path: '/admin/plugins',
    ),
  ]),
  _NavSection(l10n.adminSectionAdvanced, <_NavEntry>[
    _NavEntry(
      Icons.lan_outlined,
      l10n.adminNetworking,
      path: '/admin/settings/networking',
    ),
    _NavEntry(Icons.key_outlined, l10n.adminApiKeys, path: '/admin/keys'),
    _NavEntry(Icons.description_outlined, l10n.adminLogs, path: '/admin/logs'),
    _NavEntry(Icons.schedule_rounded, l10n.adminTasks, path: '/admin/tasks'),
  ]),
];

/// A group of screens that opens in place, as Libraries and Playback do in
/// the web dashboard's menu.
class _NavGroup extends StatelessWidget {
  const _NavGroup({required this.entry});

  final _NavEntry entry;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      leading: Icon(entry.icon, color: context.colors.primary),
      title: Text(entry.label),
      shape: const Border(),
      collapsedShape: const Border(),
      childrenPadding: EdgeInsetsDirectional.only(start: context.spacing.lg),
      children: <Widget>[
        for (final _NavEntry child in entry.children)
          _NavRow(
            icon: child.icon,
            label: child.label,
            onTap: () => context.push(child.path!),
          ),
      ],
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: context.colors.primary),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

/// One person on one device, and what can be done about it.
class _SessionRow extends ConsumerWidget {
  const _SessionRow({required this.session});

  final AdminSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = context.colors;

    final device = <String>[
      session.deviceName,
      session.client,
    ].where((s) => s.isNotEmpty).join(' · ');

    return ListTile(
      onTap: () => showSessionDetails(context, session),
      isThreeLine: session.isPlaying,
      leading: CircleAvatar(
        backgroundColor: session.isPlaying
            ? scheme.primaryContainer
            : scheme.surfaceContainerHighest,
        child: Icon(
          session.isPlaying
              ? (session.isPaused
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded)
              : Icons.devices_rounded,
          color: session.isPlaying
              ? scheme.onPrimaryContainer
              : scheme.onSurfaceVariant,
        ),
      ),
      title: Text(
        session.username.isEmpty ? device : session.username,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            session.username.isEmpty ? '' : device,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            // An idle session says so rather than showing a blank line: a
            // device that is signed in and not playing is still something an
            // administrator wants to see.
            session.nowPlaying ?? l10n.adminIdleSession,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: session.isPlaying
                  ? scheme.primary
                  : scheme.onSurfaceVariant,
            ),
          ),
          // How it reaches the client — the first thing to look at when a
          // server is struggling. The sheet behind a tap says why.
          if (session.playMethod case final PlayMethod method)
            PlayMethodChip(method: method),
          if (session.progress case final double progress) ...<Widget>[
            const SizedBox(height: 4),
            LinearProgressIndicator(value: progress, minHeight: 3),
            const SizedBox(height: 2),
            Text(
              '${formatDuration(session.position!)} / '
              '${formatDuration(session.runtime!)}',
              style: context.texts.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
      // A client that does not accept remote control gets no buttons at all,
      // rather than buttons that quietly fail.
      trailing: session.supportsRemoteControl
          ? _SessionActions(session: session)
          : null,
    );
  }
}

class _SessionActions extends ConsumerWidget {
  const _SessionActions({required this.session});

  final AdminSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        IconButton(
          icon: const Icon(Icons.message_outlined),
          tooltip: l10n.adminSendMessage,
          onPressed: () => _message(context, ref, l10n),
        ),
        // Nothing to stop on a session that is not playing.
        if (session.isPlaying)
          IconButton(
            icon: const Icon(Icons.stop_circle_outlined),
            tooltip: l10n.adminStopPlayback,
            onPressed: () => runAdminAction(
              context,
              ref,
              action: (admin) => admin.stopSession(session.id),
              success: l10n.adminPlaybackStopped,
              refresh: () => ref.invalidate(adminSessionsProvider),
            ),
          ),
      ],
    );
  }

  Future<void> _message(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final controller = TextEditingController();

    final text = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          l10n.adminMessageTitle(
            session.deviceName.isEmpty ? session.client : session.deviceName,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: l10n.adminMessageHint),
          onSubmitted: (v) => Navigator.of(dialogContext).pop(v),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: Text(l10n.actionSend),
          ),
        ],
      ),
    );

    controller.dispose();
    if (text == null || text.trim().isEmpty || !context.mounted) return;

    await runAdminAction(
      context,
      ref,
      action: (admin) => admin.messageSession(
        session.id,
        header: l10n.appTitle,
        text: text.trim(),
      ),
      success: l10n.adminMessageSent,
    );
  }
}
