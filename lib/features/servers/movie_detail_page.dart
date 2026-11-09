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
import '../../widgets/collapsing_header.dart';
import '../../widgets/detail_header.dart';
import 'detail_sections.dart';
import 'item_action_row.dart';
import 'media_images.dart';
import 'media_info_sheet.dart';
import 'server_library.dart';

/// Screen 1f — movie detail.
///
/// The same layout as the series screen at every width: the backdrop with
/// the poster hanging off it, the facts beside the poster, the action glyphs
/// under them, and a toolbar that keeps the title once the header has
/// scrolled away. The phone used to crop the portrait poster into a 268dp
/// strip with the title over it, so a film and a series opened from the same
/// shelf looked like two different apps.
class MovieDetailPage extends ConsumerStatefulWidget {
  const MovieDetailPage({super.key, this.itemId});

  /// Null when the route was opened directly rather than from a tile.
  final String? itemId;

  @override
  ConsumerState<MovieDetailPage> createState() => _MovieDetailPageState();
}

class _MovieDetailPageState extends ConsumerState<MovieDetailPage> {
  bool _overviewExpanded = false;

  void _toggleOverview() =>
      setState(() => _overviewExpanded = !_overviewExpanded);

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final l10n = AppLocalizations.of(context);
    final itemId = widget.itemId;

    final request = itemId == null
        ? const AsyncValue<ServerItem?>.data(null)
        : ref.watch(serverItemProvider(itemId));

