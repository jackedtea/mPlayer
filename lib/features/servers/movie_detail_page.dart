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
import '../../widgets/detail_header.dart';
import 'detail_sections.dart';
import 'item_action_row.dart';
import 'media_info_sheet.dart';
import 'server_library.dart';

/// Screen 1f — movie detail.
class MovieDetailPage extends ConsumerStatefulWidget {
  const MovieDetailPage({super.key, this.itemId});

  /// Null when the route was opened directly rather than from a tile.
  final String? itemId;

  @override
  ConsumerState<MovieDetailPage> createState() => _MovieDetailPageState();
}

class _MovieDetailPageState extends ConsumerState<MovieDetailPage> {
  bool _overviewExpanded = false;

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

    return Scaffold(
      // The primary action lives at the foot of the screen on a phone, where
      // a thumb reaches without shifting grip, and inline above the overview
      // on anything wider — a tablet or a desktop window is not held in one
      // hand, and the design puts the row under the backdrop there.
      bottomNavigationBar: compact
          ? ItemPrimaryActionBar(
              item: item,
              onPlay: () => playServerItem(context, ref, item.id),
              onStartOver: () =>
                  playServerItem(context, ref, item.id, fromStart: true),
            )
          : null,
      body: ListView(
        padding: EdgeInsets.only(
          bottom: spacing.xl * 2 + context.systemBottomInset,
        ),
        children: <Widget>[
          if (!compact)
            _wideHeader(item, movie)
          else ...<Widget>[
            BackdropHeader(
              seed: movie.title,
              artUrl: artUrlFor(ref, item, maxWidth: 900),
              height: 268,
              // No buttons up here any more. "More" held nothing that the
              // action row below does not now hold outright, and casting needs
              // a resolved stream and a position to start it from — it belongs
              // in the player, which has both and has the remote to go with it.
              //
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(movie.title, style: context.texts.headlineMedium),
                  SizedBox(height: spacing.sm),
                  _MetaRow(movie: movie),
                ],
              ),
            ),
            Padding(
              padding: padding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  ItemActionRow(
                    item: item,
                    primary: !compact,
                    onPlay: () => playServerItem(context, ref, item.id),
                    onStartOver: () =>
                        playServerItem(context, ref, item.id, fromStart: true),
                    playlistIds: <String>[item.id],
                    onMediaInfo: () => showMediaInfo(context, item.id),
                    // No shuffle: a film has no siblings to shuffle with, and
                    // the action is left out rather than shown doing nothing.
                  ),
                  if (movie.isStarted) ...<Widget>[
                    SizedBox(height: spacing.lg),
                    _ProgressLine(movie: movie),
                  ],
                  SizedBox(height: spacing.xl),
                  _Overview(
                    text: movie.overview,
                    expanded: _overviewExpanded,
                    onToggle: () =>
                        setState(() => _overviewExpanded = !_overviewExpanded),
                  ),
                ],
              ),
            ),
            SizedBox(height: spacing.lg),
            // Outside the page padding: the strip scrolls edge to edge and
            // supplies its own inset, so the last chip is not clipped by a
            // margin the user cannot scroll past.
            // Genres only, same as the series screen: the server's keywords
            // arrive in the same response and are far more numerous and far
            // less curated, so they bury the four words that say what the film
            // is.
            TagStrip(tags: item.genres, padding: padding),
          ],
          if (item.people.isNotEmpty) ...<Widget>[
            Padding(
              padding: padding.copyWith(top: spacing.xl, bottom: spacing.md),
              child: Text(l10n.cast, style: context.texts.titleMedium),
            ),
            PeopleStrip(people: item.people),
          ],
          SizedBox(height: spacing.xl),
          SimilarStrip(itemId: item.id, title: l10n.moreLikeThis),
        ],
      ),
    );
  }

  /// Past compact, the series screen's header: the backdrop across the top,
  /// the poster hanging off it, the titles and actions beside the poster and
  /// the overview beside those. The phone's header was the poster cropped to
  /// a strip with the title over it, a full-width Play under that and the
  /// overview under that again — on a desktop, a column of things down the
  /// left edge with the rest of the window empty.
  Widget _wideHeader(ServerItem item, MovieDetail movie) {
    final spacing = context.spacing;
    final scheme = context.colors;
    final l10n = AppLocalizations.of(context);
    final started = (item.position ?? Duration.zero) > Duration.zero;

    return Padding(
      padding: EdgeInsets.only(bottom: spacing.lg),
      child: DetailHeader(
        seed: movie.title,
        title: item.title,
        originalTitle: item.originalTitle,
        backdropUrl: backdropUrlFor(ref, item, maxWidth: 1920),
        posterUrl: artUrlFor(ref, item, maxWidth: 400),
        facts: <Widget>[
          if (movie.year.isNotEmpty)
            Text(
              movie.year,
              style: context.texts.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          if (movie.runtime.isNotEmpty)
            Text(
              movie.runtime,
              style: context.texts.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          if (movie.certificate.isNotEmpty)
            CertificateBox(certificate: movie.certificate),
          if (item.rating != null) RatingLabel(rating: item.rating!),
        ],
        // "Resume at 42m", where the series screen says how many episodes.
        caption: movie.resumeLabel,
        // A film is the one thing on this screen to play, so it keeps a
        // labelled button — "Play" or "Continue watching" — ahead of the
        // glyphs, where the series header can make do with a glyph.
        actionBar: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: spacing.sm,
          runSpacing: spacing.sm,
          children: <Widget>[
            FilledButton.icon(
              onPressed: () => playServerItem(context, ref, item.id),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(started ? l10n.continueWatching : l10n.play),
            ),
            if (started)
              IconButton(
                tooltip: l10n.startOver,
                icon: const Icon(Icons.replay_rounded),
                onPressed: () =>
                    playServerItem(context, ref, item.id, fromStart: true),
              ),
            ItemActionIcons(
              item: item,
              primary: false,
              alignment: WrapAlignment.start,
              onPlay: () => playServerItem(context, ref, item.id),
              playlistIds: <String>[item.id],
              onMediaInfo: () => showMediaInfo(context, item.id),
            ),
          ],
        ),
        aside: movie.overview.isEmpty && item.genres.isEmpty
            ? null
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (movie.overview.isNotEmpty)
                    _Overview(
                      text: movie.overview,
                      lines: 6,
                      expanded: _overviewExpanded,
                      onToggle: () => setState(
                        () => _overviewExpanded = !_overviewExpanded,
                      ),
                    ),
                  if (item.genres.isNotEmpty) ...<Widget>[
                    SizedBox(height: spacing.md),
                    TagStrip(tags: item.genres),
                  ],
                ],
              ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.movie});

  final MovieDetail movie;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final spacing = context.spacing;
    final style = context.texts.bodySmall?.copyWith(color: scheme.onSurface);

    // Only the parts the server filled in, with a dot between each pair. A
    // fixed row drew an empty outlined box for a missing certificate and a
    // trail of dots around fields that were never there — and quality is
    // never there, since the server states none.
    final parts = <Widget>[
      if (movie.rating.isNotEmpty)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.star_rounded,
              size: 15,
              color: context.semantic.ratingStar,
            ),
            const SizedBox(width: 3),
            Text(movie.rating, style: style),
          ],
        ),
      if (movie.year.isNotEmpty) Text(movie.year, style: style),
      if (movie.runtime.isNotEmpty) Text(movie.runtime, style: style),
      // Certificates are boxed rather than plain text so they cannot be
      // mistaken for part of the runtime.
      if (movie.certificate.isNotEmpty)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            border: Border.all(color: scheme.outline),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(movie.certificate, style: style),
        ),
      if (movie.quality.isNotEmpty) Text(movie.quality, style: style),
    ];

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: spacing.sm,
      runSpacing: spacing.xs,
      children: <Widget>[
        for (var i = 0; i < parts.length; i++) ...<Widget>[
          if (i > 0) Text('·', style: style),
          parts[i],
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
    final spacing = context.spacing;
    final scheme = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: movie.watchedFraction,
            minHeight: 4,
            backgroundColor: scheme.surfaceContainerHighest,
          ),
        ),
        SizedBox(height: spacing.sm),
        // The same sentence the primary button carries, so the two cannot
        // disagree about where the user got to.
        Text(
          movie.resumeLabel ?? '',
          style: context.texts.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
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
