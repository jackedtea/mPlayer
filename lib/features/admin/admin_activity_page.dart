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

/// How far back the activity log reaches.
enum ActivitySpan {
  all,
  day,
  week;

  DateTime? since(DateTime now) => switch (this) {
    ActivitySpan.all => null,
    ActivitySpan.day => now.subtract(const Duration(days: 1)),
    ActivitySpan.week => now.subtract(const Duration(days: 7)),
  };
}

/// What the server has been doing — sign-ins, playbacks, scans, failures —
/// a page at a time, with the two filters an administrator reaches for:
/// problems only, and how far back.
///
/// The pages are held here rather than in a provider: "Load more" appends,
/// and a provider family keyed on the page would refetch every page above
/// the new one on each pull.
class AdminActivityPage extends ConsumerStatefulWidget {
  const AdminActivityPage({super.key});

  /// Entries asked for per page.
  static const int pageSize = 50;

  @override
  ConsumerState<AdminActivityPage> createState() => _AdminActivityPageState();
}

class _AdminActivityPageState extends ConsumerState<AdminActivityPage> {
  final List<ActivityEntry> _entries = <ActivityEntry>[];

  /// Where the next page starts, in the server's unfiltered count.
  int _next = 0;
  bool _done = false;
  bool _loading = false;
  Object? _error;

  bool _problemsOnly = false;
  ActivitySpan _span = ActivitySpan.all;

  /// Bumped on every reset, so a page that lands after the filters changed
  /// is thrown away rather than appended to the wrong list.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _reset();
  }

  Future<void> _reset() {
    _generation++;
    _entries.clear();
    _next = 0;
    _done = false;
    _error = null;
    return _loadMore();
  }

  Future<void> _loadMore() async {
    if (_done) return;
    final generation = _generation;
    setState(() => _loading = true);

    try {
      final admin = await ref.read(serverAdminProvider.future);
      if (admin == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final page = await admin.activityPage(
        startIndex: _next,
        limit: AdminActivityPage.pageSize,
        problemsOnly: _problemsOnly,
        since: _span.since(DateTime.now()),
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _entries.addAll(page.entries);
        _next += page.fetched;
        _done =
            page.fetched < AdminActivityPage.pageSize ||
            (page.total != null && _next >= page.total!);
        _loading = false;
      });
    } catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;

    final filters = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.screenHorizontal(context.windowSize),
        vertical: spacing.xs,
      ),
      child: Wrap(
        spacing: spacing.sm,
        runSpacing: spacing.xs,
        children: <Widget>[
          FilterChip(
            label: Text(l10n.adminProblemsOnly),
            selected: _problemsOnly,
            onSelected: (v) {
              setState(() => _problemsOnly = v);
              _reset();
            },
          ),
          for (final ActivitySpan span in ActivitySpan.values)
            ChoiceChip(
              label: Text(switch (span) {
                ActivitySpan.all => l10n.adminSpanAll,
                ActivitySpan.day => l10n.adminSpanDay,
                ActivitySpan.week => l10n.adminSpanWeek,
              }),
              selected: _span == span,
              onSelected: (_) {
                setState(() => _span = span);
                _reset();
              },
            ),
        ],
      ),
    );

    return AdminScaffold(
      title: l10n.adminActivity,
      onRefresh: _reset,
      // The filter row is always a child, so the list is never "empty" in
      // AdminList's sense; the first load and the empty state are drawn here.
      child: AdminList(
        children: <Widget>[
          filters,
          if (_loading && _entries.isEmpty)
            Padding(
              padding: EdgeInsets.all(spacing.lg),
              child: const Center(child: CircularProgressIndicator()),
            ),
          for (final ActivityEntry entry in _entries)
            ActivityEntryRow(entry: entry),
          if (_error != null)
            Padding(
              padding: EdgeInsets.all(spacing.md),
              child: AdminNote(text: '$_error'),
            )
          else if (_entries.isEmpty && !_loading)
            Padding(
              padding: EdgeInsets.all(spacing.lg),
              child: AdminNote(text: l10n.adminNoActivity),
            ),
          if (!_done && _error == null && _entries.isNotEmpty)
            Center(
              child: Padding(
                padding: EdgeInsets.all(spacing.md),
                child: _loading
                    ? const CircularProgressIndicator()
                    : OutlinedButton(
                        onPressed: _loadMore,
                        child: Text(l10n.adminLoadMore),
                      ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One line of the activity log. Shared with an account's Activity tab.
class ActivityEntryRow extends StatelessWidget {
  const ActivityEntryRow({super.key, required this.entry});

  final ActivityEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = context.colors;
    final semantic = context.semantic;

    final (IconData icon, Color colour) = switch (entry.severity) {
      ActivitySeverity.error => (Icons.error_outline_rounded, scheme.error),
      ActivitySeverity.warning => (
        Icons.warning_amber_rounded,
        semantic.warning,
      ),
      ActivitySeverity.information => (
        Icons.info_outline_rounded,
        scheme.onSurfaceVariant,
      ),
    };

    return ListTile(
      leading: Icon(icon, color: colour),
      title: Text(entry.name),
      subtitle: Text(
        <String>[
          relativeTime(entry.at, l10n),
          // The server writes a second line on some events and not on
          // others; an empty one would just be a gap under the title.
          entry.overview,
        ].where((s) => s.isNotEmpty).join(' · '),
      ),
      isThreeLine: entry.overview.length > 40,
    );
  }
}
