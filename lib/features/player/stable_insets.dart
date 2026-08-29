// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:math' as math;

import 'dart:ui' show ViewPadding;

import 'package:flutter/material.dart';

/// The largest system-bar inset this app has seen since it started.
///
/// The bars are a fixed size; only their *visibility* changes, and a hidden
/// bar is reported as no inset at all. So the largest reading is the true
/// size, and it is worth keeping app-wide rather than per-screen: the player
/// is often opened *after* immersion has already begun, and a screen that
/// only ever saw zero would lay its controls against the very edge and then
/// jump the first time a bar appeared.
EdgeInsets _known = EdgeInsets.zero;

/// Notes what the bars measure while they are showing.
///
/// Called from the wrapper in `app.dart`, which sits above its own
/// `SafeArea` and therefore still sees the real numbers.
void recordSystemInsets(EdgeInsets insets) {
  _known = EdgeInsets.fromLTRB(
    math.max(_known.left, insets.left),
    math.max(_known.top, insets.top),
    math.max(_known.right, insets.right),
    math.max(_known.bottom, insets.bottom),
  );
}

@visibleForTesting
void debugResetKnownSystemInsets() => _known = EdgeInsets.zero;

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
/// Recording that zero as the truth was the whole bug: the real inset then
/// arrived a frame later and moved everything. `View.of` reports what the
/// window actually has, and no ancestor widget can mask it.
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

    EdgeInsets fromView(ViewPadding padding) => EdgeInsets.fromLTRB(
          padding.left / ratio,
          padding.top / ratio,
          padding.right / ratio,
          padding.bottom / ratio,
        );

    // Everything anyone has seen: the window's own padding now, the largest
    // reading since launch, and whatever the inherited query still carries.
    recordSystemInsets(fromView(view.viewPadding));
    recordSystemInsets(fromView(view.padding));
    recordSystemInsets(media.viewPadding);
    recordSystemInsets(media.padding);

    return MediaQuery(
      data: media.copyWith(padding: _known, viewPadding: _known),
      child: widget.child,
    );
  }
}
