// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../servers/media_library_source.dart';
import '../../widgets/no_server_note.dart';
import '../../widgets/section_header.dart';
import '../servers/server_library.dart';
import 'kind_sections.dart';
import 'search_history.dart';

/// Bumped by the navigation bar when Search is tapped while already open.
///
/// The same gesture as Google Play's: the first tap opens the tab, the second
/// puts the cursor in the field. A counter rather than a flag, so every
/// re-tap is a change a listener sees, including the third and the fourth.
final ValueNotifier<int> searchFocusRequests = ValueNotifier<int>(0);

/// Screen 1n — search the signed-in server.
///
/// Laid out the way Jellyfin's own web client lays results out: a section per
/// kind — Movies, Shows, Episodes, People — each a row that scrolls sideways,
/// and a section with nothing in it not drawn at all. Before a search, the
/// last few that were run, each removable.
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final TextEditingController _query = TextEditingController();
  final FocusNode _focus = FocusNode();

  /// Empty means the idle state; anything else shows the results.
  String _submitted = '';

  bool get _isActive => _submitted.isNotEmpty;

  @override
  void initState() {
    super.initState();
    searchFocusRequests.addListener(_focusField);
  }

  @override
  void dispose() {
    searchFocusRequests.removeListener(_focusField);
    _focus.dispose();
    _query.dispose();
    super.dispose();
  }

  void _focusField() {
    if (!mounted) return;
    _focus.requestFocus();
    // The whole query selected, so typing replaces it — a re-tap is a new
    // search far more often than an edit of the last one.
    _query.selection =
        TextSelection(baseOffset: 0, extentOffset: _query.text.length);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final padding = spacing.screenPadding(context.windowSize);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.fromLTRB(
                padding.left,
                spacing.sm,
                padding.right,
                spacing.md,
              ),
              child: SearchBar(
                controller: _query,
                focusNode: _focus,
                hintText: l10n.searchEverything,
                // Back replaces the magnifier once a query is active, so
                // there is always a way out of the results.
                leading: IconButton(
                  icon: Icon(
                    _isActive
                        ? Icons.arrow_back_rounded
                        : Icons.search_rounded,
                  ),
                  color: context.colors.onSurfaceVariant,
                  tooltip: _isActive ? l10n.actionBack : l10n.navSearch,
                  onPressed: _isActive ? _clearQuery : null,
                ),
                trailing: <Widget>[
                  if (_isActive)
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      tooltip: l10n.actionClear,
                      onPressed: _clearQuery,
                    ),
                ],
                onSubmitted: _runQuery,
              ),
            ),
            Expanded(
              // The history is this device's own, so it is there with or
              // without a server; only results need one to ask.
              child: !_isActive
                  ? _History(onPick: _runQuery)
                  : ref.watch(connectedServerProvider) == null
                      ? const NoServerNote()
                      : _Results(query: _submitted),
            ),
          ],
        ),
      ),
    );
  }

  void _runQuery(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    setState(() {
      _submitted = trimmed;
      _query.text = trimmed;
    });
    ref.read(searchHistoryProvider.notifier).add(trimmed);
  }

  void _clearQuery() {
    setState(() {
      _submitted = '';
      _query.clear();
    });
  }
}

/// The recent searches, newest first, each with its own remove button.
class _History extends ConsumerWidget {
  const _History({required this.onPick});

  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final padding = spacing.screenPadding(context.windowSize);
    final scheme = context.colors;
    final history = ref.watch(searchHistoryProvider).value ?? const <String>[];

    if (history.isEmpty) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          padding.left,
          spacing.xl,
          padding.right,
          spacing.xl,
        ),
        child: Align(
          alignment: Alignment.topCenter,
          child: Text(
            l10n.searchThisServer,
            textAlign: TextAlign.center,
            style: context.texts.bodyMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.only(bottom: spacing.xl),
      children: <Widget>[
        SectionHeader(
          title: l10n.recentSearches,
          actionLabel: l10n.clearHistory,
          onAction: () => ref.read(searchHistoryProvider.notifier).clear(),
        ),
        for (final String query in history)
          ListTile(
            contentPadding: EdgeInsets.only(
              left: padding.left,
              right: padding.right - spacing.sm,
            ),
            leading: Icon(
              Icons.history_rounded,
              color: scheme.onSurfaceVariant,
            ),
            title: Text(query, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: IconButton(
              icon: const Icon(Icons.close_rounded),
              color: scheme.onSurfaceVariant,
              tooltip: l10n.removeFromHistory,
              onPressed: () =>
                  ref.read(searchHistoryProvider.notifier).remove(query),
            ),
            onTap: () => onPick(query),
          ),
      ],
    );
  }
}

/// What matched, a section per kind; a kind with nothing is left out.
class _Results extends ConsumerWidget {
  const _Results({required this.query});

  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    AsyncValue<List<ServerItem>> of(ServerItemKind kind) =>
        ref.watch(searchItemsProvider((query: query, kind: kind)));

    return KindSections(
      movies: of(ServerItemKind.movie),
      shows: of(ServerItemKind.series),
      episodes: of(ServerItemKind.episode),
      people: ref.watch(searchPeopleProvider(query)),
      emptyText: AppLocalizations.of(context).noResults,
    );
  }
}