    final item = request.value;
    if (item == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: request.isLoading
              ? const CircularProgressIndicator()
              : Text(l10n.nothingToPlay),
        ),
      );
    }

    final movie = movieDetailFrom(item, l10n);
    final padding = spacing.screenPadding(context.windowSize);
    final compact = context.windowSize == WindowSize.compact;

    void play() => playServerItem(context, ref, item.id);
    void startOver() => playServerItem(context, ref, item.id, fromStart: true);

    return Scaffold(
      // The primary action lives at the foot of the screen on a phone, where
      // a thumb reaches without shifting grip; on anything wider it leads the
      // action row beside the poster.
      bottomNavigationBar: compact
          ? ItemPrimaryActionBar(
              item: item,
              label: movie.resumeLabel,
              onPlay: play,
              onStartOver: startOver,
            )
          : null,
      body: CustomScrollView(
        slivers: <Widget>[
          CollapsingHeaderSliver(
            title: item.title,
            header: DetailHeader(
              seed: movie.title,
              title: item.title,
              originalTitle: item.originalTitle,
              caption: _caption(item, movie),
              backdropUrl: backdropUrlFor(
                ref,
                item,
                maxWidth: compact ? 1000 : 1920,
              ),
              posterUrl: artUrlFor(ref, item, maxWidth: 400),
              facts: _facts(item, movie),
              actionBar: compact
                  ? ItemActionIcons(
                      item: item,
                      // Play is in the bar at the foot of the screen.
                      primary: false,
                      onPlay: play,
                      playlistIds: <String>[item.id],
                      onMediaInfo: () => showMediaInfo(context, item.id),
                      // No shuffle: a film has no siblings to shuffle with,
                      // and the action is left out rather than shown doing
                      // nothing.
                    )
                  : _wideActions(item, movie, play, startOver),
              aside: compact ? null : _aside(item, movie),
            ),
          ),
          if (movie.isStarted)
            SliverToBoxAdapter(
              child: Padding(
                padding: padding.copyWith(top: spacing.md, bottom: 0),
                child: _ProgressLine(movie: movie),
              ),
            ),
          if (compact && movie.overview.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: padding.copyWith(top: spacing.lg),
                child: _Overview(
                  text: movie.overview,
                  expanded: _overviewExpanded,
                  onToggle: _toggleOverview,
                ),
              ),
            ),
          // Genres only, same as the series screen: the server's keywords
          // arrive in the same response and are far more numerous and far
          // less curated, so they bury the four words that say what the film
          // is. Outside the page padding: the strip scrolls edge to edge and
          // supplies its own inset.
          if (compact && item.genres.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(bottom: spacing.sm),
                child: TagStrip(tags: item.genres, padding: padding),
              ),
            ),
          SliverList.list(
            children: <Widget>[
              if (item.people.isNotEmpty) ...<Widget>[
                Padding(
                  padding: padding.copyWith(
                    top: spacing.xl,
                    bottom: spacing.md,
                  ),
                  child: Text(l10n.cast, style: context.texts.titleMedium),
                ),
                PeopleStrip(people: item.people),
              ],
              MediaImagesStrip(
                itemId: item.id,
                padding: padding.copyWith(top: spacing.xl, bottom: 0),
              ),
              SizedBox(height: spacing.xl),
              SimilarStrip(itemId: item.id, title: l10n.moreLikeThis),
              ExternalLinks(
                links: item.links,
                padding: padding.copyWith(top: spacing.xl, bottom: 0),
              ),
              SizedBox(height: spacing.xl * 2 + context.systemBottomInset),
            ],
          ),
        ],
      ),
    );
  }

  /// Year, runtime, certificate and rating — only the ones the server filled
  /// in, so an absent certificate leaves no empty box behind.
  List<Widget> _facts(ServerItem item, MovieDetail movie) {
    final style = context.texts.bodyMedium?.copyWith(
      color: context.colors.onSurfaceVariant,
    );
    return <Widget>[
      if (movie.year.isNotEmpty) Text(movie.year, style: style),
      if (movie.runtime.isNotEmpty) Text(movie.runtime, style: style),
      if (movie.certificate.isNotEmpty)
        CertificateBox(certificate: movie.certificate),
      if (item.rating != null) RatingLabel(rating: item.rating!),
    ];
  }

  /// The muted line under the facts. An episode opened from a shelf lands
  /// here too, and says which one it is; a film says its quality where the
  /// server stated one.
  String? _caption(ServerItem item, MovieDetail movie) {
    if (item.kind == ServerItemKind.episode) {
      final code = episodeCode(item);
      return code.isEmpty ? null : code;
    }
    return movie.quality.isEmpty ? null : movie.quality;
  }

  /// Past compact, a film is the one thing on this screen to play, so it
  /// keeps a labelled button — "Play" or "Continue · 1:02:45" — ahead of the
  /// glyphs, where the series header can make do with a glyph.
  Widget _wideActions(
    ServerItem item,
    MovieDetail movie,
    VoidCallback play,
    VoidCallback startOver,
  ) {
    final spacing = context.spacing;
    final l10n = AppLocalizations.of(context);
    final started = (item.position ?? Duration.zero) > Duration.zero;

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: spacing.sm,
      runSpacing: spacing.sm,
      children: <Widget>[
        FilledButton.icon(
          onPressed: play,
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text(
            movie.resumeLabel ?? (started ? l10n.continueWatching : l10n.play),
          ),
        ),
        if (started)
          IconButton(
            tooltip: l10n.startOver,
            icon: const Icon(Icons.replay_rounded),
            onPressed: startOver,
          ),
        ItemActionIcons(
          item: item,
          primary: false,
          alignment: WrapAlignment.start,
          onPlay: play,
          playlistIds: <String>[item.id],
          onMediaInfo: () => showMediaInfo(context, item.id),
        ),
      ],
    );
  }

  /// The overview and the genres, for the column beside the titles on a
  /// wide window. Null when the film has neither.
  Widget? _aside(ServerItem item, MovieDetail movie) {
    if (movie.overview.isEmpty && item.genres.isEmpty) return null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (movie.overview.isNotEmpty)
          _Overview(
            text: movie.overview,
            lines: 6,
            expanded: _overviewExpanded,
            onToggle: _toggleOverview,
          ),
        if (item.genres.isNotEmpty) ...<Widget>[
          SizedBox(height: context.spacing.md),
          TagStrip(tags: item.genres),
        ],
      ],
    );
  }
}

class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.movie});

  final MovieDetail movie;

  @override
  Widget build(BuildContext context) {
    // The bar alone: the primary button already says where the user got to.
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: LinearProgressIndicator(
        value: movie.watchedFraction,
        minHeight: 4,
        backgroundColor: context.colors.surfaceContainerHighest,
      ),
    );
  }
}

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
            expanded
                ? AppLocalizations.of(context).less
                : AppLocalizations.of(context).more,
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
