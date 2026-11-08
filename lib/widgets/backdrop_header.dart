// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/tokens.dart';
import '../l10n/app_localizations.dart';
import 'gradient_art.dart';
import 'remote_art.dart';

/// Artwork with a scrim fading into the page surface, floating circular
/// controls over it, and the title block under it.
///
/// The title used to be laid over the bottom of the artwork at a fixed
/// height. On a bright still the scrim there was barely half the page colour,
/// so dark text sat on a light picture; and a two-line title under a tall
/// status bar or a large font grew upwards into the back button. Now the
/// artwork is [height] tall and the title starts [overlap] above its foot,
/// where the scrim is already almost the page colour, and the header grows
/// downwards with the title instead.
class BackdropHeader extends StatelessWidget {
  const BackdropHeader({
    super.key,
    required this.seed,
    required this.height,
    required this.child,
    this.actions = const <Widget>[],
    this.artUrl,
  });

  final String seed;

  /// Server artwork behind the scrim. Null falls back to the gradient, which
  /// the scrim was designed against in the first place.
  final Uri? artUrl;

  /// The artwork's height, status bar included.
  final double height;

  /// Title block, drawn under the artwork's faded foot.
  final Widget child;

  /// Rendered to the right of the back button as circular buttons.
  final List<Widget> actions;

  /// How far the title reaches up into the artwork.
  static const overlap = 40.0;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final scheme = context.colors;
    final edge = spacing.screenHorizontal(context.windowSize);

    // Where the title starts, as a fraction of the artwork. By there the
    // scrim is nearly opaque, whatever the picture is.
    final titleTop = ((height - overlap) / height).clamp(0.5, 0.95);

    return Stack(
      children: <Widget>[
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              GradientArt(seed: seed),
              RemoteArt(url: artUrl),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Colors.transparent,
                      scheme.surface.withValues(alpha: 0.92),
                      scheme.surface,
                    ],
                    stops: <double>[titleTop - 0.4, titleTop, 1.0],
                  ),
                ),
              ),
            ],
          ),
        ),
        // In the flow, so the header is as tall as the artwork plus whatever
        // the title needs below it.
        Padding(
          padding: EdgeInsets.fromLTRB(
            edge,
            height - overlap,
            edge,
            spacing.md,
          ),
          child: child,
        ),
        // Last, so the controls take taps over the artwork.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: spacing.md),
              child: Row(
                children: <Widget>[
                  CircleControl(
                    icon: Icons.arrow_back_rounded,
                    tooltip: AppLocalizations.of(context).actionBack,
                    onPressed: () {
                      if (context.canPop()) context.pop();
                    },
                  ),
                  const Spacer(),
                  for (final Widget action in actions) ...<Widget>[
                    SizedBox(width: spacing.sm),
                    action,
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 48 circular translucent button that stays legible over any artwork.
class CircleControl extends StatelessWidget {
  const CircleControl({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final isLight = scheme.brightness == Brightness.light;

    return Material(
      color: (isLight ? Colors.white : Colors.black).withValues(alpha: 0.85),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        icon: Icon(icon),
        iconSize: 22,
        color: scheme.onSurface,
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }
}
