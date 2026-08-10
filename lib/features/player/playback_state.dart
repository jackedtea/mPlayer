// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/foundation.dart';

import '../../sources/media_source.dart';

/// Everything the player UI is allowed to know.
///
/// Hand-written rather than generated: the project keeps `build_runner` off
/// the hot path, and this is the one type the whole player layer reads.
/// Deliberately free of `media_kit` types — swapping the playback backend must
/// not reach into widgets.
@immutable
class PlaybackState {
  const PlaybackState({
    this.media,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.buffered = Duration.zero,
    this.playing = false,
    this.buffering = false,
    this.completed = false,
    this.volume = 100,
    this.speed = 1.0,
    this.error,
  });

  /// Null until something has been opened.
  final PlayableMedia? media;

  final Duration position;
  final Duration duration;

  /// How far ahead of [position] the buffer reaches.
  final Duration buffered;

  final bool playing;
  final bool buffering;
  final bool completed;

  /// 0–100, matching what the backend and the volume gesture use.
  final double volume;

  final double speed;

  /// Set when playback fails. Surfaced inline — a dead file or share must
  /// never take the app down with it.
  final String? error;

  bool get hasMedia => media != null;

  /// Guards against a zero duration while the file is still being probed.
  double get progress {
    if (duration.inMilliseconds <= 0) return 0;
    return (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }

  Duration get remaining {
    final left = duration - position;
    return left.isNegative ? Duration.zero : left;
  }

  PlaybackState copyWith({
    PlayableMedia? media,
    Duration? position,
    Duration? duration,
    Duration? buffered,
    bool? playing,
    bool? buffering,
    bool? completed,
    double? volume,
    double? speed,
    String? error,
    bool clearError = false,
    bool clearMedia = false,
  }) {
    return PlaybackState(
      media: clearMedia ? null : (media ?? this.media),
      position: position ?? this.position,
      duration: duration ?? this.duration,
      buffered: buffered ?? this.buffered,
      playing: playing ?? this.playing,
      buffering: buffering ?? this.buffering,
      completed: completed ?? this.completed,
      volume: volume ?? this.volume,
      speed: speed ?? this.speed,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// `1:34:52` once past an hour, `12:04` below it — the design never pads a
/// leading hour digit.
String formatDuration(Duration d) {
  final total = d.isNegative ? Duration.zero : d;
  final hours = total.inHours;
  final minutes = total.inMinutes.remainder(60);
  final seconds = total.inSeconds.remainder(60);

  final ss = seconds.toString().padLeft(2, '0');
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:$ss';
  }
  return '$minutes:$ss';
}
