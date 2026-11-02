// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/tokens.dart';
import '../../core/models/library_models.dart';
import '../../l10n/app_localizations.dart';
import '../../servers/media_library_source.dart';
import '../../widgets/detail_header.dart';
import '../../widgets/gradient_art.dart';
import '../../widgets/remote_art.dart';
import 'detail_sections.dart';
import 'item_action_row.dart';
import 'media_info_sheet.dart';
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
        // Not the single-ticker mixin: [_controllerFor] replaces the controller
        // once the episodes land, and the replacement needs a ticker of its own.
        with
        TickerProviderStateMixin {
  TabController? _tabs;

  bool _overviewExpanded = false;

  /// The header's natural height, measured once it has laid out. Until then
  /// it is drawn as a plain sliver; after, it is the collapsing header with
  /// the pinned toolbar, which needs its full height to know how far to
  /// collapse. Re-measured whenever it changes, as it does on rotation.
  double? _headerHeight;

  void _setHeaderHeight(Size size) {
    if (!mounted || _headerHeight == size.height) return;
    setState(() => _headerHeight = size.height);
  }

  @override
  void dispose() {
    _tabs?.dispose();
    super.dispose();
  }

  /// Plays whatever the viewer should see next.
  ///
  /// A series is not a stream: "Continue" on one has to resolve to an
  /// episode. The part-watched one comes first, then the first unwatched,
  /// then the very first — which is also what a fresh series does.
  void _playNext(List<ServerItem> episodes, ServerItem series) {
    final next = nextEpisodeOf(episodes);
    if (next != null) playServerItem(context, ref, next.id);
  }

  /// The header as a sliver: measured on its first layout, then collapsing
  /// under a pinned toolbar that keeps [title] on screen.
  Widget _headerSliver(String title, Widget header) {
    final measured = _headerHeight;
    if (measured == null) {
      return SliverToBoxAdapter(
        child: MeasureSize(onSize: _setHeaderHeight, child: header),
      );
    }
    return SliverPersistentHeader(
      pinned: true,
      delegate: _CollapsingHeader(
        header: header,
        height: measured,
        title: title,
        topInset: context.systemTopInset,
        background: context.colors.surface,
        brightness: Theme.of(context).brightness,
        backTooltip: AppLocalizations.of(context).actionBack,
        onSize: _setHeaderHeight,
      ),
    );
  }

  /// The overview and the genres, for the column beside the titles. Null
  /// when the series has neither.
  Widget? _aside(ServerItem item) {
    final overview = item.overview ?? '';
    if (overview.isEmpty && item.genres.isEmpty) return null;
    final spacing = context.spacing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (overview.isNotEmpty)
          _Overview(
            text: overview,
            // More room up here than in a full-width line under the header,
            // and the titles beside it are taller than three lines anyway.
            lines: 6,
            expanded: _overviewExpanded,
            onToggle: () =>
                setState(() => _overviewExpanded = !_overviewExpanded),
          ),
        if (item.genres.isNotEmpty) ...<Widget>[
          SizedBox(height: spacing.md),
          TagStrip(tags: item.genres),
        ],
      ],
    );
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

    // The seasons are grouped out of the episode list, so until that request
    // lands there are no season tabs to draw — and the screen showed nothing
    // but "About", which reads as a series that has no episodes rather than
    // one whose episodes are still on their way.
    final loadingSeasons = episodeRequest.isLoading && episodes.isEmpty;

    // One tab past the seasons. The cast, the studio and what the server
    // suggests belong to the series rather than to any season of it, and
    // stacking them above the episode list would push the episodes — the
    // reason the screen exists — most of a screen down.
    final tabs = _controllerFor(series.seasons.length + 1);
    final compact = context.windowSize == WindowSize.compact;

    return Scaffold(
      // Play sits at the foot of the screen on a phone. The series header is
      // a poster beside a block of facts, so the glyph row under it is most
      // of a screen down on a tall display — and it scrolls away the moment
      // the user reaches the episode list, which is the reason they came.
      bottomNavigationBar: compact
          ? ItemPrimaryActionBar(
              // The episode, not the series: it is what has a position, so
              // the label reads "Continue watching" when there is one.
              item: nextEpisodeOf(episodes) ?? item,
              caption: nextEpisodeCaption(nextEpisodeOf(episodes), l10n),
              onPlay: () => _playNext(episodes, item),
            )
          : null,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => <Widget>[
          _headerSliver(
            item.title,
            DetailHeader(
              seed: series.title,
              title: item.title,
              originalTitle: item.originalTitle,
              // The seasons and the unwatched count, which the old header
              // carried under the title and this one carries under the facts:
              // the tabs say how many seasons there are, but only after the
              // episodes have arrived.
              caption: series.summary,
              // Full width on a desktop now; 1000 was upscaled there.
              backdropUrl: backdropUrlFor(
                ref,
                item,
                maxWidth: compact ? 1000 : 1920,
              ),
              posterUrl: artUrlFor(ref, item, maxWidth: 400),
              facts: <Widget>[
                if (_yearRange(item).isNotEmpty)
                  Text(
                    _yearRange(item),
                    style: context.texts.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                if ((item.certificate ?? '').isNotEmpty)
                  CertificateBox(certificate: item.certificate!),
                if (item.rating != null) RatingLabel(rating: item.rating!),
              ],
              // Beside the titles on a wide window; under the header, in the
              // slivers below, on a phone.
              aside: compact ? null : _aside(item),
              // No "More" up here either: everything it would have held is
              // in the row itself, or one tap into its overflow.
              actionBar: ItemActionIcons(
                item: item,
                primary: !compact,
                alignment: compact ? WrapAlignment.center : WrapAlignment.start,
                seriesId: item.id,
                // Continue where the series is, which is whichever episode
                // the server is holding a position for — not the series
                // itself, which has no stream of its own.
                onPlay: () => _playNext(episodes, item),
                shuffleFrom: episodes,
                playlistIds: <String>[
                  for (final ServerItem e in episodes) e.id,
                ],
                downloadsAll: true,
              ),
            ),
          ),
          if (compact && (item.overview ?? '').isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: spacing
                    .screenPadding(context.windowSize)
                    .copyWith(top: spacing.lg),
                child: _Overview(
                  text: item.overview!,
                  expanded: _overviewExpanded,
                  onToggle: () =>
                      setState(() => _overviewExpanded = !_overviewExpanded),
                ),
              ),
            ),
          // Genres only. The server's keywords ride along in the same
          // response and there are dozens of them per series — "affectation",
          // "co-workers relationship" — none of which say what the thing is.
          // A row that has to be scrolled past to find "Comedy" is worse than
          // one that only ever holds the four words that matter.
          if (compact && item.genres.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(bottom: spacing.sm),
                child: TagStrip(
                  tags: item.genres,
                  padding: spacing.screenPadding(context.windowSize),
                ),
              ),
            ),
          if (!loadingSeasons)
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
                background: scheme.surface,
                divider: context.semantic.divider,
              ),
            ),
        ],
        body: loadingSeasons
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
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
                            item: source,
                            seriesId: item.id,
                            siblings: episodes,
                            // The server holds a still per episode, not just the
                            // series poster: `ImageTags.Primary` on an Episode is
                            // that frame. The row drew the gradient placeholder and
                            // nothing else, so every episode looked alike.
                            artUrl: source == null
                                ? null
                                : artUrlFor(ref, source, maxWidth: 320),
                            // The row opens the episode, where the tracks can be
                            // chosen before anything starts; the glyph beside it
                            // skips that for the common case of just watching.
                            onTap: source == null
                                ? () {}
                                : () => context.push(
                                    '/library/episode',
                                    extra: source.id,
                                  ),
                            onPlay: source == null
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

