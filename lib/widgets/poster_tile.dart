// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';

import '../app/tokens.dart';
import '../core/models/library_models.dart';
import 'gradient_art.dart';
import 'remote_art.dart';

/// Poster plus caption, used by the "Recently added" shelf (1d), the library
/// grid (1e) and the server group of search results (1n).
///
/// Like the resume card, the ink ring sits outside the poster so the hover
/// highlight does not hug the caption — callers subtract `hitInset` from their
/// own gaps. See [outerWidth].
class PosterTile extends StatelessWidget {
  const PosterTile({
    super.key,
    required this.item,
    required this.width,
    required this.posterHeight,
    this.onTap,
    this.artUrl,
    this.titleLines = defaultTitleLines,
  });

  /// Two, because one truncates most of what a media server holds: a title
  /// like "Loạt phim Thành Phố Động Vật" is three words past a poster's width
  /// and an ellipsis after the first is not a label.
  static const defaultTitleLines = 2;

  final LibraryItem item;

  /// Artwork from a server, drawn over the gradient. Null for anything the
  /// server has no image for, and for every local source.
  final Uri? artUrl;
  final double width;
  final double posterHeight;
  final VoidCallback? onTap;

  /// How many caption lines the tile reserves. Reserved, not maximum — the
  /// height is the same whether the title needs them, so a grid row stays
  /// level however long its neighbours' titles are.
  final int titleLines;

  static double outerWidth(BuildContext context, double width) =>
      width + context.spacing.hitInset * 2;

  /// The caption's text alone, without the gap above it.
  ///
  /// Rounded up per line and scaled with the user's text size — same
  /// reasoning as `ContinueWatchingCard.captionHeight`.
  ///
  /// Reserved, not measured: the box is this tall whether the title fills it
  /// or not. A caption that shrank to fit a one-line title would hand the
  /// spare height to the artwork above it, and a row of posters would come
  /// out at two different sizes depending on how long each title happened to
  /// be — which is exactly what it used to do.
  static double titleHeight(
    BuildContext context, {
    int lines = defaultTitleLines,
  }) {
    final scaler = MediaQuery.textScalerOf(context);
    final style = context.texts.bodySmall;
    final line = (scaler.scale(style?.fontSize ?? 12) * (style?.height ?? 16 / 12))
        .ceilToDouble();
    return line * lines;
  }

  /// The caption and the gap above it.
  static double captionHeight(
    BuildContext context, {
    int lines = defaultTitleLines,
  }) =>
      (context.spacing.sm - 2) + titleHeight(context, lines: lines);

  /// Footprint including the ink ring. Grids must pass this as
  /// `mainAxisExtent`: deriving cell height from an aspect ratio makes it
  /// depend on the column width, which varies with the window.
  static double outerHeight(
    BuildContext context,
    double posterHeight, {
    int titleLines = defaultTitleLines,
  }) =>
      posterHeight +
      captionHeight(context, lines: titleLines) +
      context.spacing.hitInset * 2;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final radii = context.radii;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(radii.chip + spacing.hitInset),
      child: Padding(
        padding: EdgeInsets.all(spacing.hitInset),
        child: SizedBox(
          width: width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // Flexible rather than fixed: a grid cell is rarely exactly the
              // requested height, and a hard SizedBox turns a 1px shortfall
              // into an overflow.
              Expanded(
                child: ClipRRect(
                  borderRadius: radii.chipAll,
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      GradientArt(seed: item.title, icon: Icons.movie_rounded),
                      // Over the gradient, which stays the artwork for
                      // anything the server has no image for.
                      RemoteArt(url: artUrl),
                      if (item.watched)
                        Positioned(
                          right: spacing.xs + 2,
                          top: spacing.xs + 2,
                          child: const _WatchedBadge(),
                        ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: spacing.sm - 2),
              // A fixed box, not a `Text` left to size itself. The artwork
              // above is `Expanded`, so whatever the caption does not take it
              // does — and a one-line title therefore grew its poster taller
              // than its two-line neighbour's, leaving every grid row ragged.
              SizedBox(
                height: titleHeight(context, lines: titleLines),
                width: double.infinity,
                child: Text(
                  item.title,
                  maxLines: titleLines,
                  overflow: TextOverflow.ellipsis,
                  style: context.texts.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: context.colors.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Corner tick marking an item as already seen — the library grid's
/// "Unwatched" filter is only meaningful if watched state is visible.
class _WatchedBadge extends StatelessWidget {
  const _WatchedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: context.colors.primary,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.check_rounded,
        size: 14,
        color: context.colors.onPrimary,
      ),
    );
  }
}
