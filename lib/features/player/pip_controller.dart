// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A button pressed inside the picture-in-picture window.
///
/// The system draws those controls, so they arrive as events rather than as
/// taps — but what they *mean* is decided here, next to everything else that
/// drives playback.
enum PipControl { back, toggle, forward }

@immutable
class PipState {
  const PipState({this.supported = false, this.active = false});

  /// False on every platform but Android, and on Android devices whose
  /// manufacturer left the feature out. The button is hidden rather than
  /// shown failing.
  final bool supported;

  /// True while the video is playing in the small window. The chrome has no
  /// room there and is dropped entirely.
  final bool active;

  PipState copyWith({bool? supported, bool? active}) => PipState(
        supported: supported ?? this.supported,
        active: active ?? this.active,
      );
}

final pipProvider = NotifierProvider<PipController, PipState>(
  PipController.new,
);

/// See `android/app/src/main/kotlin/dev/icedtea/mplayer/PipChannel.kt`.
class PipController extends Notifier<PipState> {
  static const _channel = MethodChannel('dev.icedtea.mplayer/pip');
  static const _events = EventChannel('dev.icedtea.mplayer/pip-events');

  final _controls = StreamController<PipControl>.broadcast();

  /// The window's transport buttons. The player subscribes and applies them
  /// with the same methods its own controls use.
  Stream<PipControl> get controls => _controls.stream;

  StreamSubscription<Object?>? _sub;

  @override
  PipState build() {
    if (!Platform.isAndroid) return const PipState();

    _sub = _events.receiveBroadcastStream().listen(
          _accept,
          onError: (Object e) => debugPrint('PiP event stream failed: $e'),
        );
    ref.onDispose(() {
      unawaited(_sub?.cancel());
      unawaited(_controls.close());
    });

    unawaited(_querySupport());
    return const PipState();
  }

  Future<void> _querySupport() async {
    try {
      final supported = await _channel.invokeMethod<bool>('isSupported');
      state = state.copyWith(supported: supported ?? false);
    } catch (e) {
      debugPrint('Could not ask about picture in picture: $e');
    }
  }

  void _accept(Object? payload) {
    if (payload is! Map) return;

    switch (payload['type']) {
      case 'mode':
        state = state.copyWith(active: payload['inPip'] as bool? ?? false);
      case 'control':
        final control = switch (payload['control']) {
          'back' => PipControl.back,
          'toggle' => PipControl.toggle,
          'forward' => PipControl.forward,
          _ => null,
        };
        if (control != null) _controls.add(control);
    }
  }

  /// Shrinks the app into the PiP window now.
  Future<void> enter({int? width, int? height, required bool playing}) async {
    if (!state.supported) return;
    await _invoke('enter', width: width, height: height, playing: playing);
  }

  /// Keeps the window's shape and buttons in step with the player.
  ///
  /// Also what arms [autoEnter]: on Android 12+ the system opens PiP by
  /// itself when the user leaves, and it reads that from these params — so
  /// this has to be called *before* they leave, not on the way out.
  Future<void> update({
    int? width,
    int? height,
    required bool playing,
    required bool autoEnter,
  }) async {
    if (!state.supported) return;
    await _invoke(
      'update',
      width: width,
      height: height,
      playing: playing,
      autoEnter: autoEnter,
    );
  }

  Future<void> _invoke(
    String method, {
    int? width,
    int? height,
    required bool playing,
    bool? autoEnter,
  }) async {
    try {
      await _channel.invokeMethod<void>(method, <String, Object?>{
        if (width != null && height != null) ...<String, Object?>{
          'width': width,
          'height': height,
        },
        'playing': playing,
        'autoEnter': ?autoEnter,
      });
    } catch (e) {
      // A refused window is a missing convenience, not a broken player.
      debugPrint('Picture in picture $method failed: $e');
    }
  }
}