/// "2023 - 2026", or "2023" for a series that has not ended.
///
/// The server only dates the end of a series that has one, so a continuing
/// one is a single year rather than an open range — "2023 -" reads as a
/// missing number.
String _yearRange(ServerItem item) {
  final start = item.year;
  if (start == null) return '';

  final end = item.endYear;
  return end == null || end == start ? '$start' : '$start - $end';
}

/// Keeps the season tabs pinned while the episode list scrolls under them —
/// directly below the collapsed toolbar, which is what keeps them clear of
/// the status bar.
class _TabBarHeader extends SliverPersistentHeaderDelegate {
  _TabBarHeader(this.tabBar, {required this.background, required this.divider});

  final TabBar tabBar;
  final Color background;
  final Color divider;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        // A hairline only once the episodes are scrolling under it, the cue
        // that the tabs are now holding still.
        border: overlaps ? Border(bottom: BorderSide(color: divider)) : null,
      ),
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_TabBarHeader old) =>
      old.tabBar != tabBar ||
      old.background != background ||
      old.divider != divider;
}

/// The series header, scrolling away under a toolbar that keeps the title.
///
/// The backdrop, poster and facts scroll up as they always did; over the last
/// stretch of the collapse a solid bar fades in under the status bar with the
/// back arrow and the series' name, and stays pinned there. The page runs
/// edge to edge for the backdrop, and this bar is also what keeps everything
/// pinned below it — the season tabs — out from under the clock.
class _CollapsingHeader extends SliverPersistentHeaderDelegate {
  _CollapsingHeader({
    required this.header,
    required this.height,
    required this.title,
    required this.topInset,
    required this.background,
    required this.brightness,
    required this.backTooltip,
    required this.onSize,
  });

