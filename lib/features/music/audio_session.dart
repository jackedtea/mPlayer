// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../sources/media_source.dart';
import '../cast/cast_controller.dart';
import '../player/now_playing.dart';
import '../player/playback_controller.dart';
import '../player/playback_state.dart';
import '../settings/player_settings.dart';

final audioSessionProvider = NotifierProvider<AudioSession, bool>(
  AudioSession.new,
);

/// Owns the decoder's lifetime while music plays. State is true while it does.
///
/// A video's lifetime is its `/player` route: leaving the film stops the film.
/// A song has no route to live and die with, because it is listened to while
/// doing something else in the app. This holds what the route holds for a
/// video: the notification, its buttons and the background rule.
///
/// **There is one way out**, the controller's `stop`, reached through [end] or
/// by something else stopping the controller, which [_onPlayback] notices. The
/// player's teardown comments record why: a leaked audio thread was a real bug.
class AudioSession extends Notifier<bool> {
  /// How far into a song Previous starts it again rather than going back.
  static const restartWindow = Duration(seconds: 3);

  PlaybackController get _playback =>
      ref.read(playbackControllerProvider.notifier);

  NowPlayingController get _notification =>
      ref.read(nowPlayingProvider.notifier);

  @override
  bool build() {
    final commands = _notification.commands.listen(_onCommand);
    final lifecycle = AppLifecycleListener(onStateChange: _onLifecycle);
    ref.onDispose(() {
      unawaited(commands.cancel());
      lifecycle.dispose();
    });

    ref.listen(playbackControllerProvider, _onPlayback);
    return false;
  }

  /// Starts [media] the way its kind asks: a song here, with the user left
  /// where they are, and anything else on the full-screen player.
  ///
  /// The one place that decides, so a song cannot reach `/player` by a route
  /// someone forgot to change.
  Future<void> present(
    GoRouter router,
    PlayableMedia media, {
    PlaybackQueue? queue,
  }) async {
    if (!media.isAudio) {
      unawaited(
        router.push(
          '/player',
          extra: queue == null
              ? media
              : PlayerLaunch(media: media, queue: queue),
        ),
      );
      return;
    }

    state = true;
    await _playback.openInstead(media, queue: queue);
  }

  /// Stops the music and lets the decoder go.
  ///
  /// Free when no music is playing, so the video player calls it on every
  /// open: one decoder, and the film takes it.
  Future<void> end() async {
    if (!state) return;
    state = false;
    await _notification.stop();
    // The television too: the mini player's cross should not leave a song
    // playing in the next room with nothing on screen to stop it.
    if (ref.read(castControllerProvider).isCasting) {
      await ref.read(castControllerProvider.notifier).disconnect();
    }
    await _playback.stop();
  }

  /// Play or pause. A queue that has run out starts its last song again:
  /// the decoder has nothing left to resume.
  Future<void> togglePlaying() {
    final now = ref.read(playbackControllerProvider);
    return now.completed && !now.playing
        ? _playback.restartCurrent()
        : _playback.playOrPause();
  }

  /// Back to the start of this song, or to the one before if it has only just
  /// begun. What every music player's Previous does.
  Future<void> previous() {
    final now = ref.read(playbackControllerProvider);
    return now.queue.hasPrevious && now.position <= restartWindow
        ? _playback.playPrevious()
        : _playback.seek(Duration.zero);
  }

  void _onPlayback(PlaybackState? previous, PlaybackState next) {
    if (!state) return;

    final media = next.media;
    if (media == null) {
      // Stopped from somewhere else. Nothing is left to own, and a
      // notification left up would claim otherwise.
      if (previous?.media != null) {
        state = false;
        unawaited(_notification.stop());
      }
      return;
    }

    if (!ref.read(playerSettingsProvider).backgroundAudio) {
      if (ref.read(nowPlayingProvider)) unawaited(_notification.stop());
      return;
    }

    unawaited(
      _notification.update(
        title: media.title,
        subtitle: media.artist,
        album: media.album,
        artUrl: media.artworkUri?.toString(),
        playing: next.playing,
        position: next.position,
        duration: next.duration,
        speed: next.speed,
        hasNext: next.queue.hasNext,
        hasPrevious: next.queue.hasPrevious,
      ),
    );
  }

  void _onCommand(NowPlayingEvent event) {
    if (!state) return;

    switch (event.command) {
      case NowPlayingCommand.play:
        unawaited(_playback.play());
      case NowPlayingCommand.pause:
        unawaited(_playback.pause());
      case NowPlayingCommand.next:
        unawaited(_playback.playNext());
      case NowPlayingCommand.previous:
        unawaited(previous());
      case NowPlayingCommand.seek:
        final to = event.position;
        if (to != null) unawaited(_playback.seek(to));
      case NowPlayingCommand.stop:
        unawaited(end());
    }
  }

  /// Background audio is the point of music, so this only acts for a user who
  /// turned it off. No delay as the video player has: that one waits to see
  /// whether a picture-in-picture window opens, and a song has none.
  void _onLifecycle(AppLifecycleState lifecycle) {
    if (!state) return;
    if (lifecycle != AppLifecycleState.paused &&
        lifecycle != AppLifecycleState.hidden) {
      return;
    }
    if (ref.read(playerSettingsProvider).backgroundAudio) return;
    unawaited(_playback.pause());
  }
}
