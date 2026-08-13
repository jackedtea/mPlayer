// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';

import '../../app/tokens.dart';
import '../../core/models/library_models.dart';
import '../../core/sample_library.dart';
import '../../widgets/gradient_art.dart';

/// Screen 1n, active state — results grouped by the source they came from.
///
/// Grouping is not cosmetic: a filename match on a share and a metadata match
/// on a server are not comparable, so merging them into one ranked list would
/// invent a relevance order that does not exist. Each group also ends with its
/// own "show more", because each source paginates separately.
class SearchResultsView extends StatelessWidget {
  const SearchResultsView({super.key, required this.groups});

  final List<SearchResultGroup> groups;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    return ListView(
      padding: EdgeInsets.only(bottom: spacing.xl),
      children: <Widget>[
        Padding(
          padding: EdgeInsets.fromLTRB(
            spacing.screenHorizontal(context.windowSize),
            spacing.sm,
            spacing.screenHorizontal(context.windowSize),
            spacing.xs,
          ),
          child: Text(
            SampleLibrary.resultsSummary,
            style: context.texts.bodySmall
                ?.copyWith(color: context.colors.onSurfaceVariant),
          ),
        ),
        for (final SearchResultGroup group in groups) _Group(group: group),
      ],
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.group});

  final SearchResultGroup group;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final scheme = context.colors;
    final padding = spacing.screenPadding(context.windowSize);

    final posters =
        group.hits.where((h) => h.kind == SearchHitKind.poster).toList();
    final rows =
        group.hits.where((h) => h.kind != SearchHitKind.poster).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.fromLTRB(
            padding.left,
            spacing.md,
            padding.right,
            spacing.xs,
          ),
          child: Row(
            children: <Widget>[
              Icon(group.sourceKind.icon, size: 18, color: scheme.primary),
              SizedBox(width: spacing.sm),
              Expanded(
                child: Text(
                  group.sourceName,
                  style: context.texts.titleSmall
                      ?.copyWith(color: scheme.primary),
                ),
              ),
              Text(
                '${group.total}',
                style: context.texts.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        if (posters.isNotEmpty) _PosterRow(hits: posters),
        for (final SearchHit hit in rows) _HitRow(hit: hit),
        if (group.hiddenCount > 0)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: padding.left - 8),
            child: TextButton(
              onPressed: () => _notYet(
                context,
                'More results from ${group.sourceName}',
              ),
              child: Text(
                'Show ${group.hiddenCount} more from ${group.sourceName}',
              ),
            ),
          ),
      ],
    );
  }
}

class _PosterRow extends StatelessWidget {
  const _PosterRow({required this.hits});

  final List<SearchHit> hits;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    return SizedBox(
      height: 168,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: spacing.screenPadding(context.windowSize),
        itemCount: hits.length,
        separatorBuilder: (_, _) => SizedBox(width: spacing.md),
        itemBuilder: (context, i) {
          final hit = hits[i];
          return SizedBox(
            width: 96,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: ClipRRect(
                    borderRadius: context.radii.chipAll,
                    child: GradientArt(
                      seed: hit.title,
                      icon: Icons.movie_rounded,
                    ),
                  ),
                ),
                SizedBox(height: spacing.xs + 2),
                Text(
                  hit.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.texts.bodySmall
                      ?.copyWith(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HitRow extends StatelessWidget {
  const _HitRow({required this.hit});

  final SearchHit hit;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final scheme = context.colors;

    return InkWell(
      onTap: () => _notYet(context, hit.title),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: spacing.screenHorizontal(context.windowSize),
          vertical: spacing.sm,
        ),
        child: Row(
          children: <Widget>[
            _HitLeading(hit: hit),
            SizedBox(width: spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    hit.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.texts.bodyMedium
                        ?.copyWith(color: scheme.onSurface),
                  ),
                  Text(
                    hit.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.texts.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HitLeading extends StatelessWidget {
  const _HitLeading({required this.hit});

  final SearchHit hit;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final radii = context.radii;

    switch (hit.kind) {
      case SearchHitKind.file:
        // A file hit comes from a filesystem source, which has no artwork —
        // an icon rather than a gradient standing in for a thumbnail that
        // does not exist. Poster hits below come from a server and keep it.
        return Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: radii.chipAll,
          ),
          child: Icon(Icons.movie_rounded, size: 22, color: scheme.primary),
        );
      case SearchHitKind.folder:
        return Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: radii.chipAll,
          ),
          child: Icon(
            Icons.folder_rounded,
            size: 22,
            color: scheme.onPrimaryContainer,
          ),
        );
      case SearchHitKind.series:
        return Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: radii.chipAll,
          ),
          child: Icon(Icons.live_tv_rounded, size: 22, color: scheme.primary),
        );
      case SearchHitKind.poster:
        // Posters are drawn by _PosterRow, never as a row.
        return const SizedBox.shrink();
    }
  }
}

void _notYet(BuildContext context, String what) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('$what — not implemented yet')),
  );
}
