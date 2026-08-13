// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';

import '../../app/tokens.dart';
import '../../core/models/library_models.dart';
import '../../core/sample_library.dart';
import '../../widgets/backdrop_header.dart';
import '../../widgets/gradient_art.dart';

/// Screen 1g — a series, its seasons as tabs, and the episode list.
class SeriesPage extends StatefulWidget {
  const SeriesPage({super.key});

  @override
  State<SeriesPage> createState() => _SeriesPageState();
}

class _SeriesPageState extends State<SeriesPage>
    with SingleTickerProviderStateMixin {
  late final SeriesDetail _series = SampleLibrary.series;
  late final TabController _tabs =
      TabController(length: _series.seasons.length, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final scheme = context.colors;

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => <Widget>[
          SliverToBoxAdapter(
            child: BackdropHeader(
              seed: _series.title,
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
                  Text(_series.title, style: context.texts.headlineMedium),
                  SizedBox(height: spacing.xs),
                  Text(
                    _series.summary,
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
                controller: _tabs,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorWeight: 3,
                indicatorSize: TabBarIndicatorSize.label,
                tabs: <Widget>[
                  for (final Season s in _series.seasons) Tab(text: s.name),
                ],
              ),
              scheme.surface,
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabs,
          children: <Widget>[
            for (final Season season in _series.seasons)
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
