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
import 'library_view_settings.dart';
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
  ///
  /// A collection's id works here too: the server answers `/Items?parentId=`
  /// with the collection's films exactly as it answers with a library's, so
  /// one screen covers both and a box set is browsed rather than played.
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

    final columns = columnsForWidth(
      ref.watch(libraryColumnsProvider),
      MediaQuery.sizeOf(context).width,
    );

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
            tooltip: l10n.gridSize,
            onPressed: _pickColumns,
          ),
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: l10n.navSearch,
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
                  label: Text(l10n.unwatched),
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
            child: request.isLoading && all.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final gutter =
                          (spacing.screenHorizontal(context.windowSize) -
                                  spacing.hitInset)
                              .clamp(0.0, double.infinity);
                      // The poster is whatever a cell leaves after the ink
                      // ring, so the column count is what the user asked for
                      // and the artwork follows it, rather than the other way
                      // round.
                      final cell =
                          (constraints.maxWidth - gutter * 2) / columns;
                      final posterWidth =
                          (cell - spacing.hitInset * 2).clamp(48.0, 400.0);
                      // The design's poster is 108x142; keeping that ratio
                      // means five columns look like three, only smaller.
                      final posterHeight = posterWidth * 142 / 108;

                      return GridView.builder(
                        padding: EdgeInsets.fromLTRB(
                          gutter,
                          0,
                          gutter,
                          spacing.md + context.systemBottomInset,
                        ),
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          mainAxisSpacing: spacing.sm,
                          crossAxisSpacing: 0,
                          // Fixed height, not an aspect ratio: the caption is
                          // two lines of text, whose height does not scale
                          // with the column width.
                          mainAxisExtent:
                              PosterTile.outerHeight(context, posterHeight),
                        ),
                        itemCount: items.length,
                        itemBuilder: (context, i) {
                          final entry =
                              all.firstWhere((e) => e.id == items[i].id);
                          return PosterTile(
                            item: items[i],
                            artUrl: artUrlFor(ref, entry, maxWidth: 300),
                            width: posterWidth,
                            posterHeight: posterHeight,
                            onTap: () => _open(entry),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  /// Opens whatever [entry] is.
  ///
  /// A collection is browsed, not played: it has no runtime, no stream and no
  /// resume point, and sending it to the movie screen is what drew a Play
  /// button over a box set with nothing behind it.
  void _open(ServerItem entry) {
    if (entry.kind.isBrowsable) {
      context.push(
        Uri(
          path: '/library',
          queryParameters: <String, String>{'title': entry.title},
        ).toString(),
        extra: entry.id,
      );
      return;
    }

    context.push(
      entry.kind == ServerItemKind.series ? '/library/series' : '/library/movie',
      extra: entry.id,
    );
  }

  Future<void> _pickColumns() async {
    final l10n = AppLocalizations.of(context);
    final current = ref.read(libraryColumnsProvider);

    final chosen = await showModalBottomSheet<int>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (var n = LibraryColumnsController.minColumns;
                n <= LibraryColumnsController.maxColumns;
                n++)
              ListTile(
                leading: const Icon(Icons.grid_view_rounded),
                title: Text(l10n.gridColumns(n)),
                trailing: n == current ? const Icon(Icons.check_rounded) : null,
                onTap: () => Navigator.of(sheetContext).pop(n),
              ),
          ],
        ),
      ),
    );

    if (chosen == null) return;
    await ref.read(libraryColumnsProvider.notifier).set(chosen);
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

