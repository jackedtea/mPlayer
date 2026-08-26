// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Holds the system-bar padding still while the bars come and go.
///
/// The player runs in sticky immersion, where the navigation bar slides in on
/// a swipe and slides out again by itself. Each time it does, Android reports
/// the bottom inset going from nothing to its full height and back, the
/// `SafeArea` around the control row grows and shrinks with it, and
/// everything stacked above that row jumps — which is what sent the Skip
/// intro pill flying up the screen and then dropping back.
///
/// Neither `padding` nor `viewPadding` survives that: hidden bars are
/// reported as no inset at all, so both collapse. What does not change is the
/// space the bars *occupy when shown*, and the largest inset seen since the
/// player opened is exactly that. The controls are laid out against it and
/// stay put.
///
/// Only ever grows, so a bar appearing for the first time costs one small
/// settle. A rotation can leave the inset generous by the difference between
/// the two orientations' bars, which is worth far less than a control row
/// that moves while being aimed at.
class StableInsets extends StatefulWidget {
  const StableInsets({super.key, required this.child});

  final Widget child;

  @override
  State<StableInsets> createState() => _StableInsetsState();
}

class _StableInsetsState extends State<StableInsets> {
  EdgeInsets _seen = EdgeInsets.zero;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    // `viewPadding` as well as `padding`: on the way in the bars are still
    // showing, so the real inset is known from the first frame and the
    // controls never have to settle at all.
    double widest(double a, double b, double c) =>
        math.max(a, math.max(b, c));

    _seen = EdgeInsets.fromLTRB(
      widest(_seen.left, media.padding.left, media.viewPadding.left),
      widest(_seen.top, media.padding.top, media.viewPadding.top),
      widest(_seen.right, media.padding.right, media.viewPadding.right),
      widest(_seen.bottom, media.padding.bottom, media.viewPadding.bottom),
    );

    return MediaQuery(
      data: media.copyWith(padding: _seen, viewPadding: _seen),
      child: widget.child,
    );
  }
}
