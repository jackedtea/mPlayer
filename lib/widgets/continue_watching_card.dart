// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:io' show File;

import 'package:flutter/material.dart';

import '../app/tokens.dart';
import '../core/models/media_models.dart';
import 'gradient_art.dart';
import 'remote_art.dart';

/// 200x112 resume card: source badge top-left, centred play circle, and a 4px
/// progress bar pinned to the bottom of the thumbnail.
///
/// Shared by the Storage shelf (1a) and the Jellyfin "Next up" carousel (1d) —
/// the design uses the same card in both.
///
/// The whole card is one tap target, so its hover/press highlight is inset by
/// `spacing.hitInset` from the artwork and caption; without that the ink hugs
/// the text. The extra ring is *outside* the [width] the caller asks for —
/// use [outerWidth] and [outerHeight] when laying these out, and subtract
/// `2 * hitInset` from the surrounding gaps so the artwork still lands on the
/// design's 16pt margin and 12pt card gap.
class ContinueWatchingCard extends StatelessWidget {
  const ContinueWatchingCard({
    super.key,
    required this.item,
    this.onTap,
    this.width = 200,
    this.artHeight = 112,
    this.artUrl,
  });

  final ResumeItem item;

  /// Artwork from a server. A still captured on this device wins over it —
  /// the frame the user actually stopped on says more than a poster.
  final Uri? artUrl;
  final VoidCallback? onTap;
  final double width;
  final double artHeight;

  /// Caption is bodyMedium over bodySmall, with [AppSpacing.sm] between it and
  /// the artwork.
  ///
  /// Derived from the live text theme and the user's text scale rather than
  /// the design's 20/16 literals — the shelf has a fixed height, so at large
  /// system font sizes hard-coding these would overflow the row.
  static double captionHeight(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final texts = context.texts;

    // Rounded up per line: the engine lays a line box out on whole logical
    // pixels, so the raw fontSize * height product can land a fraction short
    // and overflow the fixed-height shelf by a hair.
    double lineHeight(TextStyle? style, double size, double factor) =>
        (scaler.scale(style?.fontSize ?? size) * (style?.height ?? factor))
            .ceilToDouble();

    return context.spacing.sm +
        lineHeight(texts.bodyMedium, 14, 20 / 14) +
        lineHeight(texts.bodySmall, 12, 16 / 12);
  }

  /// Footprint including the ink ring, for the shelf that lays these out.
  static double outerWidth(BuildContext context, {double width = 200}) =>
      width + context.spacing.hitInset * 2;

  static double outerHeight(
    BuildContext context, {
    double artHeight = 112,
  }) =>
      artHeight + captionHeight(context) + context.spacing.hitInset * 2;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final radii = context.radii;
    final scheme = context.colors;

    return InkWell(
      onTap: onTap,
      // Concentric with the artwork's radius once the inset is added.
      borderRadius: BorderRadius.circular(radii.card + spacing.hitInset),
      child: Padding(
        padding: EdgeInsets.all(spacing.hitInset),
        child: SizedBox(
          width: width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
            SizedBox(
              height: artHeight,
              child: ClipRRect(
                borderRadius: radii.cardAll,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    // The gradient stays underneath the still: it shows while
                    // the file is decoded, and remains the artwork for an
                    // item that never got one.
                    GradientArt(seed: item.title),
                    // Server artwork sits between the gradient and the
                    // captured still: a frame grabbed from this device is
                    // more useful than a poster, so it wins.
                    RemoteArt(url: artUrl),
                    if (item.thumbnailPath != null)
                      _Thumbnail(path: item.thumbnailPath!, width: width),
                    Center(
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.86),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.play_arrow_rounded,
                          size: 22,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                    Positioned(
                      left: spacing.sm,
                      top: spacing.sm,
                      child: _SourceBadge(
                        icon: item.sourceKind.icon,
                        label: item.sourceLabel,
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: LinearProgressIndicator(
                        value: item.progress,
                        minHeight: 4,
                        backgroundColor: Colors.white.withValues(alpha: 0.4),
                        valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: spacing.sm),
            Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.texts.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: scheme.onSurface,
              ),
            ),
            Text(
              item.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.texts.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The frame grabbed while the file was playing.
///
/// Decoded at the card's own size rather than the file's — these are stills
/// off a 4K frame, and a shelf of them at full resolution costs tens of
/// megabytes of image cache for artwork drawn 200pt wide.
///
/// A still can go missing between being written and being drawn: the OS may
/// clear application support, or the entry may predate its file being
/// removed. That is not an error worth showing, so the builder falls through
/// to the gradient already painted underneath.
class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.path, required this.width});

  final String path;
  final double width;

  @override
  Widget build(BuildContext context) {
    final ratio = MediaQuery.devicePixelRatioOf(context);

    return Image.file(
      File(path),
      fit: BoxFit.cover,
      cacheWidth: (width * ratio).round(),
      // Without this the image blinks back to the gradient on every rebuild
      // that re-resolves the file.
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );
  }
}

/// Dark pill over artwork naming the source the item streams from.
class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: context.semantic.scrimStrong,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              height: 1.2,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
