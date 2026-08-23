// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Something that happened outside the app and has to reach the player.
///
/// The notification's buttons, the lock screen, a headset click, headphones
/// pulled out, and losing audio focus to a call all arrive here.
enum NowPlayingCommand { play, pause, next, previous, stop, seek }

@immutable
class NowPlayingEvent {
  const NowPlayingEvent(this.command, {this.position});

  final NowPlayingCommand command;

  /// Set only for [NowPlayingCommand.seek], from the lock-screen scrubber.
  final Duration? position;
}

final nowPlayingProvider = NotifierProvider<NowPlayingController, bool>(
  NowPlayingController.new,
);

/// The media notification, the lock-screen controls and audio focus.
///
/// State is `true` while the notification is up. Everything real happens in
/// `android/app/src/main/kotlin/dev/icedtea/mplayer/PlaybackService.kt`; this
/// pushes what is playing and turns what comes back into events the player
/// applies. Nothing here decides anything, so the notification cannot end up
/// claiming a state the decoder is not in.
class NowPlayingController extends Notifier<bool> {
  static const _channel = MethodChannel('dev.icedtea.mplayer/now-playing');
  static const _events = EventChannel('dev.icedtea.mplayer/now-playing-events');

  /// The lock screen works the position out from the last one it was told
  /// plus the speed, so it only has to be corrected now and then.
  static const _positionInterval = Duration(seconds: 5);

  final _commands = StreamController<NowPlayingEvent>.broadcast();

  Stream<NowPlayingEvent> get commands => _commands.stream;

  StreamSubscription<Object?>? _sub;
  DateTime _lastPush = DateTime.fromMillisecondsSinceEpoch(0);
  String _lastSignature = '';

  @override
  bool build() {
    if (!Platform.isAndroid) return false;

    _sub = _events.receiveBroadcastStream().listen(
          _accept,
          onError: (Object e) => debugPrint('Now-playing stream failed: $e'),
        );
    ref.onDispose(() {
      unawaited(_sub?.cancel());
      unawaited(_commands.close());
    });

    return false;
  }

  void _accept(Object? payload) {
    if (payload is! Map) return;

    final command = switch (payload['control']) {
      'play' => NowPlayingCommand.play,
      'pause' => NowPlayingCommand.pause,
      'next' => NowPlayingCommand.next,
      'previous' => NowPlayingCommand.previous,
      'stop' => NowPlayingCommand.stop,
      'seek' => NowPlayingCommand.seek,
      _ => null,
    };
    if (command == null) return;

    final ms = payload['positionMs'] as int?;
    _commands.add(
      NowPlayingEvent(
        command,
        position: ms == null ? null : Duration(milliseconds: ms),
      ),
    );
  }

  /// Publishes what is playing, starting the service the first time.
  ///
  /// Safe to call on every state change: a call that only moves the position
  /// on is dropped unless [_positionInterval] has passed, so the position
  /// stream firing several times a second does not become several IPC hops a
  /// second.
  Future<void> update({
    required String title,
    String? subtitle,
    required bool playing,
    required Duration position,
    required Duration duration,
    double speed = 1.0,
    bool hasNext = false,
    bool hasPrevious = false,
  }) async {
    if (!Platform.isAndroid) return;

    final signature = '$title|$subtitle|$playing|${duration.inSeconds}'
        '|$speed|$hasNext|$hasPrevious';
    final now = DateTime.now();

    if (signature == _lastSignature &&
        now.difference(_lastPush) < _positionInterval) {
      return;
    }
    _lastSignature = signature;
    _lastPush = now;

    try {
      await _channel.invokeMethod<void>('update', <String, Object?>{
        'title': title,
        'subtitle': subtitle ?? '',
        'playing': playing,
        'positionMs': position.inMilliseconds,
        'durationMs': duration.inMilliseconds,
        'speed': speed,
        'hasNext': hasNext,
        'hasPrevious': hasPrevious,
      });
      state = true;
    } catch (e) {
      // No notification is a lost convenience; the video keeps playing.
      debugPrint('Could not publish the playback notification: $e');
    }
  }

  /// Takes the notification down and lets the service go.
  Future<void> stop() async {
    if (!Platform.isAndroid) return;

    // Cleared so the next file republishes immediately rather than being
    // dropped as an unchanged position update.
    _lastSignature = '';
    _lastPush = DateTime.fromMillisecondsSinceEpoch(0);

    try {
      await _channel.invokeMethod<void>('stop');
    } catch (e) {
      debugPrint('Could not stop the playback notification: $e');
    }
    state = false;
  }
}
