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

  /// Guards against re-reading the chapter list on every duration tick.
  bool _chaptersLoaded = false;

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

    // Otherwise a second file inherits the first one's chapter list.
    _chaptersLoaded = false;

    state = state.copyWith(
      media: media,
      position: Duration.zero,
      duration: Duration.zero,
      buffered: Duration.zero,
      completed: false,
      buffering: true,
      containerChapters: const <MediaChapter>[],
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

  /// Selects a subtitle stream. Pass null for "off".
  Future<void> setSubtitleTrack(MediaTrack? track) async {
    final player = _player;
    if (player == null) return;
    await player.setSubtitleTrack(
      track == null || track.isOff
          ? SubtitleTrack.no()
          : SubtitleTrack(track.id, track.label, track.language),
    );
  }

  Future<void> setAudioTrack(MediaTrack track) async {
    final player = _player;
    if (player == null) return;
    await player.setAudioTrack(
      track.isAuto
          ? AudioTrack.auto()
          : AudioTrack(track.id, track.label, track.language),
    );
  }

  void _listen(Player player) {
    final s = player.stream;
    _subs.addAll(<StreamSubscription<void>>[
      s.position.listen((v) => state = state.copyWith(position: v)),
      s.duration.listen((v) {
        state = state.copyWith(duration: v);
        // A known duration means the file is demuxed, which is the earliest
        // point the container's chapter list can be read.
        if (v > Duration.zero && !_chaptersLoaded) {
          _chaptersLoaded = true;
          unawaited(_loadContainerChapters(v));
        }
      }),
      s.buffer.listen((v) => state = state.copyWith(buffered: v)),
      s.playing.listen((v) => state = state.copyWith(playing: v)),
      s.buffering.listen((v) => state = state.copyWith(buffering: v)),
      s.completed.listen((v) => state = state.copyWith(completed: v)),
      s.volume.listen((v) => state = state.copyWith(volume: v)),
      s.rate.listen((v) => state = state.copyWith(speed: v)),
      s.tracks.listen((t) {
        state = state.copyWith(
          audioTracks: t.audio.map(_toTrack).toList(),
          subtitleTracks: t.subtitle.map(_toTrack).toList(),
        );
      }),
      s.track.listen((t) {
        state = state.copyWith(
          activeAudio: _toTrack(t.audio),
          activeSubtitle: _toTrack(t.subtitle),
          stats: _statsFrom(player, t),
        );
      }),
      s.width.listen((_) => state = state.copyWith(stats: _statsFrom(player))),
      s.height.listen((_) => state = state.copyWith(stats: _statsFrom(player))),
      s.error.listen(
        (e) => state = state.copyWith(buffering: false, error: e),
      ),
    ]);
  }

  /// Reads the container's own chapter list out of libmpv.
  ///
  /// MKV and MP4 routinely embed chapters, so a local file is not
  /// chapterless — only *intro marking* needs a server. Read through the
  /// `chapter-list` properties because media_kit exposes no chapter API.
  Future<void> _loadContainerChapters(Duration duration) async {
    final platform = _player?.platform;
    // Web and any future backend without the mpv property interface simply
    // report no chapters rather than failing.
    if (platform is! NativePlayer) return;

    try {
      final rawCount = await platform.getProperty('chapter-list/count');
      final count = int.tryParse(rawCount.trim()) ?? 0;
      if (count <= 0) return;

      final starts = <Duration>[];
      final titles = <String>[];

      for (var i = 0; i < count; i++) {
        final rawTime = await platform.getProperty('chapter-list/$i/time');
        final seconds = double.tryParse(rawTime.trim()) ?? 0;
        starts.add(Duration(milliseconds: (seconds * 1000).round()));

        final title = (await platform.getProperty('chapter-list/$i/title')).trim();
        titles.add(title.isEmpty ? 'Chapter ${i + 1}' : title);
      }

      final chapters = <MediaChapter>[
        for (var i = 0; i < count; i++)
          MediaChapter(
            title: titles[i],
            start: starts[i],
            // A chapter runs until the next one begins.
            end: i + 1 < count ? starts[i + 1] : duration,
            isIntro: _looksLikeIntro(titles[i]),
          ),
      ];

      state = state.copyWith(containerChapters: chapters);
    } catch (_) {
      // The property is absent on some demuxers; no chapters is a valid
      // answer, not an error worth surfacing to the user.
    }
  }

  /// Title heuristic for container chapters.
  ///
  /// Only a server can say authoritatively that a segment is an intro, but
  /// rips overwhelmingly name the chapter "Intro", "Opening" or "OP", and a
  /// false positive costs the user nothing more than an extra pill they can
  /// ignore. Source-provided chapters never go through this.
  static bool _looksLikeIntro(String title) {
    final t = title.toLowerCase().trim();
    return t == 'intro' ||
        t == 'opening' ||
        t == 'op' ||
        t == 'avant' ||
        t == 'title sequence' ||
        t == 'opening credits' ||
        t.startsWith('intro ') ||
        t.startsWith('opening ');
  }

  /// Flattens a backend track into the label the design's pills show.
  MediaTrack _toTrack(dynamic t) {
    final String id = t.id as String;
    final String? title = t.title as String?;
    final String? language = t.language as String?;

    final kind = t is VideoTrack
        ? TrackKind.video
        : (t is AudioTrack ? TrackKind.audio : TrackKind.subtitle);

    return MediaTrack(
      id: id,
      kind: kind,
      label: _labelFor(id, title, language, t),
      language: language,
      isDefault: (t.isDefault as bool?) ?? false,
    );
  }

  String _labelFor(String id, String? title, String? language, dynamic t) {
    if (id == 'no') return 'Off';
    if (id == 'auto') return 'Auto';

    // Prefer the embedded title, then language, then a codec summary — a
    // bare track number tells the user nothing.
    final parts = <String>[
      if (title != null && title.isNotEmpty) title
      else if (language != null && language.isNotEmpty) language.toUpperCase(),
    ];

    final codec = t.codec as String?;
    final channels = t.channels as String?;
    if (parts.isEmpty && codec != null) parts.add(codec.toUpperCase());
    if (channels != null && channels.isNotEmpty) parts.add(channels);

    return parts.isEmpty ? 'Track $id' : parts.join(' · ');
  }

  PlaybackStats _statsFrom(Player player, [Track? track]) {
    final ps = player.state;
    final audio = track?.audio ?? ps.track.audio;
    final video = track?.video ?? ps.track.video;

    return PlaybackStats(
      width: ps.width,
      height: ps.height,
      videoCodec: video.codec,
      videoDecoder: video.decoder,
      fps: video.fps,
      videoBitrate: video.bitrate,
      audioCodec: audio.codec,
      audioChannels: audio.channels,
      audioSampleRate: audio.samplerate,
      audioBitrate: ps.audioBitrate,
    );
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
