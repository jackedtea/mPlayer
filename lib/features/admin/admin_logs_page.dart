// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../servers/server_admin.dart';
import '../downloads/download_ui.dart' show formatBytes;
import 'admin_providers.dart';
import 'admin_widgets.dart';

/// The server's log files, newest first.
class AdminLogsPage extends ConsumerWidget {
  const AdminLogsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final files = ref.watch(serverLogFilesProvider);

    return AdminScaffold(
      title: l10n.adminLogs,
      onRefresh: () async {
        ref.invalidate(serverLogFilesProvider);
        await ref.read(serverLogFilesProvider.future);
      },
      child: switch (files) {
        AsyncError(:final error) => AdminList(
          emptyText: '$error',
          children: const <Widget>[],
        ),
        _ => AdminList(
          loading: files.isLoading,
          emptyText: l10n.adminNoLogs,
          children: <Widget>[
            for (final ServerLogFile file
                in files.value ?? const <ServerLogFile>[])
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: Text(
                  file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  <String>[
                    formatBytes(file.size),
                    relativeTime(file.modified, l10n),
                  ].where((s) => s.isNotEmpty).join(' · '),
                ),
                onTap: () => context.push(
                  '/admin/logs/view?name=${Uri.encodeQueryComponent(file.name)}',
                ),
              ),
          ],
        ),
      },
    );
  }
}

/// One log file, as lines, with a filter.
///
/// Lines rather than one block of text: a log is tens of thousands of lines,
/// and a list builds only the ones on screen. It opens at the **end**, since
/// the newest lines are the reason anyone opens a log.
class AdminLogViewerPage extends ConsumerStatefulWidget {
  const AdminLogViewerPage({super.key, required this.name});

  final String name;

  @override
  ConsumerState<AdminLogViewerPage> createState() => _AdminLogViewerState();
}

class _AdminLogViewerState extends ConsumerState<AdminLogViewerPage> {
  String _query = '';
  bool _problemsOnly = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final text = ref.watch(serverLogTextProvider(widget.name));

    final lines = filterLogLines(
      text.value ?? '',
      query: _query,
      problemsOnly: _problemsOnly,
    );

    return AdminScaffold(
      title: widget.name,
      actions: <Widget>[
        IconButton(
          icon: const Icon(Icons.copy_rounded),
          tooltip: l10n.adminCopyLog,
          onPressed: text.value == null
              ? null
              : () async {
                  final messenger = ScaffoldMessenger.of(context);
                  await Clipboard.setData(
                    ClipboardData(text: lines.join('\n')),
                  );
                  messenger.showSnackBar(
                    SnackBar(content: Text(l10n.adminLogCopied)),
                  );
                },
        ),
      ],
      onRefresh: () async {
        ref.invalidate(serverLogTextProvider(widget.name));
        await ref.read(serverLogTextProvider(widget.name).future);
      },
      child: Column(
        children: <Widget>[
          Padding(
            padding: EdgeInsets.fromLTRB(
              spacing.screenHorizontal(context.windowSize),
              spacing.sm,
              spacing.screenHorizontal(context.windowSize),
              0,
            ),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: l10n.adminLogFilter,
                isDense: true,
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: spacing.screenHorizontal(context.windowSize),
              ),
              child: FilterChip(
                label: Text(l10n.adminProblemsOnly),
                selected: _problemsOnly,
                onSelected: (v) => setState(() => _problemsOnly = v),
              ),
            ),
          ),
          Expanded(
            child: switch (text) {
              AsyncError(:final error) => AdminList(
                emptyText: '$error',
                children: const <Widget>[],
              ),
              AsyncLoading() => const Center(
                child: CircularProgressIndicator(),
              ),
              _ when lines.isEmpty => AdminList(
                emptyText: l10n.adminLogNoLines,
                children: const <Widget>[],
              ),
              _ => ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                // Reversed so it opens on the newest line without a jump.
                reverse: true,
                padding: EdgeInsets.symmetric(
                  horizontal: spacing.screenHorizontal(context.windowSize),
                  vertical: spacing.sm,
                ),
                itemCount: lines.length,
                itemBuilder: (context, i) =>
                    _LogLine(line: lines[lines.length - 1 - i]),
              ),
            },
          ),
        ],
      ),
    );
  }
}

class _LogLine extends StatelessWidget {
  const _LogLine({required this.line});

  final String line;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final colour = switch (logLineLevel(line)) {
      LogLineLevel.error => scheme.error,
      LogLineLevel.warning => context.semantic.warning,
      LogLineLevel.other => scheme.onSurface,
    };
    return SelectableText(
      line,
      style: context.texts.bodySmall?.copyWith(
        fontFamily: 'monospace',
        color: colour,
      ),
    );
  }
}

enum LogLineLevel { error, warning, other }

/// Jellyfin writes `[2026-11-10 03:00:00.123 +07:00] [ERR] [12] …`; the level
/// is the second bracket. A continuation line (a stack trace) has none.
LogLineLevel logLineLevel(String line) {
  if (line.contains('] [ERR]') || line.contains('] [FTL]')) {
    return LogLineLevel.error;
  }
  if (line.contains('] [WRN]')) return LogLineLevel.warning;
  return LogLineLevel.other;
}

/// The lines of [text] that match [query] (case-insensitive) and, with
/// [problemsOnly], are warnings or errors.
List<String> filterLogLines(
  String text, {
  String query = '',
  bool problemsOnly = false,
}) {
  final needle = query.trim().toLowerCase();
  return <String>[
    for (final String line in text.split('\n'))
      if (line.trim().isNotEmpty &&
          (needle.isEmpty || line.toLowerCase().contains(needle)) &&
          (!problemsOnly || logLineLevel(line) != LogLineLevel.other))
        line.trimRight(),
  ];
}
