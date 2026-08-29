// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:math' as math;
import 'dart:ui' show ViewPadding;

import 'package:flutter/material.dart';

/// The largest system-bar inset seen **in each orientation** since launch.
///
/// Two entries, not one, because the bars move when the phone turns: upright
/// the navigation bar runs along the bottom, on its side it runs down an edge
/// and the bottom inset is nothing at all. Remembering a single largest
/// reading across both meant a film watched in landscape kept a bottom inset
/// it did not have, and the control row floated a navigation bar's height
/// above where it belonged.
///
/// Largest *within* an orientation is still right: the bars are a fixed size
/// there and only their visibility changes, and a hidden bar is reported as
/// no inset at all.
final Map<Orientation, EdgeInsets> _known = <Orientation, EdgeInsets>{};

/// Notes what the bars measure while they are showing.
///
/// Called from the wrapper in `app.dart`, which sits above its own
/// `SafeArea` and therefore still sees the real numbers.
void recordSystemInsets(EdgeInsets insets, Orientation orientation) {
  final seen = _known[orientation] ?? EdgeInsets.zero;

  _known[orientation] = EdgeInsets.fromLTRB(
    math.max(seen.left, insets.left),
    math.max(seen.top, insets.top),
    math.max(seen.right, insets.right),
    math.max(seen.bottom, insets.bottom),
  );
}

/// What the bars occupy when shown, in [orientation].
EdgeInsets knownSystemInsets(Orientation orientation) =>
    _known[orientation] ?? EdgeInsets.zero;

@visibleForTesting
void debugResetKnownSystemInsets() => _known.clear();

/// Holds the system-bar padding still while the bars come and go.
///
/// The player runs in sticky immersion, where the navigation bar slides in on
/// a swipe and slides out again by itself. Each time it does, Android reports
/// the inset going from nothing to its full height and back, every `SafeArea`
/// under it grows and shrinks, and everything laid out against one moves —
/// which is what sent the Skip intro pill up the screen and dropped it back.
///
/// **Read from the view, not from the inherited media query.** The wrapper in
/// `app.dart` insets every screen but the player, and on the player's first
/// build that wrapper has not yet been told to stop — its `SafeArea` has
/// already eaten the bottom inset, so a media query read here answers zero.
/// Recording that zero as the truth was a bug in its own right: the real
/// inset then arrived a frame later and moved everything. `View.of` reports
/// what the window actually has, and no ancestor widget can mask it.
class StableInsets extends StatefulWidget {
  const StableInsets({super.key, required this.child});

  final Widget child;

  @override
  State<StableInsets> createState() => _StableInsetsState();
}

class _StableInsetsState extends State<StableInsets> {
  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final view = View.of(context);
    final ratio = view.devicePixelRatio;
    final orientation = media.orientation;

    EdgeInsets fromView(ViewPadding padding) => EdgeInsets.fromLTRB(
          padding.left / ratio,
          padding.top / ratio,
          padding.right / ratio,
          padding.bottom / ratio,
        );

    // Everything anyone has seen *in this orientation*: the window's own
    // padding now, and whatever the inherited query still carries.
    recordSystemInsets(fromView(view.viewPadding), orientation);
    recordSystemInsets(fromView(view.padding), orientation);
    recordSystemInsets(media.viewPadding, orientation);
    recordSystemInsets(media.padding, orientation);

    final stable = knownSystemInsets(orientation);

    return MediaQuery(
      data: media.copyWith(padding: stable, viewPadding: stable),
      child: widget.child,
    );
  }
}
