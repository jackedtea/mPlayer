// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';

import '../app/tokens.dart';

/// Lifts a tile and rings it while something inside it has keyboard focus.
///
/// An `InkWell`'s own focus overlay is a faint tint, which is enough beside a
/// mouse and invisible from a sofa: a remote has no pointer, so the focused
/// tile is the only cursor there is and has to be found at a glance. Drawn
/// only in [FocusHighlightMode.traditional] — a tap focuses things too, and a
/// ring left behind on whatever was touched last reads as a selection.
///
/// It takes no focus of its own; it watches its subtree's.
class FocusRing extends StatefulWidget {
  const FocusRing({
    super.key,
    required this.child,
    required this.radius,
    this.scale = 1.06,
  });

  final Widget child;

  /// The child's own corner radius, so the ring follows its outline.
  final double radius;

  /// How far the focused tile grows. Room for it is the caller's business —
  /// a shelf pads its ends so the first tile does not grow into the edge.
  final double scale;

  @override
  State<FocusRing> createState() => _FocusRingState();
}

class _FocusRingState extends State<FocusRing> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final shown = _focused &&
        FocusManager.instance.highlightMode == FocusHighlightMode.traditional;

    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (has) => setState(() => _focused = has),
      child: AnimatedScale(
        scale: shown ? widget.scale : 1,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            border: Border.all(
              color: shown ? context.colors.primary : Colors.transparent,
              width: 3,
            ),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
