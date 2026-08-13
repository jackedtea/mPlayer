// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Rotation control cycles through these; the default follows the video's own
/// aspect rather than the device sensor.
enum RotationMode {
  auto('Auto', Icons.screen_rotation_rounded),
  landscape('Landscape', Icons.stay_current_landscape_rounded),
  portrait('Portrait', Icons.stay_current_portrait_rounded);

  const RotationMode(this.label, this.icon);

  final String label;
  final IconData icon;

  RotationMode get next =>
      RotationMode.values[(index + 1) % RotationMode.values.length];

  /// What `SystemChrome` should allow in this mode.
  ///
  /// `auto` is deliberately absent: it does not mean "allow everything", it
  /// means *follow the video* — see [PlayerUiController.followVideoAspect].
  List<DeviceOrientation> get orientations => switch (this) {
        RotationMode.auto => const <DeviceOrientation>[],
        RotationMode.landscape => const <DeviceOrientation>[
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ],
        RotationMode.portrait => const <DeviceOrientation>[
            DeviceOrientation.portraitUp,
          ],
      };
}

/// Orientations that suit a video of the given shape.
///
/// Both landscape directions are offered so the device still flips end for
/// end; only the axis is pinned.
List<DeviceOrientation> orientationsForVideo(int width, int height) {
  return width >= height
      ? const <DeviceOrientation>[
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]
      : const <DeviceOrientation>[
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ];
}

/// How the video fills the surface.
enum AspectMode {
  fit('Fit', BoxFit.contain),
  fill('Fill', BoxFit.cover),
  stretch('Stretch', BoxFit.fill);

  const AspectMode(this.label, this.boxFit);

  final String label;

  /// Named `boxFit` because `fit` would collide with the enum value.
  final BoxFit boxFit;

  AspectMode get next =>
      AspectMode.values[(index + 1) % AspectMode.values.length];
}

/// Chrome state that is not playback state.
///
/// Kept out of `PlaybackState` because none of it survives the media: locking
/// the screen or showing stats says nothing about what is playing. Kept out of
/// the widget because the design lists these under player state and they need
/// to be testable without pumping the whole screen.
@immutable
class PlayerUiState {
  const PlayerUiState({
    this.locked = false,
    this.rotation = RotationMode.auto,
    this.aspect = AspectMode.fit,
    this.statsVisible = false,
    this.sleepTimer,
  });

  /// Locked ignores every input but the unlock affordance.
  final bool locked;

  final RotationMode rotation;
  final AspectMode aspect;
  final bool statsVisible;

  /// Null means off.
  final Duration? sleepTimer;

  String get sleepLabel =>
      sleepTimer == null ? 'Off' : '${sleepTimer!.inMinutes} min';

  PlayerUiState copyWith({
    bool? locked,
    RotationMode? rotation,
    AspectMode? aspect,
    bool? statsVisible,
    Duration? sleepTimer,
    bool clearSleepTimer = false,
  }) {
    return PlayerUiState(
      locked: locked ?? this.locked,
      rotation: rotation ?? this.rotation,
      aspect: aspect ?? this.aspect,
      statsVisible: statsVisible ?? this.statsVisible,
      sleepTimer: clearSleepTimer ? null : (sleepTimer ?? this.sleepTimer),
    );
  }
}

final playerUiProvider =
    NotifierProvider<PlayerUiController, PlayerUiState>(PlayerUiController.new);

class PlayerUiController extends Notifier<PlayerUiState> {
  @override
  PlayerUiState build() {
    // Leaving the player must not strand a locked orientation on the rest of
    // the app.
    ref.onDispose(() => SystemChrome.setPreferredOrientations(
          const <DeviceOrientation>[],
        ));
    return const PlayerUiState();
  }

  /// Last frame size reported by the decoder, so `auto` can be re-applied when
  /// the user cycles back to it without waiting for a new video.
  int? _videoWidth;
  int? _videoHeight;

  void toggleLock() => state = state.copyWith(locked: !state.locked);

  void unlock() => state = state.copyWith(locked: false);

  void cycleRotation() {
    final next = state.rotation.next;
    state = state.copyWith(rotation: next);

    if (next == RotationMode.auto) {
      _applyAuto();
    } else {
      SystemChrome.setPreferredOrientations(next.orientations);
    }
  }

  /// Points the device at whichever axis suits the video.
  ///
  /// This is what "Auto" means in the design — the rotation default is
  /// "follow video", not "let the sensor decide". A 16:9 film opened from a
  /// portrait home screen should turn the phone landscape by itself.
  ///
  /// No-op on desktop, where `setPreferredOrientations` does nothing.
  void followVideoAspect(int? width, int? height) {
    if (width == null || height == null || width <= 0 || height <= 0) return;

    _videoWidth = width;
    _videoHeight = height;

    if (state.rotation == RotationMode.auto) _applyAuto();
  }

  void _applyAuto() {
    final w = _videoWidth;
    final h = _videoHeight;
    if (w == null || h == null) {
      // Nothing decoded yet: leave the device alone rather than guessing.
      SystemChrome.setPreferredOrientations(const <DeviceOrientation>[]);
      return;
    }
    SystemChrome.setPreferredOrientations(orientationsForVideo(w, h));
  }

  void cycleAspect() => state = state.copyWith(aspect: state.aspect.next);

  void setAspect(AspectMode mode) => state = state.copyWith(aspect: mode);

  void toggleStats() =>
      state = state.copyWith(statsVisible: !state.statsVisible);

  void setSleepTimer(Duration? d) => d == null
      ? state = state.copyWith(clearSleepTimer: true)
      : state = state.copyWith(sleepTimer: d);

  /// Called when the player screen closes, so a second file does not inherit
  /// the previous one's lock or rotation.
  void reset() {
    SystemChrome.setPreferredOrientations(const <DeviceOrientation>[]);
    // Otherwise the next file inherits the previous one's shape before its
    // own dimensions arrive.
    _videoWidth = null;
    _videoHeight = null;
    state = const PlayerUiState();
  }
}
