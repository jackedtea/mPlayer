// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/tokens.dart';
import '../l10n/app_localizations.dart';
import 'backdrop_header.dart';
import 'gradient_art.dart';
import 'remote_art.dart';

/// A wide backdrop with the poster hanging off its bottom-left corner, the
/// titles beside it, and the actions in a row underneath.
///
/// Replaces the scrim-and-title arrangement of [BackdropHeader] on the series
/// screen: a series' primary image is a portrait poster, and stretching that
/// across the top of the window cropped it to a chin and a shoulder. Here the
/// two pictures do the two jobs — the backdrop sets the scene, the poster is
/// the thing itself, and neither is asked to be the other's shape.
class DetailHeader extends StatelessWidget {
  const DetailHeader({
    super.key,
    required this.seed,
    required this.title,
    required this.actionBar,
    this.originalTitle,
    this.caption,
    this.facts = const <Widget>[],
    this.backdropUrl,
    this.posterUrl,
  });

  /// Decides the placeholder gradient's hue, so a title keeps its colour.
  final String seed;

  final String title;

  /// The title in the language it was made in. Null, or the same string as
  /// [title], draws nothing — a second line repeating the first is noise.
  final String? originalTitle;

  /// One muted line under the facts: "3 seasons · 28 episodes".
  final String? caption;

  /// The year range, the certificate and the rating, in that order. Wrapped
  /// rather than laid out in a row: three of them do not fit beside a poster
  /// on a narrow window, and a second line beats an overflow.
  final List<Widget> facts;

  /// Wide artwork. Null falls back to the gradient rather than to the poster,
  /// which is the wrong shape for the space.
  final Uri? backdropUrl;

  final Uri? posterUrl;

  /// What can be done to the item, drawn under the whole block.
  final Widget actionBar;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final scheme = context.colors;
    final texts = context.texts;
    final size = context.windowSize;
    final screenH = spacing.screenHorizontal(size);

    final posterWidth = size.isCompact ? 118.0 : 148.0;
    final posterHeight = posterWidth * 3 / 2;

    // How far the poster rises into the backdrop. Under a fifth of it: enough
    // to read as one block rather than two stacked panels, little enough that
    // the titles beside it still land on the page's own surface.
    final overlap = posterHeight * 0.18;

    final second = originalTitle?.trim() ?? '';
    final showsSecond = second.isNotEmpty && second != title;

    return LayoutBuilder(
      builder: (context, constraints) {
        // 16:9, which is the shape the server generates backdrops in, capped
        // so a desktop window does not open on half a screen of sky.
        final backdrop = math.min(constraints.maxWidth * 9 / 16, 280.0);

        return Stack(
          children: <Widget>[
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: backdrop,
              child: _Backdrop(seed: seed, artUrl: backdropUrl),
            ),
            Padding(
              padding: EdgeInsets.only(top: backdrop - overlap),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: screenH),
                    child: Row(
                      // The poster is what hangs into the picture; the words
                      // never do. Centring the two against each other looked
                      // right until a series with a second title and a long
                      // one made the text the taller of the two — and then it
                      // was the titles that rode up over the artwork and the
                      // poster that came unstuck from the corner it hangs off.
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _Poster(
                          seed: seed,
                          artUrl: posterUrl,
                          width: posterWidth,
                          height: posterHeight,
                        ),
                        SizedBox(width: spacing.lg),
                        Expanded(
                          child: Padding(
                            // Down past the seam the poster straddles, so the
                            // titles start on the page's own surface however
                            // many lines they run to.
                            padding: EdgeInsets.only(top: overlap + spacing.sm),
                            child: ConstrainedBox(
                              // Short titles centre against what is left of
                              // the poster instead of hanging from its top.
                              constraints: BoxConstraints(
                                minHeight: posterHeight - overlap - spacing.sm,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  Text(
                                    title,
                                    textAlign: TextAlign.center,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: texts.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (showsSecond) ...<Widget>[
                                    SizedBox(height: spacing.xs),
                                    Text(
                                      second,
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: texts.bodyMedium?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                  if (facts.isNotEmpty) ...<Widget>[
                                    SizedBox(height: spacing.md),
                                    Wrap(
                                      alignment: WrapAlignment.center,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      spacing: spacing.md,
                                      runSpacing: spacing.sm,
                                      children: facts,
                                    ),
                                  ],
                                  if ((caption ?? '').isNotEmpty) ...<Widget>[
                                    SizedBox(height: spacing.sm),
                                    Text(
                                      caption!,
                                      textAlign: TextAlign.center,
                                      style: texts.bodySmall?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: spacing.lg),
                  actionBar,
                ],
              ),
            ),
            // Last, so it stays reachable over both pictures.
            SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: spacing.md),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: CircleControl(
                    icon: Icons.arrow_back_rounded,
                    tooltip: AppLocalizations.of(context).actionBack,
                    onPressed: () {
                      if (context.canPop()) context.pop();
                    },
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The wide picture, ending in the colour of the page it sits on.
class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.seed, this.artUrl});

  final String seed;
  final Uri? artUrl;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        GradientArt(seed: seed),
        RemoteArt(url: artUrl),
        // Only the bottom third, unlike the old header: nothing is written
        // over the middle of this picture any more, so darkening it would
        // cost the artwork for nothing. The fade is there to end the picture
        // in the page's own colour rather than at a visible seam.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                Colors.transparent,
                scheme.surface.withValues(alpha: 0.7),
                scheme.surface,
              ],
              stops: const <double>[0.62, 0.88, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}

class _Poster extends StatelessWidget {
  const _Poster({
    required this.seed,
    required this.width,
    required this.height,
    this.artUrl,
  });

  final String seed;
  final Uri? artUrl;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: context.radii.cardAll,
        // The poster hangs half over a picture and half over the page, and
        // without a shadow the half over the page has no edge at all.
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: context.radii.cardAll,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            GradientArt(seed: seed),
            RemoteArt(url: artUrl),
          ],
        ),
      ),
    );
  }
}

/// The certificate, in the filled box the design draws it in.
class CertificateBox extends StatelessWidget {
  const CertificateBox({super.key, required this.certificate});

  final String certificate;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.spacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: context.radii.chipAll,
      ),
      child: Text(
        certificate,
        style: context.texts.labelMedium?.copyWith(color: scheme.onSurface),
      ),
    );
  }
}

/// "7.7" beside a star.
class RatingLabel extends StatelessWidget {
  const RatingLabel({super.key, required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(Icons.star_rounded, size: 18, color: context.semantic.ratingStar),
        SizedBox(width: context.spacing.xs),
        Text(
          rating.toStringAsFixed(1),
          style: context.texts.bodyMedium?.copyWith(
            color: context.colors.onSurface,
          ),
        ),
      ],
    );
  }
}
