// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

/// Where the window was last left, and making sure there is only one of it.
///
/// Desktop only. `window_manager` throws on Android and iOS, which is the
/// signal to do nothing rather than an error worth reporting — the same rule
/// the player's fullscreen toggle follows.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

bool get isDesktop =>
    !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

const _prefsKey = 'window_bounds_v1';

/// The port the running instance holds to prove it is the running instance.
///
/// A fixed loopback port is the whole locking mechanism: binding it succeeds
/// for exactly one process, and a second launch fails to bind, which is how
/// it knows it is the second launch.
const singleInstancePort = 47821;

/// Restores the last size and position, then shows the window.
///
/// The window is created hidden in the runner and shown here, once it is the
/// right size: doing it the other way round means the user watches it appear
/// at the default size and jump.
Future<void> restoreWindow() async {
  if (!isDesktop) return;

  try {
    await windowManager.ensureInitialized();

    final prefs = await SharedPreferences.getInstance();
    final saved = _Bounds.decode(prefs.getString(_prefsKey));

    await windowManager.waitUntilReadyToShow(
      WindowOptions(
        size: saved?.size ?? const Size(1280, 800),
        minimumSize: const Size(480, 360),
        center: saved == null,
        title: 'mPlayer',
      ),
      () async {
        // Position after size: setting them together lets a window restored
        // onto a monitor that no longer exists land off-screen.
        final position = saved?.position;
        if (position != null && await _isOnScreen(position)) {
          await windowManager.setPosition(position);
        }
        await windowManager.show();
      },
    );
  } catch (e) {
    // A window that will not restore must still open.
    debugPrint('Could not restore the window: $e');
  }
}

/// Writes the current bounds. Called as the window moves or resizes.
Future<void> saveWindowBounds() async {
  if (!isDesktop) return;

  try {
    if (await windowManager.isMinimized() ||
        await windowManager.isFullScreen()) {
      // Saving either would restore the app as a minimised or fullscreen
      // window next launch, which is not what the user left behind.
      return;
    }

    final bounds = _Bounds(
      await windowManager.getSize(),
      await windowManager.getPosition(),
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, bounds.encode());
  } catch (e) {
    debugPrint('Could not save the window bounds: $e');
  }
}

/// True when this is the only instance.
///
/// When it is not, the running window is raised and this process should exit.
///
/// It used to carry a file across as well: a second `mPlayer video.mkv`
/// handed its path to the instance already running rather than opening a
/// second player to fight the first over the audio device. mPlayer opens no
/// local files now, so there is nothing to carry — but a second launch still
/// has no business becoming a second window, and bringing the existing one
/// forward is what the user meant by launching it.
Future<bool> claimSingleInstance() async {
  if (!isDesktop) return true;

  try {
    final server = await ServerSocket.bind(
      InternetAddress.loopbackIPv4,
      singleInstancePort,
    );
    _listenForLaunches(server);
    return true;
  } on SocketException {
    // The port is taken, so another instance owns it. Knock, and let the
    // caller exit.
    await _raiseRunningWindow();
    return false;
  }
}

void _listenForLaunches(ServerSocket server) {
  server.listen((socket) async {
    try {
      // The connection itself is the whole message. Nothing is read from it:
      // it is on loopback, but a socket this app does not need to trust is a
      // socket it should not parse.
      await windowManager.show();
      await windowManager.focus();
    } catch (e) {
      debugPrint('Could not raise the window for a second launch: $e');
    } finally {
      socket.destroy();
    }
  });
}

Future<void> _raiseRunningWindow() async {
  try {
    final socket = await Socket.connect(
      InternetAddress.loopbackIPv4,
      singleInstancePort,
      timeout: const Duration(seconds: 2),
    );
    socket.destroy();
  } catch (e) {
    debugPrint('Could not reach the running instance: $e');
  }
}

/// Starts saving the window's bounds as the user moves and resizes it.
Future<void> watchWindowBounds() async {
  if (!isDesktop) return;
  windowManager.addListener(_BoundsSaver());
}

/// Debounces the save.
///
/// Dragging a window edge fires a resize for every frame of the drag; writing
/// preferences at that rate would be pointless work, and only the position the
/// drag ends at matters.
class _BoundsSaver extends WindowListener {
  Timer? _pending;

  void _schedule() {
    _pending?.cancel();
    _pending = Timer(const Duration(milliseconds: 600), saveWindowBounds);
  }

  @override
  void onWindowResized() => _schedule();

  @override
  void onWindowMoved() => _schedule();

  @override
  void onWindowClose() {
    // The last word: a debounce still pending when the window closes would
    // never fire.
    _pending?.cancel();
    unawaited(saveWindowBounds());
  }
}

/// Guards against restoring onto a monitor that has since been unplugged.
Future<bool> _isOnScreen(Offset position) async {
  try {
    final bounds = await windowManager.getBounds();
    // A generous test: the title bar only has to be reachable, not the whole
    // window, and multi-monitor layouts can put a screen at negative offsets.
    return position.dx > -bounds.width && position.dy > -50;
  } catch (_) {
    return true;
  }
}

@immutable
class _Bounds {
  const _Bounds(this.size, this.position);

  final Size size;
  final Offset position;

  static _Bounds? decode(String? raw) {
    if (raw == null) return null;

    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final width = (json['width'] as num).toDouble();
      final height = (json['height'] as num).toDouble();

      // A stored size smaller than the minimum comes from a build with
      // different limits; the default is better than an unusable window.
      if (width < 480 || height < 360) return null;

      return _Bounds(
        Size(width, height),
        Offset(
          (json['x'] as num).toDouble(),
          (json['y'] as num).toDouble(),
        ),
      );
    } catch (e) {
      debugPrint('Unreadable window bounds, using the default: $e');
      return null;
    }
  }

  String encode() => jsonEncode(<String, double>{
        'width': size.width,
        'height': size.height,
        'x': position.dx,
        'y': position.dy,
      });
}
