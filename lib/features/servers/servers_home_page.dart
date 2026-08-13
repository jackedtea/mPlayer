// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/tokens.dart';
import '../../core/models/library_models.dart';
import '../../core/sample_library.dart';
import '../../widgets/continue_watching_card.dart';
import '../../widgets/poster_tile.dart';
import '../../widgets/section_header.dart';

/// Screen 1d — the Server tab once a server is configured.
///
/// Reached from the empty state (1c) after a successful connection. Kept as a
/// separate page rather than a branch inside 1c so the empty state stays the
/// simple thing it is.
class ServersHomePage extends StatefulWidget {
  const ServersHomePage({super.key});

  @override
  State<ServersHomePage> createState() => _ServersHomePageState();
}

class _ServersHomePageState extends State<ServersHomePage> {
  int _filter = 0;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final scheme = context.colors;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(SampleLibrary.serverName),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: context.semantic.success,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: spacing.xs + 1),
                // A long hostname must ellipsize rather than push the app
                // bar's actions off the right edge.
                Flexible(
                  child: Text(
                    '${SampleLibrary.serverHost} · ${SampleLibrary.serverUser}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.cast_rounded),
            tooltip: 'Cast',
            onPressed: () => _notYet(context, 'Cast'),
          ),
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: 'Search this server',
            onPressed: () => context.go('/search'),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: spacing.sm),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: scheme.primaryContainer,
              child: Text(
                SampleLibrary.serverUser.characters.first.toUpperCase(),
                style: TextStyle(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.only(bottom: spacing.xl),
        children: <Widget>[
          _FilterChips(
            selected: _filter,
            onSelected: (i) => setState(() => _filter = i),
          ),
          SizedBox(height: spacing.sm),
          const SectionHeader(title: 'Next up'),
          _NextUpShelf(items: SampleLibrary.nextUp),
          SizedBox(height: spacing.sectionGap),
          const SectionHeader(title: 'Recently added'),
          const _RecentlyAddedShelf(),
          SizedBox(height: spacing.sectionGap),
          const SectionHeader(title: 'Libraries'),
          const _LibraryGrid(),
        ],
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.selected, required this.onSelected});

  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: spacing.screenPadding(context.windowSize),
        children: <Widget>[
          for (final (int i, String label)
              in SampleLibrary.libraryFilters.indexed)
            Padding(
              padding: EdgeInsets.only(right: spacing.sm),
              child: FilterChip(
                label: Text(label),
                selected: i == selected,
                onSelected: (_) => onSelected(i),
              ),
            ),
        ],
      ),
    );
  }
}

class _NextUpShelf extends StatelessWidget {
  const _NextUpShelf({required this.items});

  final List<dynamic> items;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final inset = spacing.hitInset;
    final side = (spacing.screenHorizontal(context.windowSize) - inset)
        .clamp(0.0, double.infinity);
    final gap = (spacing.cardGap - inset * 2).clamp(0.0, double.infinity);

    return SizedBox(
      height: ContinueWatchingCard.outerHeight(context),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: side),
        itemCount: SampleLibrary.nextUp.length,
        separatorBuilder: (_, _) => SizedBox(width: gap),
        itemBuilder: (context, i) => ContinueWatchingCard(
          item: SampleLibrary.nextUp[i],
          onTap: () => _notYet(context, SampleLibrary.nextUp[i].title),
        ),
      ),
    );
  }
}

class _RecentlyAddedShelf extends StatelessWidget {
  const _RecentlyAddedShelf();

  static const _posterWidth = 104.0;
  static const _posterHeight = 156.0;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final inset = spacing.hitInset;
    final side = (spacing.screenHorizontal(context.windowSize) - inset)
        .clamp(0.0, double.infinity);
    final gap = (spacing.cardGap - inset * 2).clamp(0.0, double.infinity);

    return SizedBox(
      height: PosterTile.outerHeight(context, _posterHeight),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: side),
        itemCount: SampleLibrary.recentlyAdded.length,
        separatorBuilder: (_, _) => SizedBox(width: gap),
        itemBuilder: (context, i) {
          final item = SampleLibrary.recentlyAdded[i];
          return PosterTile(
            item: item,
            width: _posterWidth,
            posterHeight: _posterHeight,
            onTap: () => context.push('/library/movie'),
          );
        },
      ),
    );
  }
}

class _LibraryGrid extends StatelessWidget {
  const _LibraryGrid();

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final scheme = context.colors;

    return Padding(
      padding: spacing.screenPadding(context.windowSize),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 260,
          mainAxisExtent: 76,
          mainAxisSpacing: spacing.md,
          crossAxisSpacing: spacing.md,
        ),
        itemCount: SampleLibrary.librarySections.length,
        itemBuilder: (context, i) {
          final LibrarySection section = SampleLibrary.librarySections[i];
          return Material(
            color: scheme.surfaceContainerLow,
            borderRadius: context.radii.cardAll,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => context.push(
              section.name == 'Shows' ? '/library/series' : '/library',
            ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: spacing.lg),
                child: Row(
                  children: <Widget>[
                    Icon(section.icon, color: scheme.primary),
                    SizedBox(width: spacing.md),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            section.name,
                            style: context.texts.bodyLarge,
                          ),
                          Text(
                            '${section.itemCount} items',
                            style: context.texts.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

void _notYet(BuildContext context, String what) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('$what — not implemented yet')),
  );
}