  final Widget header;

  /// The header's measured natural height.
  final double height;
  final String title;
  final double topInset;
  final Color background;
  final Brightness brightness;
  final String backTooltip;
  final ValueChanged<Size> onSize;

  /// How much of the collapse the toolbar takes to fade in.
  static const _fade = 48.0;

  @override
  double get minExtent => topInset + kToolbarHeight;

  @override
  double get maxExtent => height < minExtent ? minExtent : height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    final range = maxExtent - minExtent;
    final shown = range <= 0
        ? 1.0
        : ((shrinkOffset - (range - _fade)) / _fade).clamp(0.0, 1.0);

    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // At its natural height, slid up by however far the page has
          // scrolled — so it scrolls rather than squashing — and measured
          // again in case that height changes.
          Positioned(
            top: -shrinkOffset,
            left: 0,
            right: 0,
            child: MeasureSize(onSize: onSize, child: header),
          ),
          if (shown > 0)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: minExtent,
              child: IgnorePointer(
                ignoring: shown < 0.5,
                child: Opacity(
                  opacity: shown,
                  child: _annotated(
                    shown >= 0.5,
                    Material(
                      color: background,
                      child: Padding(
                        padding: EdgeInsets.only(top: topInset),
                        child: Row(
                          children: <Widget>[
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.arrow_back_rounded),
                              tooltip: backTooltip,
                              onPressed: () {
                                if (context.canPop()) context.pop();
                              },
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.texts.titleLarge,
                              ),
                            ),
                            const SizedBox(width: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Status-bar icons for the page colour once the bar is mostly in; until
  /// then the backdrop under them annotates its own.
  Widget _annotated(bool solid, Widget child) {
    if (!solid) return child;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: child,
    );
  }

  @override
  bool shouldRebuild(_CollapsingHeader old) => true;
}

/// Reports its child's size after every layout that changes it.
///
/// Used for the series header, whose height depends on its title, facts and
/// the window's width, and which the collapsing header needs before it can
/// say how far to collapse.
class MeasureSize extends SingleChildRenderObjectWidget {
  const MeasureSize({super.key, required this.onSize, required super.child});

  final ValueChanged<Size> onSize;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderMeasureSize(onSize);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderMeasureSize renderObject,
  ) {
    renderObject.onSize = onSize;
  }
}

class RenderMeasureSize extends RenderProxyBox {
  RenderMeasureSize(this.onSize);

  ValueChanged<Size> onSize;
  Size? _last;

  @override
  void performLayout() {
    super.performLayout();
    if (size == _last) return;
    _last = size;
    // After the frame: reporting during layout would ask for a rebuild in
    // the middle of one.
    final reported = size;
    WidgetsBinding.instance.addPostFrameCallback((_) => onSize(reported));
  }
}

/// What a series' Play button plays: the episode part-watched, then the first
/// unwatched, then the very first — which is also what a fresh series does.
ServerItem? nextEpisodeOf(List<ServerItem> episodes) {
  if (episodes.isEmpty) return null;

  final started = episodes
      .where((e) => (e.position ?? Duration.zero) > Duration.zero && !e.played)
      .firstOrNull;
  final unwatched = episodes.where((e) => !e.played).firstOrNull;
  return started ?? unwatched ?? episodes.first;
}

/// "S1E3 · The Long Night · 41m left" — the line under Play.
String? nextEpisodeCaption(ServerItem? episode, AppLocalizations l10n) {
  if (episode == null) return null;
  final parts = <String>[
    episodeCode(episode),
    episode.title,
    remainingLabel(episode, l10n),
  ].where((p) => p.trim().isNotEmpty).toList();
  return parts.isEmpty ? null : parts.join(' · ');
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
  const _EpisodeRow({
    required this.episode,
    required this.onTap,
    required this.onPlay,
    this.item,
    this.seriesId,
    this.siblings = const <ServerItem>[],
    this.artUrl,
  });

  final Episode episode;

  /// The server item behind this row. Null when the grouped list and the flat
  /// one could not be matched up, which leaves the row readable but inert.
  final ServerItem? item;

  final String? seriesId;

  /// What "shuffle" plays: every episode of the series, not only this season.
  final List<ServerItem> siblings;

  /// The episode's own still, or null where the server has none.
  final Uri? artUrl;

  /// Opens the episode's own screen.
  final VoidCallback onTap;

  /// Resolves the episode through the server and opens the player.
  final VoidCallback onPlay;

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
            // The still carries a play glyph, so it plays. It used to open
            // the episode's screen like the rest of the row — a button that
            // says one thing and does another.
            InkWell(
              onTap: onPlay,
              borderRadius: context.radii.chipAll,
              child: _EpisodeThumb(episode: episode, artUrl: artUrl),
            ),
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
                    style: context.texts.titleSmall?.copyWith(
                      color: scheme.onSurface,
                    ),
                  ),
                  SizedBox(height: spacing.xs / 2),
                  Text(
                    episode.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.texts.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  SizedBox(height: spacing.xs),
                  Text(
                    episode.meta,
                    style: context.texts.bodySmall?.copyWith(
                      color: scheme.outline,
                    ),
                  ),
                ],
              ),
            ),
            // No play button here: the still is the play affordance now, and
            // two of them on one row is one too many. This is where the rest
            // of what can be done to an episode lives.
            if (item != null)
              ItemActionMenu(
                item: item!,
                seriesId: seriesId,
                shuffleFrom: siblings,
                onMediaInfo: () => showMediaInfo(context, item!.id),
              ),
          ],
        ),
      ),
    );
  }
}

class _EpisodeThumb extends StatelessWidget {
  const _EpisodeThumb({required this.episode, this.artUrl});

  final Episode episode;
  final Uri? artUrl;

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
            // Over the gradient, which stays the picture for an episode the
            // server has no still for. Same arrangement as `PosterTile`:
            // `RemoteArt` draws nothing while it loads and nothing on
            // failure, so there is always something underneath it.
            RemoteArt(url: artUrl),
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
                  valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
                ),
              ),
          ],
        ),
      ),
    );
  }
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
                    style: context.texts.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Expanded(child: Text(value, style: context.texts.bodySmall)),
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
    this.lines = 3,
  });

  final String text;

  /// How many lines show before "More".
  final int lines;
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
            maxLines: expanded ? null : lines,
            overflow: expanded ? null : TextOverflow.ellipsis,
            style: context.texts.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          Text(
            expanded ? l10n.less : l10n.more,
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
