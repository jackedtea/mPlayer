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

/// Artwork header with a scrim fading into the page surface, plus floating
/// circular controls. 268h on the movie detail (1f), 196h on the series (1g).
///
/// The scrim ends in the scaffold's own surface colour so the artwork appears
/// to dissolve into the page rather than stopping at a visible edge.
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
  final double height;

  /// Title block laid over the bottom of the scrim.
  final Widget child;

  /// Rendered to the right of the back button as circular buttons.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final scheme = context.colors;

    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          GradientArt(seed: seed),
          // Under the scrim, so the title stays legible over whatever the
          // artwork turns out to be.
          RemoteArt(url: artUrl),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Colors.transparent,
                  scheme.surface.withValues(alpha: 0.55),
                  scheme.surface,
                ],
                stops: const <double>[0.35, 0.78, 1.0],
              ),
            ),
          ),
          SafeArea(
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
          Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                spacing.screenHorizontal(context.windowSize),
                0,
                spacing.screenHorizontal(context.windowSize),
                spacing.lg,
              ),
              child: child,
            ),
          ),
        ],
      ),
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
