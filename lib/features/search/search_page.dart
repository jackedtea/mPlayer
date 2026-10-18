// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/tokens.dart';
import '../../core/models/media_models.dart';
import '../../core/models/library_models.dart';
import '../../l10n/app_localizations.dart';
import '../../servers/media_library_source.dart';
import '../../servers/server_registry.dart';
import '../servers/server_library.dart';
import '../../widgets/section_header.dart';
import 'search_results.dart';

/// Screen 1n — search the signed-in server.
///
/// **It used to be scoped.** Scope was the point: the user picked which
/// sources to hit — device, each share, the server — with unreachable ones
/// shown greyed and skipped so a dead NAS never looked like missing results.
/// There is one source now, so the chip row and the "Where to look" list are
/// gone: a scope picker offering one scope cannot be set wrongly and cannot
/// be set usefully either.
///
/// Recent searches live for as long as the screen does. Persisting them would
/// mean writing what someone searched for to disk, and this screen is not
/// worth that.
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final List<RecentSearch> _recents = <RecentSearch>[];
  final TextEditingController _query = TextEditingController();

  /// Empty means the idle state; anything else shows grouped results.
  String _submitted = '';

  bool get _isActive => _submitted.isNotEmpty;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
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
                  // Voice search went with the microphone icon: it was never
                  // implemented, and a button that reports "not implemented
                  // yet" on a screen with one real control is noise.
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
            if (_isActive)
              Expanded(child: _ServerResults(query: _submitted))
            else
            Expanded(
              child: ListView(
                padding: EdgeInsets.only(bottom: spacing.xl),
                children: <Widget>[
                  if (_recents.isEmpty)
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        padding.left,
                        spacing.xl,
                        padding.right,
                        spacing.xl,
                      ),
                      child: Center(
                        child: Text(
                          l10n.searchThisServer,
                          textAlign: TextAlign.center,
                          style: context.texts.bodyMedium?.copyWith(
                            color: context.colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  if (_recents.isNotEmpty) ...<Widget>[
                    SectionHeader(
                      title: l10n.recentSearches,
                      actionLabel: l10n.clearAll,
                      onAction: () => setState(_recents.clear),
                    ),
                    for (final RecentSearch r in _recents)
                      ListTile(
                        contentPadding: padding,
                        leading: Icon(
                          Icons.history_rounded,
                          color: context.colors.onSurfaceVariant,
                        ),
                        title: Text(r.query),
                        trailing: Icon(
                          Icons.north_west_rounded,
                          size: 20,
                          color: context.colors.outline,
                        ),
                        onTap: () => _runQuery(r.query),
                      ),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: padding.left,
                        vertical: spacing.sm,
                      ),
                      child: const Divider(),
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

  void _runQuery(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    setState(() {
      _submitted = trimmed;
      _query.text = trimmed;
      // Most-recent-first, without duplicating an existing entry.
      _recents.removeWhere((r) => r.query == trimmed);
      _recents.insert(0, RecentSearch(trimmed));
    });
  }

  void _clearQuery() {
    setState(() {
      _submitted = '';
      _query.clear();
    });
  }
}

/// Results from the signed-in server.
///
/// Still grouped, with one group. The grouping is the design's decision and
/// it holds whether there is one source or three — and it is what says which
/// server a hit came from, once more than one can be signed in.
class _ServerResults extends ConsumerWidget {
  const _ServerResults({required this.query});

  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final profile = ref.watch(serverRegistryProvider).active;
    final request = ref.watch(serverSearchProvider(query));

    final items = request.value ?? const <ServerItem>[];

    if (request.isLoading && items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (items.isEmpty) {
      return Center(
        child: Text(
          l10n.noResults,
          style: context.texts.bodyMedium
              ?.copyWith(color: context.colors.onSurfaceVariant),
        ),
      );
    }

    return SearchResultsView(
      groups: <SearchResultGroup>[
        SearchResultGroup(
          sourceName: profile?.name ?? '',
          sourceKind: SourceKind.jellyfin,
          total: items.length,
          hits: <SearchHit>[
            for (final ServerItem item in items) searchHitFrom(item, l10n),
          ],
        ),
      ],
    );
  }
}
