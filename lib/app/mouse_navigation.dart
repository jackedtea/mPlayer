// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// The mouse's side buttons, as a browser treats them: back leaves the screen,
/// forward returns to the one just left.
///
/// Back goes through the router's [GoRouterDelegate.popRoute] — the path the
/// system back button takes — rather than a bare pop, so a screen that
/// intercepts back (the player, a dialog) is asked first, exactly as it is on
/// Android.
///
/// Go_router keeps no forward history; this does. Each screen backed out of
/// is remembered with the `extra` it was opened with, and forward pushes it
/// again. Going anywhere else first forgets them all, which is what a browser
/// does when a link is followed after going back.
class MouseNavigation extends StatefulWidget {
  const MouseNavigation({super.key, required this.router, required this.child});

  final GoRouter router;
  final Widget child;

  @override
  State<MouseNavigation> createState() => _MouseNavigationState();
}

class _MouseNavigationState extends State<MouseNavigation> {
  final _forward = <({Uri uri, Object? extra})>[];

  /// True while a back of ours is popping, so the change it causes is not
  /// read as the user going somewhere new.
  bool _backing = false;

  /// Where a forward of ours is about to land. A push settles asynchronously,
  /// so a flag would be cleared before the change arrived.
  Uri? _arriving;

  GoRouterDelegate get _delegate => widget.router.routerDelegate;

  @override
  void initState() {
    super.initState();
    _delegate.addListener(_onRouteChanged);
  }

  @override
  void didUpdateWidget(MouseNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.router != widget.router) {
      oldWidget.router.routerDelegate.removeListener(_onRouteChanged);
      _delegate.addListener(_onRouteChanged);
      _forward.clear();
    }
  }

  @override
  void dispose() {
    _delegate.removeListener(_onRouteChanged);
    super.dispose();
  }

  void _onRouteChanged() {
    if (_backing) return;
    final arriving = _arriving;
    if (arriving != null && widget.router.state.uri == arriving) {
      _arriving = null;
      return;
    }
    _forward.clear();
  }

  Future<void> _back() async {
    final leaving = widget.router.state;
    _backing = true;
    final bool handled;
    try {
      handled = await _delegate.popRoute();
    } finally {
      _backing = false;
    }
    // A screen that only closed something of its own — the player leaving
    // full screen — handled the press without being left.
    if (!handled || !mounted) return;
    if (widget.router.state.pageKey == leaving.pageKey) return;
    _forward.add((uri: leaving.uri, extra: leaving.extra));
  }

  void _ahead() {
    if (_forward.isEmpty) return;
    final next = _forward.removeLast();
    _arriving = next.uri;
    widget.router.push(next.uri.toString(), extra: next.extra);
  }

  void _onPointerDown(PointerDownEvent event) {
    if (event.kind != PointerDeviceKind.mouse) return;
    if (event.buttons & kBackMouseButton != 0) {
      _back();
    } else if (event.buttons & kForwardMouseButton != 0) {
      _ahead();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      // Anywhere in the window, over empty space as much as over a widget.
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      child: widget.child,
    );
  }
}
