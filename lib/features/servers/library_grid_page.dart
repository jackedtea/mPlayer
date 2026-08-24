// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../servers/media_library_source.dart';
import '../../widgets/poster_tile.dart';
import 'server_library.dart';

/// Screen 1e — one library, as a poster grid with filters.
///
/// Three columns on a phone; wider windows add columns rather than stretching
/// the posters, so a poster is always about the same physical size.
class LibraryGridPage extends ConsumerStatefulWidget {
  const LibraryGridPage({super.key, this.title = 'Movies', this.viewId});

  final String title;

  /// Which library to show. Null renders the empty state — the screen is
  /// always reached from a library tile, so a null id means the route was
  /// opened directly.
  final String? viewId;

  @override
  ConsumerState<LibraryGridPage> createState() => _LibraryGridPageState();
}

class _LibraryGridPageState extends ConsumerState<LibraryGridPage> {
  /// Off by default: a library opens showing everything in it. Hiding most
  /// of a collection until the user notices a chip is the wrong first
  /// impression.
  bool _unwatchedOnly = false;

  ServerSort _sort = ServerSort.name;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final scheme = context.colors;
    final l10n = AppLocalizations.of(context);

    final viewId = widget.viewId;
    final request = viewId == null
        ? const AsyncValue<List<ServerItem>>.data(<ServerItem>[])
        : ref.watch(libraryItemsProvider(LibraryQuery(viewId, _sort)));

    final all = request.value ?? const <ServerItem>[];
    final items = (_unwatchedOnly ? all.where((i) => !i.played) : all)
        .map(libraryItemFrom)
        .toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: scheme.surfaceContainerHigh,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(_titleFor(ref) ?? widget.title),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.grid_view_rounded),
            tooltip: 'View',
            onPressed: () => _notYet(context, 'View options'),
          ),
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: 'Search',
            onPressed: () => context.go('/search'),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: scheme.surfaceContainerHigh,
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: spacing.screenPadding(context.windowSize),
              children: <Widget>[
                FilterChip(
                  label: const Text('Unwatched'),
                  selected: _unwatchedOnly,
                  onSelected: (v) => setState(() => _unwatchedOnly = v),
                ),
                SizedBox(width: spacing.sm),
                _MenuChip(label: _sortLabel(l10n), onTap: _pickSort),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.fromLTRB(
              spacing.screenHorizontal(context.windowSize),
              spacing.md,
              spacing.screenHorizontal(context.windowSize),
              spacing.sm,
            ),
            child: Text(
              _unwatchedOnly
                  ? l10n.unwatchedCount(items.length)
                  : l10n.itemCount(items.length),
              style: context.texts.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.symmetric(
                horizontal: (spacing.screenHorizontal(context.windowSize) -
                        spacing.hitInset)
                    .clamp(0.0, double.infinity),
              ),
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                // ~108 poster + the ink ring; wider windows get more columns.
                maxCrossAxisExtent: 132,
                mainAxisSpacing: spacing.sm,
                crossAxisSpacing: 0,
                // Fixed height, not an aspect ratio: the cell width varies
                // with the window and would otherwise drag the height with it.
                mainAxisExtent: PosterTile.outerHeight(context, 142),
              ),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final entry = all.firstWhere((e) => e.id == items[i].id);
                return PosterTile(
                  item: items[i],
                  width: 108,
                  posterHeight: 142,
                  onTap: () => context.push(
                    entry.kind == ServerItemKind.series
                        ? '/library/series'
                        : '/library/movie',
                    extra: entry.id,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// The library's own name, once the views have loaded.
  String? _titleFor(WidgetRef ref) {
    final viewId = widget.viewId;
    if (viewId == null) return null;

    final views = ref.watch(serverViewsProvider).value ?? const <LibraryView>[];
    for (final LibraryView v in views) {
      if (v.id == viewId) return v.name;
    }
    return null;
  }

  String _sortLabel(AppLocalizations l10n) {
    return switch (_sort) {
      ServerSort.name => l10n.sortName,
      ServerSort.dateAdded => l10n.sortDateAdded,
      ServerSort.releaseDate => l10n.sortReleaseDate,
      ServerSort.datePlayed => l10n.sortDatePlayed,
      ServerSort.random => l10n.sortRandom,
    };
  }

  Future<void> _pickSort() async {
    final l10n = AppLocalizations.of(context);

    final chosen = await showModalBottomSheet<ServerSort>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final ServerSort option in ServerSort.values)
              ListTile(
                title: Text(switch (option) {
                  ServerSort.name => l10n.sortName,
                  ServerSort.dateAdded => l10n.sortDateAdded,
                  ServerSort.releaseDate => l10n.sortReleaseDate,
                  ServerSort.datePlayed => l10n.sortDatePlayed,
                  ServerSort.random => l10n.sortRandom,
                }),
                trailing:
                    option == _sort ? const Icon(Icons.check_rounded) : null,
                onTap: () => Navigator.of(sheetContext).pop(option),
              ),
          ],
        ),
      ),
    );

    if (chosen == null || !mounted) return;
    setState(() => _sort = chosen);
  }
}

/// Chip that opens a menu — the design draws these with a trailing caret.
class _MenuChip extends StatelessWidget {
  const _MenuChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(label),
          const SizedBox(width: 2),
          const Icon(Icons.expand_more_rounded, size: 18),
        ],
      ),
      onPressed: onTap,
    );
  }
}

void _notYet(BuildContext context, String what) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('$what — not implemented yet')),
  );
}
