// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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
          for (final ScheduledTask task
              in tasks.value ?? const <ScheduledTask>[])
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
          // When it runs by itself: what tells "never run" apart from
          // "runs at 3 a.m. and has not got there yet".
          Text(
            triggerSummary(
              task.triggers,
              l10n,
              MaterialLocalizations.of(context),
            ),
            style: context.texts.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
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

/// "Daily at 03:00 · On startup", or "Only when run by hand".
String triggerSummary(
  List<TaskTrigger> triggers,
  AppLocalizations l10n,
  MaterialLocalizations material,
) {
  if (triggers.isEmpty) return l10n.adminTriggerManual;

  String time(Duration? d) {
    final t = d ?? Duration.zero;
    return material.formatTimeOfDay(
      TimeOfDay(hour: t.inHours % 24, minute: t.inMinutes % 60),
      alwaysUse24HourFormat: true,
    );
  }

  String every(Duration? d) {
    final t = d ?? Duration.zero;
    if (t.inMinutes % (24 * 60) == 0 && t.inDays > 0) {
      return l10n.adminTriggerEveryDays(t.inDays);
    }
    if (t.inMinutes % 60 == 0 && t.inHours > 0) {
      return l10n.adminTriggerEveryHours(t.inHours);
    }
    return l10n.adminTriggerEveryMinutes(t.inMinutes);
  }

  return <String>[
    for (final TaskTrigger t in triggers)
      switch (t.kind) {
        TaskTriggerKind.daily => l10n.adminTriggerDaily(time(t.timeOfDay)),
        TaskTriggerKind.weekly => l10n.adminTriggerWeekly(
          weekdayName(t.dayOfWeek, l10n.localeName),
          time(t.timeOfDay),
        ),
        TaskTriggerKind.interval => every(t.interval),
        TaskTriggerKind.startup => l10n.adminTriggerStartup,
        TaskTriggerKind.other => l10n.adminTriggerOther,
      },
  ].join(' · ');
}

/// The server's English day name in the reader's language.
String weekdayName(String english, String locale) {
  const days = <String>[
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];
  final i = days.indexOf(english);
  if (i < 0) return english;
  // 7 January 2024 was a Sunday.
  return DateFormat.EEEE(locale).format(DateTime(2024, 1, 7 + i));
}
