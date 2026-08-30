// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../servers/server_admin.dart';
import 'admin_providers.dart';
import 'admin_widgets.dart';

/// The server's maintenance jobs — run one, stop one, watch one.
class AdminTasksPage extends ConsumerWidget {
  const AdminTasksPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tasks = ref.watch(scheduledTasksProvider);

    return AdminScaffold(
      title: l10n.adminTasks,
      onRefresh: () async {
        ref.invalidate(scheduledTasksProvider);
        await ref.read(scheduledTasksProvider.future);
      },
      child: AdminList(
        loading: tasks.isLoading,
        emptyText: l10n.adminNoTasks,
        children: <Widget>[
          for (final ScheduledTask task in tasks.value ?? const <ScheduledTask>[])
            _TaskRow(task: task),
        ],
      ),
    );
  }
}

class _TaskRow extends ConsumerWidget {
  const _TaskRow({required this.task});

  final ScheduledTask task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = context.colors;

    return ListTile(
      isThreeLine: task.isRunning,
      title: Text(task.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            _statusLine(l10n),
            style: TextStyle(
              // The only thing about a finished task worth colouring.
              color: task.lastFailed && !task.isRunning
                  ? scheme.error
                  : scheme.onSurfaceVariant,
            ),
          ),
          if (task.isRunning) ...<Widget>[
            const SizedBox(height: 6),
            LinearProgressIndicator(
              // Null draws the indeterminate bar, which is the honest answer
              // for a task that is running and has not reported a percentage
              // — several never do.
              value: task.progress == null ? null : task.progress! / 100,
              minHeight: 3,
            ),
          ],
        ],
      ),
      trailing: task.isRunning
          ? TextButton(
              onPressed: task.state == TaskState.cancelling
                  ? null
                  : () => runAdminAction(
                        context,
                        ref,
                        action: (admin) => admin.stopTask(task.id),
                        success: l10n.adminTaskStopping(task.name),
                        refresh: () => ref.invalidate(scheduledTasksProvider),
                      ),
              child: Text(l10n.adminStopTask),
            )
          : TextButton(
              onPressed: () => runAdminAction(
                context,
                ref,
                action: (admin) => admin.runTask(task.id),
                success: l10n.adminTaskStarted(task.name),
                refresh: () => ref.invalidate(scheduledTasksProvider),
              ),
              child: Text(l10n.adminRunTask),
            ),
    );
  }

  String _statusLine(AppLocalizations l10n) {
    if (task.state == TaskState.cancelling) return l10n.adminStopTask;
    if (task.isRunning) {
      final progress = task.progress;
      return progress == null ? l10n.adminRunTask : '${progress.round()}%';
    }
    if (task.lastFailed) return l10n.adminTaskLastFailed;

    final ended = task.lastEndedAt;
    if (ended == null) return l10n.adminTaskNeverRun;
    return l10n.adminTaskLastRun(relativeTime(ended, l10n));
  }
}
