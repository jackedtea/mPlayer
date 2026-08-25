// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/tokens.dart';
import '../../core/models/library_models.dart';
import '../../l10n/app_localizations.dart';
import '../../servers/media_library_source.dart';
import '../../widgets/backdrop_header.dart';
import '../../widgets/gradient_art.dart';
import 'detail_sections.dart';
import 'server_library.dart';

/// Screen 1g — a series, its seasons as tabs, and the episode list.
class SeriesPage extends ConsumerStatefulWidget {
  const SeriesPage({super.key, this.seriesId});

  /// Null when the route was opened directly rather than from a tile.
  final String? seriesId;

  @override
  ConsumerState<SeriesPage> createState() => _SeriesPageState();
}

class _SeriesPageState extends ConsumerState<SeriesPage>
    with SingleTickerProviderStateMixin {
  TabController? _tabs;

  bool _overviewExpanded = false;

  @override
  void dispose() {
    _tabs?.dispose();
    super.dispose();
  }

  /// Rebuilt whenever the number of seasons changes, which is once: the
  /// episodes arrive after the first frame, and a controller made for zero
  /// tabs cannot drive the tabs that follow.
  TabController _controllerFor(int seasons) {
    final existing = _tabs;
    if (existing != null && existing.length == seasons) return existing;

    existing?.dispose();
    return _tabs = TabController(length: seasons, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final scheme = context.colors;
    final l10n = AppLocalizations.of(context);
    final seriesId = widget.seriesId;

    final item = seriesId == null
        ? null
        : ref.watch(serverItemProvider(seriesId)).value;
    final episodeRequest = seriesId == null
        ? const AsyncValue<List<ServerItem>>.data(<ServerItem>[])
        : ref.watch(seriesEpisodesProvider(seriesId));
    final episodes = episodeRequest.value ?? const <ServerItem>[];

    if (item == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: seriesId == null
              ? Text(l10n.nothingToPlay)
              : const CircularProgressIndicator(),
        ),
      );
    }

    final series = seriesDetailFrom(item, episodes, l10n);
    // One tab past the seasons. The cast, the studio and what the server
    // suggests belong to the series rather than to any season of it, and
    // stacking them above the episode list would push the episodes — the
    // reason the screen exists — most of a screen down.
    final tabs = _controllerFor(series.seasons.length + 1);

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => <Widget>[
          SliverToBoxAdapter(
            child: BackdropHeader(
              seed: series.title,
              artUrl: artUrlFor(ref, item, maxWidth: 900),
              height: 196,
              actions: <Widget>[
                CircleControl(
                  icon: Icons.more_vert_rounded,
                  tooltip: 'More',
                  onPressed: () => _notYet(context, 'More'),
                ),
              ],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(series.title, style: context.texts.headlineMedium),
                  SizedBox(height: spacing.xs),
                  Text(
                    series.summary,
                    style: context.texts.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          if ((item.overview ?? '').isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: spacing.screenPadding(context.windowSize),
                child: _Overview(
                  text: item.overview!,
                  expanded: _overviewExpanded,
                  onToggle: () =>
                      setState(() => _overviewExpanded = !_overviewExpanded),
                ),
              ),
            ),
          if (item.genres.isNotEmpty || item.tags.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(bottom: spacing.sm),
                child: TagStrip(
                  tags: <String>[...item.genres, ...item.tags],
                  padding: spacing.screenPadding(context.windowSize),
                ),
              ),
            ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarHeader(
              TabBar(
                controller: tabs,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorWeight: 3,
                indicatorSize: TabBarIndicatorSize.label,
                tabs: <Widget>[
                  for (final Season s in series.seasons) Tab(text: s.name),
                  Tab(text: l10n.about),
                ],
              ),
              scheme.surface,
            ),
          ),
        ],
        body: TabBarView(
          controller: tabs,
          children: <Widget>[
            for (final (int s, Season season) in series.seasons.indexed)
              if (season.episodes.isEmpty && episodeRequest.isLoading)
                const Center(child: CircularProgressIndicator())
              else
                ListView.builder(
                  padding: EdgeInsets.only(
                    top: spacing.sm,
                    bottom: spacing.sm + context.systemBottomInset,
                  ),
                  itemCount: season.episodes.length,
                  itemBuilder: (context, i) {
                    // The rows are grouped copies of the flat list, so the
                    // item behind one is found by matching what identifies it
                    // rather than by an index into a list it is not in.
                    final source = _episodeAt(episodes, series, s, i);
                    return _EpisodeRow(
                      episode: season.episodes[i],
                      onTap: source == null
                          ? () {}
                          : () => playServerItem(context, ref, source.id),
                    );
                  },
                ),
            _AboutTab(item: item),
          ],
        ),
      ),
    );
  }
}

/// Keeps the season tabs pinned while the episode list scrolls under them.
class _TabBarHeader extends SliverPersistentHeaderDelegate {
  _TabBarHeader(this.tabBar, this.background);

