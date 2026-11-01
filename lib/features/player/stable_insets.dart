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

/// The player's sheets' own colour: a dark surface matching the player, so
/// the app's light theme never flashes over the film.
const Color playerSheetColor = Color(0xFF1A2125);

/// Opens a bottom sheet over the player, the same size whether the system
/// bars are showing or not.
///
/// A sheet is a route on the root navigator, above [StableInsets], so it used
/// to see the real insets — which come and go with the sticky-immersive bars.
/// Opened with the bars up, a sheet sat a status bar's height lower and a
/// navigation bar's width to one side of the same sheet opened with them
/// down. So every player sheet goes through here:
///
/// - its content gets [StableInsets]' padding — what the bars take when they
///   show — so the `SafeArea` inside it pads the same either way;
/// - it is capped below the status bar, so it never reaches the top and the
///   top inset is removed rather than padded;
/// - it is centred on the whole screen at a fixed maximum width, not on
///   whatever the bars left free.
const double _sheetMaxWidth = 640;

Future<T?> showPlayerSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  final size = MediaQuery.sizeOf(context);
  final known = knownSystemInsets(MediaQuery.orientationOf(context));

  // A sheet narrower than the screen is centred, and on a phone on its side
  // the gap either side of it is wider than the navigation bar or the
  // camera cut-out. Padding for a bar the sheet does not reach doubled the
  // rows' side margin for nothing.
  final margin = (size.width - math.min(size.width, _sheetMaxWidth)) / 2;

  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: playerSheetColor,
    isScrollControlled: true,
    useSafeArea: false,
    constraints: BoxConstraints(
      maxWidth: _sheetMaxWidth,
      maxHeight: size.height - known.top,
    ),
    builder: (sheetContext) => StableInsets(
      child: Builder(
        builder: (inner) => MediaQuery.removePadding(
          context: inner,
          removeTop: true,
          removeLeft: margin >= known.left,
          removeRight: margin >= known.right,
          child: builder(inner),
        ),
      ),
    ),
  );
}

