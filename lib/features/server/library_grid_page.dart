// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/tokens.dart';
import '../../core/sample_library.dart';
import '../../widgets/poster_tile.dart';

/// Screen 1e — one library, as a poster grid with filters.
///
/// Three columns on a phone; wider windows add columns rather than stretching
/// the posters, so a poster is always about the same physical size.
class LibraryGridPage extends StatefulWidget {
  const LibraryGridPage({super.key, this.title = 'Movies'});

  final String title;

  @override
  State<LibraryGridPage> createState() => _LibraryGridPageState();
}

class _LibraryGridPageState extends State<LibraryGridPage> {
  bool _unwatchedOnly = true;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final scheme = context.colors;

    final items = _unwatchedOnly
        ? SampleLibrary.movieLibrary.where((i) => !i.watched).toList()
        : SampleLibrary.movieLibrary;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: scheme.surfaceContainerHigh,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(widget.title),
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
                _MenuChip(label: 'Genre', onTap: () => _notYet(context, 'Genre')),
                SizedBox(width: spacing.sm),
                _MenuChip(label: 'A–Z', onTap: () => _notYet(context, 'Sort')),
                SizedBox(width: spacing.sm),
                ActionChip(
                  avatar: const Icon(Icons.tune_rounded, size: 18),
                  label: const Text('Filters'),
                  onPressed: () => _notYet(context, 'Filters'),
                ),
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
                  ? '${items.length} unwatched'
                  : SampleLibrary.movieLibraryMeta,
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
              itemBuilder: (context, i) => PosterTile(
                item: items[i],
                width: 108,
                posterHeight: 142,
                onTap: () => context.push('/library/movie'),
              ),
            ),
          ),
        ],
      ),
    );
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
