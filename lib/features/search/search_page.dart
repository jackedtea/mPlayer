// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';

import '../../app/tokens.dart';
import '../../core/models/media_models.dart';
import '../../core/sample_data.dart';
import '../../widgets/section_header.dart';
import '../../widgets/source_tile.dart';

/// Screen 1n, idle state — scoped search across device, shares and server.
///
/// Scope is the point of this screen: the user picks which sources to hit
/// before querying, and unreachable ones are shown greyed and skipped rather
/// than hidden, so a dead NAS never looks like missing results.
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  List<SearchScope> _scopes = List<SearchScope>.of(SampleData.searchScopes);
  final List<RecentSearch> _recents =
      List<RecentSearch>.of(SampleData.recentSearches);

  bool get _allSelected => _scopes.every((s) => s.enabled || !s.source.online);

  @override
  Widget build(BuildContext context) {
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
                hintText: 'Search everything',
                leading: Icon(
                  Icons.search_rounded,
                  color: context.colors.onSurfaceVariant,
                ),
                trailing: <Widget>[
                  IconButton(
                    icon: const Icon(Icons.mic_rounded),
                    tooltip: 'Voice search',
                    onPressed: () => _notYet(context, 'Voice search'),
                  ),
                ],
                onSubmitted: _runQuery,
              ),
            ),
            _ScopeChips(
              scopes: _scopes,
              allSelected: _allSelected,
              onToggleAll: _selectAll,
              onToggle: _toggleScope,
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.only(bottom: spacing.xl),
                children: <Widget>[
                  if (_recents.isNotEmpty) ...<Widget>[
                    SectionHeader(
                      title: 'Recent searches',
                      actionLabel: 'Clear',
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
                  const SectionHeader(title: 'Where to look'),
                  Padding(
                    padding: padding,
                    child: Column(
                      children: <Widget>[
                        for (final (int i, SearchScope scope)
                            in _scopes.indexed) ...<Widget>[
                          SourceTile(
                            source: scope.source,
                            subtitleOverride: scope.capability,
                            onTap: scope.source.online
                                ? () => _toggleScope(i)
                                : null,
                            trailing: Checkbox(
                              value: scope.enabled,
                              onChanged: scope.source.online
                                  ? (_) => _toggleScope(i)
                                  : null,
                            ),
                          ),
                          if (i != _scopes.length - 1)
                            SizedBox(height: spacing.sm),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleScope(int index) {
    final scope = _scopes[index];
    // An unreachable source cannot be searched; the chip stays inert.
    if (!scope.source.online) return;
    setState(() {
      _scopes[index] = scope.copyWith(enabled: !scope.enabled);
    });
  }

  void _selectAll() {
    setState(() {
      _scopes = <SearchScope>[
        for (final SearchScope s in _scopes)
          s.copyWith(enabled: s.source.online),
      ];
    });
  }

  void _runQuery(String query) {
    if (query.trim().isEmpty) return;
    _notYet(context, 'Search for "$query"');
  }
}

/// Scope chip row: "All sources" plus one chip per configured source.
class _ScopeChips extends StatelessWidget {
  const _ScopeChips({
    required this.scopes,
    required this.allSelected,
    required this.onToggleAll,
    required this.onToggle,
  });

  final List<SearchScope> scopes;
  final bool allSelected;
  final VoidCallback onToggleAll;
  final void Function(int index) onToggle;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final padding = spacing.screenPadding(context.windowSize);

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: padding,
        children: <Widget>[
          FilterChip(
            label: const Text('All sources'),
            selected: allSelected,
            onSelected: (_) => onToggleAll(),
          ),
          for (final (int i, SearchScope scope) in scopes.indexed)
            Padding(
              padding: EdgeInsets.only(left: spacing.sm),
              child: FilterChip(
                avatar: Icon(scope.source.kind.icon, size: 16),
                label: Text(scope.source.name.split(' · ').first),
                selected: scope.enabled,
                onSelected:
                    scope.source.online ? (_) => onToggle(i) : null,
              ),
            ),
        ],
      ),
    );
  }
}

void _notYet(BuildContext context, String what) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('$what — not implemented yet')),
  );
}
