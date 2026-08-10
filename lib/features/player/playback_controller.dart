// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../sources/local_source.dart';
import '../../sources/media_source.dart';
import 'playback_state.dart';

/// Hand-written, per the project's no-codegen rule for Riverpod.
final playbackControllerProvider =
    NotifierProvider<PlaybackController, PlaybackState>(
  PlaybackController.new,
);

/// The registry of configured sources.
///
/// Only the device exists today; SMB, WebDAV and Jellyfin register here as
/// they land, and nothing downstream changes.
final mediaSourcesProvider = Provider<Map<String, MediaSource>>((ref) {
  return const <String, MediaSource>{
    LocalSource.sourceId: LocalSource(),
  };
});

final localSourceProvider = Provider<LocalSource>((ref) => const LocalSource());

/// Owns the `media_kit` player and translates it into [PlaybackState].
///
/// This class is the only place in the app that imports `media_kit`, apart
/// from the widget that hosts the video surface — which cannot avoid it,
/// since `Video` needs a real [VideoController].
class PlaybackController extends Notifier<PlaybackState> {
  Player? _player;
  VideoController? _videoController;
  final List<StreamSubscription<void>> _subs = <StreamSubscription<void>>[];

  @override
  PlaybackState build() {
    ref.onDispose(_teardown);
    return const PlaybackState();
  }

  /// Non-null once [open] has been called at least once. The video surface
  /// waits on this.
  VideoController? get videoController => _videoController;

  /// Resolves [mediaRef] through its source and starts playback.
  ///
  /// Failure is reported through [PlaybackState.error] rather than thrown: a
  /// missing file must render as an inline message on the player, not as an
  /// unhandled exception.
  Future<void> open(MediaRef mediaRef) async {
    final sources = ref.read(mediaSourcesProvider);
    final source = sources[mediaRef.sourceId];

    if (source == null) {
      state = state.copyWith(error: 'Unknown source "${mediaRef.sourceId}"');
      return;
    }

    state = state.copyWith(buffering: true, clearError: true);

    try {
      final media = await source.resolve(mediaRef);
      await openResolved(media);
    } on MediaSourceException catch (e) {
      state = state.copyWith(buffering: false, error: e.message);
    } catch (e) {
      state = state.copyWith(buffering: false, error: 'Could not open: $e');
    }
  }

  /// Plays an already-resolved handle. Used when a caller resolved ahead of
  /// time (the picker does, so the player opens with a title already known).
  Future<void> openResolved(PlayableMedia media) async {
    final player = _ensurePlayer();

    state = state.copyWith(
      media: media,
      position: Duration.zero,
      duration: Duration.zero,
      buffered: Duration.zero,
      completed: false,
      buffering: true,
      clearError: true,
    );

    try {
      await player.open(
        Media(
          media.uri.toString(),
          httpHeaders: media.headers.isEmpty ? null : media.headers,
          start: media.startPosition == Duration.zero
              ? null
              : media.startPosition,
        ),
      );
    } catch (e) {
      state = state.copyWith(buffering: false, error: 'Playback failed: $e');
    }
  }

  Future<void> playOrPause() async => _player?.playOrPause();

  Future<void> play() async => _player?.play();

  Future<void> pause() async => _player?.pause();

  Future<void> seek(Duration to) async {
    final duration = state.duration;
    final clamped = to < Duration.zero
        ? Duration.zero
        : (duration > Duration.zero && to > duration ? duration : to);
    await _player?.seek(clamped);
    // Optimistic: the position stream lags a frame behind a seek, and the
    // scrubber must not snap back to where it was.
    state = state.copyWith(position: clamped);
  }

  /// Relative jump for the ±10s / ±30s controls and double-tap gestures.
  Future<void> skip(Duration delta) => seek(state.position + delta);

  Future<void> setSpeed(double speed) async {
    await _player?.setRate(speed);
    state = state.copyWith(speed: speed);
  }

  Future<void> setVolume(double volume) async {
    final clamped = volume.clamp(0.0, 100.0);
    await _player?.setVolume(clamped);
    state = state.copyWith(volume: clamped);
  }

  /// Releases the backend but keeps the notifier alive, so leaving the player
  /// screen does not strand a decoder.
  Future<void> stop() async {
    await _teardownAsync();
    state = const PlaybackState();
  }

  Player _ensurePlayer() {
    final existing = _player;
    if (existing != null) return existing;

    final player = Player();
    _player = player;
    _videoController = VideoController(player);
    _listen(player);
    return player;
  }

  void _listen(Player player) {
    final s = player.stream;
    _subs.addAll(<StreamSubscription<void>>[
      s.position.listen((v) => state = state.copyWith(position: v)),
      s.duration.listen((v) => state = state.copyWith(duration: v)),
      s.buffer.listen((v) => state = state.copyWith(buffered: v)),
      s.playing.listen((v) => state = state.copyWith(playing: v)),
      s.buffering.listen((v) => state = state.copyWith(buffering: v)),
      s.completed.listen((v) => state = state.copyWith(completed: v)),
      s.volume.listen((v) => state = state.copyWith(volume: v)),
      s.rate.listen((v) => state = state.copyWith(speed: v)),
      s.error.listen(
        (e) => state = state.copyWith(buffering: false, error: e),
      ),
    ]);
  }

  void _teardown() {
    unawaited(_teardownAsync());
  }

  Future<void> _teardownAsync() async {
    for (final sub in _subs) {
      await sub.cancel();
    }
    _subs.clear();

    final player = _player;
    _player = null;
    _videoController = null;
    await player?.dispose();
  }
}
