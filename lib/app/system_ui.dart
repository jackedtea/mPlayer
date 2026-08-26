// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/foundation.dart'
    show ValueNotifier, debugPrint, visibleForTesting;
import 'package:flutter/material.dart' show Colors;
import 'package:flutter/services.dart';

import 'desktop_window.dart' show isDesktop;

/// Whether the last thing this app asked for was a hidden set of system bars.
///
/// Module-level rather than held by the player, because the whole point is
/// that it outlives the screen that set it: if the player's teardown is
/// skipped for any reason, something else has to be able to notice and put
/// the bars back.
bool _immersive = false;

/// Whether these calls mean anything on this platform.
///
/// Overridable because the tests run on the desktop VM, where the real answer
/// is "no" and every function here would return before doing the thing under
/// test. The app never sets it.
@visibleForTesting
bool Function()? debugSystemUiApplies;

bool get _applies => debugSystemUiApplies?.call() ?? !isDesktop;

/// Whether the screen on top wants the window edge to edge.
///
/// False for everything but the player: the app is laid out *between* the
/// system bars, not under them. Video is the exception the whole arrangement
/// exists for — letterboxing a film to leave room for a navigation bar throws
/// away the part of the screen the user came for.
///
/// A notifier rather than a route check because the wrapper that reads it sits
/// above the navigator, where the current route is not visible.
final fullBleedUi = ValueNotifier<bool>(false);

/// Hides the status and navigation bars for fullscreen video.
///
/// `immersiveSticky` rather than `immersive`: a swipe brings the bars back
/// for a moment and they leave again on their own, which is what a video
/// player wants — `immersive` hands them back permanently on the first
/// accidental edge swipe.
Future<void> enterImmersiveUi() async {
  if (!_applies) return;
  if (_immersive) return;
  _immersive = true;

  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
}

/// Puts the system bars back the way the rest of the app expects them.
///
/// **Two calls, because they are two different platform methods.**
/// `setEnabledSystemUIMode` with anything but `manual` invokes
/// `SystemChrome.setEnabledSystemUIMode`, which sets the *layout* behaviour;
/// `manual` invokes `SystemChrome.setEnabledSystemUIOverlays` instead, which
/// is the one that says which bars are *visible*. Asking for `edgeToEdge`
/// alone therefore restores the layout while leaving the bars hidden — the
/// app comes back from the player still swallowing its navigation bar, which
/// keeps sliding away on its own because sticky immersion was never lifted.
///
/// Cheap to call repeatedly: it does nothing unless something actually asked
/// for immersion.
Future<void> restoreAppSystemUi() async {
  if (!_applies) return;
  if (!_immersive) return;
  _immersive = false;

  try {
    // Visibility first, then layout. The other order leaves a frame where the
    // bars are shown but the app is still laid out as though they were not.
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  } catch (e) {
    // A failure here strands the app without its bars, which is worth a line
    // in the log even though nothing can be done about it from Dart.
    debugPrint('Could not restore the system bars: $e');
    _immersive = true;
  }
}

/// The app-wide baseline, stated at startup.
///
/// Android 15 draws every app edge to edge whether it asks to or not, and
/// Android 14 and below do not, so without this the same build lays out
/// differently on two phones and only one of them matches what the insets are
/// calculated against.
Future<void> applyBaselineSystemUi() async {
  if (!_applies) return;

  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  // Transparent bars over the app's own surface: the icons are drawn by the
  // system in whichever contrast the theme asks for.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );
}