  final TabBar tabBar;
  final Color background;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    return ColoredBox(color: background, child: tabBar);
  }

  @override
  bool shouldRebuild(_TabBarHeader old) =>
      old.tabBar != tabBar || old.background != background;
}

/// The server item behind the row at [index] of season [seasonIndex].
///
/// Matched on season and episode number rather than on position: the grouped
/// view and the flat list agree on those, and a special with no number would
/// otherwise shift everything after it.
ServerItem? _episodeAt(
  List<ServerItem> episodes,
  SeriesDetail series,
  int seasonIndex,
  int index,
) {
  final row = series.seasons[seasonIndex].episodes[index];
  for (final ServerItem item in episodes) {
    if (item.episodeNumber == row.number && item.title == row.title) {
      return item;
    }
  }
  return null;
}

class _EpisodeRow extends StatelessWidget {
  const _EpisodeRow({required this.episode, required this.onTap});

  final Episode episode;

  /// Resolves the episode through the server and opens the player.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final scheme = context.colors;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: spacing.screenHorizontal(context.windowSize),
          vertical: spacing.md,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _EpisodeThumb(episode: episode),
            SizedBox(width: spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    '${episode.number}. ${episode.title}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.texts.titleSmall
                        ?.copyWith(color: scheme.onSurface),
                  ),
                  SizedBox(height: spacing.xs / 2),
                  Text(
                    episode.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.texts.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  SizedBox(height: spacing.xs),
                  Text(
                    episode.meta,
                    style: context.texts.bodySmall
                        ?.copyWith(color: scheme.outline),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.download_for_offline_rounded),
              tooltip: 'Download',
              onPressed: () => _notYet(context, 'Download'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EpisodeThumb extends StatelessWidget {
  const _EpisodeThumb({required this.episode});

  final Episode episode;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return ClipRRect(
      borderRadius: context.radii.chipAll,
      child: SizedBox(
        width: 108,
        height: 62,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            GradientArt(seed: '${episode.number}${episode.title}'),
            Center(
              child: Icon(
                Icons.play_circle_rounded,
                size: 28,
                color: Colors.white.withValues(alpha: 0.86),
              ),
            ),
            // No bar at all on an unwatched episode — an empty track would
            // read as "started but at zero".
            if (episode.progress > 0)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: LinearProgressIndicator(
                  value: episode.progress,
                  minHeight: 3,
                  backgroundColor: Colors.white.withValues(alpha: 0.35),
                  valueColor:
                      AlwaysStoppedAnimation<Color>(scheme.primary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

void _notYet(BuildContext context, String what) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('$what — not implemented yet')),
  );
}

/// Everything about a series that is not one of its episodes.
class _AboutTab extends StatelessWidget {
  const _AboutTab({required this.item});

  final ServerItem item;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final scheme = context.colors;
    final l10n = AppLocalizations.of(context);
    final padding = spacing.screenPadding(context.windowSize);

    final facts = <(String, String)>[
      if (item.status != null && item.status!.isNotEmpty)
        (
          l10n.seriesStatus,
          switch (item.status) {
            'Continuing' => l10n.statusContinuing,
            'Ended' => l10n.statusEnded,
            // Anything the server invents is shown as it wrote it rather
            // than dropped.
            final String other => other,
            null => '',
          },
        ),
      if (item.studios.isNotEmpty) (l10n.studios, item.studios.join(', ')),
    ];

    return ListView(
      padding: EdgeInsets.only(
        top: spacing.md,
        bottom: spacing.xl * 2 + context.systemBottomInset,
      ),
      children: <Widget>[
        for (final (String label, String value) in facts)
          Padding(
            padding: padding.copyWith(top: 0, bottom: spacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  width: 96,
                  child: Text(
                    label,
                    style: context.texts.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
                Expanded(
                  child: Text(value, style: context.texts.bodySmall),
                ),
              ],
            ),
          ),
        if (item.people.isNotEmpty) ...<Widget>[
          Padding(
            padding: padding.copyWith(top: spacing.lg, bottom: spacing.md),
            child: Text(l10n.cast, style: context.texts.titleMedium),
          ),
          PeopleStrip(people: item.people),
        ],
        SizedBox(height: spacing.xl),
        SimilarStrip(itemId: item.id, title: l10n.moreLikeThis),
      ],
    );
  }
}

/// The series summary, three lines until it is tapped.
class _Overview extends StatelessWidget {
  const _Overview({
    required this.text,
    required this.expanded,
    required this.onToggle,
  });

  final String text;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final l10n = AppLocalizations.of(context);

    return GestureDetector(
      onTap: onToggle,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            text,
            maxLines: expanded ? null : 3,
            overflow: expanded ? null : TextOverflow.ellipsis,
            style: context.texts.bodyMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          Text(
            expanded ? l10n.showLess : l10n.showMore,
            style: context.texts.bodyMedium?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
