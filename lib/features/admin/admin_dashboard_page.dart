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
      actions: <Widget>[
        _ServerMenu(info: info.value),
      ],
      child: AdminList(
        children: <Widget>[
          _ServerCard(info: info.value),
          SizedBox(height: spacing.md),

          // The four screens this one is the way in to.
          _NavRow(
            icon: Icons.schedule_rounded,
            label: l10n.adminTasks,
            onTap: () => context.push('/admin/tasks'),
          ),
          _NavRow(
            icon: Icons.people_outline_rounded,
            label: l10n.adminUsers,
            onTap: () => context.push('/admin/users'),
          ),
          _NavRow(
            icon: Icons.receipt_long_rounded,
            label: l10n.adminActivity,
            onTap: () => context.push('/admin/activity'),
          ),
          _NavRow(
            icon: Icons.extension_outlined,
            label: l10n.adminPlugins,
            onTap: () => context.push('/admin/plugins'),
          ),

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
        '${profile?.kind.label ?? ''} ${resolved.version}'.trim(),
      if (resolved != null)
        <String>[resolved.operatingSystem, resolved.architecture]
            .where((s) => s.isNotEmpty)
            .join(' · '),
      if (profile != null) profile.uri,
    ].where((s) => s.isNotEmpty).toList();

    return Padding(
      padding: spacing.screenPadding(context.windowSize),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(spacing.lg),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: context.radii.cardAll,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              resolved?.name.isNotEmpty ?? false
                  ? resolved!.name
                  : profile?.name ?? '',
              style: context.texts.titleMedium,
            ),
            for (final String line in lines) ...<Widget>[
              SizedBox(height: spacing.xs),
              Text(
                line,
                style: context.texts.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
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
    final serverName =
        ref.watch(serverRegistryProvider).active?.name ?? '';

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded),
      itemBuilder: (menuContext) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'scan',
          child: Text(l10n.adminScanLibraries),
        ),
        PopupMenuItem<String>(
          value: 'rename',
          child: Text(l10n.adminRename),
        ),
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
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text),
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

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

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

    final device = <String>[session.deviceName, session.client]
        .where((s) => s.isNotEmpty)
        .join(' · ');

    return ListTile(
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
              color: session.isPlaying ? scheme.primary : scheme.onSurfaceVariant,
            ),
          ),
          if (session.progress case final double progress) ...<Widget>[
            const SizedBox(height: 4),
            LinearProgressIndicator(value: progress, minHeight: 3),
            const SizedBox(height: 2),
            Text(
              '${formatDuration(session.position!)} / '
              '${formatDuration(session.runtime!)}',
              style: context.texts.labelSmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
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
