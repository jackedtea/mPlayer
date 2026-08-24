// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'cast_device.dart';
import 'cast_renderer.dart';

/// The Dart side of `CastChannel.kt`.
///
/// Android only — the Cast SDK is a Google Play Services library with no
/// desktop equivalent, which is exactly why DLNA exists alongside it and why
/// this whole file is inert everywhere else.
///
/// One instance, shared: the SDK keeps a single session and a single router
/// per process, so a second discovery would fight the first.
class Chromecast {
  Chromecast._();

  static final Chromecast instance = Chromecast._();

  static const _channel = MethodChannel('dev.icedtea.mplayer/chromecast');
  static const _events = EventChannel('dev.icedtea.mplayer/chromecast-events');

  final _devices = StreamController<List<CastDevice>>.broadcast();
  final _sessions = StreamController<bool>.broadcast();

  /// Devices as the router finds them. Emits repeatedly during a scan: the
  /// list grows as televisions answer.
  Stream<List<CastDevice>> get devices => _devices.stream;

  /// True once a session is open and something can be loaded.
  Stream<bool> get sessions => _sessions.stream;

  StreamSubscription<Object?>? _sub;
  List<CastDevice> _latest = const <CastDevice>[];
  bool _connected = false;

  bool get isConnected => _connected;

  /// False without Google Play Services, which is a normal state — plenty of
  /// devices ship without it, and the picker just shows no Chromecasts.
  Future<bool> isAvailable() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('isAvailable') ?? false;
    } catch (e) {
      debugPrint('Chromecast availability check failed: $e');
      return false;
    }
  }

  void _listen() {
    _sub ??= _events.receiveBroadcastStream().listen(
          _accept,
          onError: (Object e) => debugPrint('Chromecast stream failed: $e'),
        );
  }

  void _accept(Object? payload) {
    if (payload is! Map) return;

    switch (payload['type']) {
      case 'devices':
        final raw = payload['devices'];
        if (raw is! List) return;

        _latest = <CastDevice>[
          for (final Object? entry in raw)
            if (entry is Map)
              CastDevice(
                id: entry['id'] as String? ?? '',
                name: entry['name'] as String? ?? 'Chromecast',
                kind: CastKind.chromecast,
                model: entry['model'] as String?,
              ),
        ].where((d) => d.id.isNotEmpty).toList();

        _devices.add(_latest);

      case 'session':
        _connected = payload['connected'] as bool? ?? false;
        _sessions.add(_connected);
    }
  }

  /// Starts an active scan and returns what is already known.
  ///
  /// Later devices arrive on [devices]; a scan that found nothing yet is not
  /// an error, it is a television that has not answered.
  Future<List<CastDevice>> startDiscovery() async {
    if (!await isAvailable()) return const <CastDevice>[];

    _listen();
    try {
      await _channel.invokeMethod<void>('startDiscovery');
    } catch (e) {
      debugPrint('Could not start Chromecast discovery: $e');
      return const <CastDevice>[];
    }
    return _latest;
  }

  /// Active scanning costs battery, so it stops with the picker.
  Future<void> stopDiscovery() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('stopDiscovery');
    } catch (e) {
      debugPrint('Could not stop Chromecast discovery: $e');
    }
  }

  Future<void> invoke(String method, [Map<String, Object?>? arguments]) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on PlatformException catch (e) {
      // The message is written for the user on the Kotlin side — a rejected
      // container is the common case and says so in words.
      throw CastException(e.message ?? 'The device refused that.');
    }
  }

  Future<Map<Object?, Object?>?> status() async {
    try {
      return await _channel.invokeMapMethod<Object?, Object?>('status');
    } catch (e) {
      debugPrint('Chromecast status failed: $e');
      return null;
    }
  }

  /// Waits for the session the SDK opens when a route is selected.
  ///
  /// There is no connect call to await: selecting a route starts a session
  /// and the answer arrives as an event, so this is where "connected" is
  /// actually established.
  Future<bool> connect(String id, {Duration timeout = const Duration(seconds: 15)}) async {
    _listen();
    if (_connected) return true;

    final opened = sessions.firstWhere((c) => c).timeout(
          timeout,
          onTimeout: () => false,
        );

    try {
      await _channel.invokeMethod<void>('connect', <String, Object?>{'id': id});
    } on PlatformException catch (e) {
      throw CastException(e.message ?? 'Could not connect to that device.');
    }

    return opened;
  }
}

/// The receiver's player state, as the SDK names it.
///
/// A free function so the mapping can be tested without a device: the states
/// a receiver reports are the one part of this file that is pure logic.
CastPlayback castPlaybackFrom(Object? raw) {
  return switch (raw) {
    'playing' => CastPlayback.playing,
    'paused' => CastPlayback.paused,
    // Loading and buffering are one state to a viewer: the picture is not
    // moving and the device is working on it.
    'buffering' => CastPlayback.buffering,
    'stopped' => CastPlayback.stopped,
    _ => CastPlayback.idle,
  };
}

/// One Chromecast, driven through [Chromecast].
class ChromecastRenderer implements CastRenderer {
  ChromecastRenderer(this.device);

  @override
  final CastDevice device;

  final Chromecast _cast = Chromecast.instance;

  @override
  Future<void> load(
    Uri url, {
    required String title,
    String contentType = 'video/mp4',
    Duration position = Duration.zero,
  }) async {
    final connected = await _cast.connect(device.id);
    if (!connected) {
      throw CastException(
        '${device.name} did not accept a connection. It may be in use by '
        'another app.',
      );
    }

    await _cast.invoke('load', <String, Object?>{
      'url': url.toString(),
      'title': title,
      'contentType': contentType,
      'positionMs': position.inMilliseconds,
    });
  }

  @override
  Future<void> play() => _cast.invoke('play');

  @override
  Future<void> pause() => _cast.invoke('pause');

  @override
  Future<void> stop() => _cast.invoke('stop');

  @override
  Future<void> seek(Duration to) => _cast.invoke('seek', <String, Object?>{
        'positionMs': to.inMilliseconds,
      });

  @override
  Future<CastStatus> status() async {
    final raw = await _cast.status();
    if (raw == null) return const CastStatus();

    return CastStatus(
      playback: castPlaybackFrom(raw['playback']),
      position: Duration(milliseconds: (raw['positionMs'] as int?) ?? 0),
      duration: Duration(milliseconds: (raw['durationMs'] as int?) ?? 0),
    );
  }

  @override
  Future<void> dispose() async {
    // Ends the session rather than just dropping the object: a receiver left
    // running keeps the television on this app's black screen.
    await _cast.invoke('disconnect');
  }
}
