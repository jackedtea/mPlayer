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
    final episodes = seriesId == null
        ? const <ServerItem>[]
        : ref.watch(seriesEpisodesProvider(seriesId)).value ??
            const <ServerItem>[];

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
    final tabs = _controllerFor(series.seasons.length);

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => <Widget>[
          SliverToBoxAdapter(
            child: BackdropHeader(
              seed: series.title,
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
                ],
              ),
              scheme.surface,
            ),
          ),
        ],
        body: TabBarView(
          controller: tabs,
          children: <Widget>[
            for (final Season season in series.seasons)
              ListView.builder(
                padding: EdgeInsets.symmetric(vertical: spacing.sm),
                itemCount: season.episodes.length,
                itemBuilder: (context, i) =>
                    _EpisodeRow(episode: season.episodes[i]),
              ),
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

class _EpisodeRow extends StatelessWidget {
  const _EpisodeRow({required this.episode});

  final Episode episode;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final scheme = context.colors;

    return InkWell(
      onTap: () => _notYet(context, 'Play episode ${episode.number}'),
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
