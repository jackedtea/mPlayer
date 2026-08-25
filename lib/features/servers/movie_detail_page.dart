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

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.only(
          bottom: spacing.xl * 2 + context.systemBottomInset,
        ),
        children: <Widget>[
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
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.movie});

  final MovieDetail movie;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final spacing = context.spacing;
    final style = context.texts.bodySmall?.copyWith(color: scheme.onSurface);

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: spacing.sm,
      runSpacing: spacing.xs,
      children: <Widget>[
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
        Text('·', style: style),
        Text(movie.year, style: style),
        Text('·', style: style),
        Text(movie.runtime, style: style),
        Text('·', style: style),
        // Certificates are boxed rather than plain text so they cannot be
        // mistaken for part of the runtime.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            border: Border.all(color: scheme.outline),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(movie.certificate, style: style),
        ),
        Text('·', style: style),
        Text(movie.quality, style: style),
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
  });

  final String text;
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
            maxLines: expanded ? null : 3,
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
