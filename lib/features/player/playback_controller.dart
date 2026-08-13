// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:async';
import 'dart:io' show Directory, Platform;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../core/resume_repository.dart';
import '../../sources/local_source.dart';
import '../../sources/media_source.dart';
import '../../sources/source_registry.dart';
import 'playback_state.dart';

/// Hand-written, per the project's no-codegen rule for Riverpod.
final playbackControllerProvider =
    NotifierProvider<PlaybackController, PlaybackState>(
  PlaybackController.new,
);

/// The device source, which always exists and needs no configuration.
///
/// Every other source comes from `sourceRegistryProvider`; see
/// `sources/source_registry.dart` for the map this controller resolves against.
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

  /// Mirrors the Player settings switch, which defaults to on. Not persisted
  /// yet — that arrives with the settings wiring.
  bool autoPlayNext = true;

  /// Throttles resume writes. The position stream fires several times a
  /// second; persisting that often would hammer storage for no benefit.
  DateTime _lastResumeWrite = DateTime.fromMillisecondsSinceEpoch(0);
  static const _resumeInterval = Duration(seconds: 5);

  /// Completes once the mpv properties media_kit leaves unset have been
  /// applied. [openResolved] waits on it so the first file already benefits.
  Future<void>? _nativeReady;

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
  Future<void> openResolved(PlayableMedia media, {PlaybackQueue? queue}) async {
    final player = _ensurePlayer();

    // Applied before the first open so the very first file gets the cache
    // directory and decoder settings too.
    await _nativeReady;

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
      queue: queue,
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

  /// Reads the folder [mediaRef] came from and turns it into the playlist.
  ///
  /// Runs *after* playback has started, deliberately: the file the user asked
  /// for should begin immediately rather than waiting on a directory listing
  /// that may cross a network. Prev/next simply appear a moment later.
  ///
  /// Failure is silent by design — a folder that cannot be listed costs the
  /// user the step buttons, not their video.
  Future<void> loadSiblingQueue(MediaRef mediaRef) async {
    final source = ref.read(mediaSourcesProvider)[mediaRef.sourceId];
    if (source is! BrowsableSource) return;

    try {
      final siblings = await siblingVideosOf(source, mediaRef);
      if (siblings.items.length <= 1) return;

      state = state.copyWith(
        queue: PlaybackQueue(items: siblings.items, index: siblings.index),
      );
    } catch (e) {
      debugPrint('Could not read the folder for a playlist: $e');
    }
  }

  /// Steps to the previous file in the folder.
  Future<void> playPrevious() => _step(-1);

  /// Steps to the next file in the folder.
  Future<void> playNext() => _step(1);

  Future<void> _step(int delta) async {
    final next = state.queue.stepTo(state.queue.index + delta);
    if (next == null) return;

    final source = ref.read(mediaSourcesProvider)[next.current!.sourceId];
    if (source == null) return;

    await _openAt(next, source);
  }

  Future<void> _openAt(PlaybackQueue queue, MediaSource source) async {
    final mediaRef = queue.current;
    if (mediaRef == null) return;

    state = state.copyWith(queue: queue, buffering: true, clearError: true);

    try {
      final media = await source.resolve(mediaRef);
      await openResolved(media, queue: queue);
    } on MediaSourceException catch (e) {
      state = state.copyWith(buffering: false, error: e.message);
    } catch (e) {
      state = state.copyWith(buffering: false, error: 'Could not open: $e');
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
    // Force a final write: the throttle would otherwise drop the last few
    // seconds, which is exactly the position the user will resume from.
    _recordProgress(force: true);

    await _teardownAsync();
    state = const PlaybackState();

    // The Continue-watching shelf is built from what was just written.
    ref.invalidate(resumePointsProvider);
  }

  Player _ensurePlayer() {
    final existing = _player;
    if (existing != null) return existing;

    final player = Player(
      configuration: PlayerConfiguration(
        // Without this libmpv sets `sub-ass: no` and renders ASS/SSA as plain
        // text, discarding every style, position and karaoke tag.
        libass: true,
        // Android's fontconfig cannot see system fonts, so libass silently
        // fails to render there unless it is handed a font itself. The app
        // already bundles Roboto for its own UI; reuse it.
        libassAndroidFont:
            Platform.isAndroid ? 'assets/fonts/Roboto-Variable.ttf' : null,
        libassAndroidFontName: Platform.isAndroid ? 'Roboto' : null,
        // Warnings as well as errors: a subtitle codec that cannot be found
        // is reported at warn level, and that line is the only place the
        // failure is visible. Surfaced in the stats overlay.
        logLevel: MPVLogLevel.warn,
      ),
    );
    _player = player;
    _videoController = VideoController(player);
    _listen(player);
    _nativeReady = _configureNative(player);
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
      s.position.listen((v) {
        state = state.copyWith(position: v);
        _recordProgress();
      }),
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
      s.completed.listen((v) {
        state = state.copyWith(completed: v);
        // Roll on to the next file in the folder, which is what the Player
        // settings page already calls "Auto-play next episode". Guarded on
        // hasNext so the last file simply stops.
        if (v && autoPlayNext && state.queue.hasNext) {
          unawaited(playNext());
        }
      }),
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
      s.log.listen((entry) {
        final line = '[${entry.level}] ${entry.prefix}: ${entry.text.trim()}';
        state = state.copyWith(
          logLines: <String>[
            // Oldest first, capped — an unbounded list on a long film would
            // grow without limit.
            ...state.logLines.length >= PlaybackState.logLimit
                ? state.logLines.skip(1)
                : state.logLines,
            line,
          ],
        );
      }),
    ]);
  }

  /// Writes where playback got to, at most once every [_resumeInterval].
  ///
  /// Throttled because the position stream fires several times a second and
  /// each write touches storage. The repository decides what is worth keeping
  /// — barely-started and finished files are dropped there, not here.
  void _recordProgress({bool force = false}) {
    final media = state.media;
    if (media == null || state.duration <= Duration.zero) return;

    final now = DateTime.now();
    if (!force && now.difference(_lastResumeWrite) < _resumeInterval) return;
    _lastResumeWrite = now;

    unawaited(
      ref.read(resumeRepositoryProvider).save(
            ResumePoint(
              sourceId: media.ref.sourceId,
              itemId: media.ref.itemId,
              title: media.title,
              kind: media.kind,
              position: state.position,
              duration: state.duration,
              updatedAt: now,
            ),
          ),
    );
  }

  /// Applies mpv options media_kit never sets.
  ///
  /// Both of these show up as errors in the mpv log and nowhere else, which is
  /// why they went unnoticed until the log was surfaced in the stats overlay.
  Future<void> _configureNative(Player player) async {
    final platform = player.platform;
    if (platform is! NativePlayer) return;

    try {
      // media_kit turns on `cache-on-disk` but never says *where*, so mpv
      // fails with "Failed to create file cache". Point it at the app's own
      // temporary directory, which is writable on every platform and is
      // cleaned up by the OS.
      final cacheDir = await getTemporaryDirectory();
      final mpvCache = Directory(p.join(cacheDir.path, 'mpv-cache'));
      await mpvCache.create(recursive: true);
      await platform.setProperty('cache-dir', mpvCache.path);

      // Unset by media_kit, so mpv falls back to its own default and can end
      // up attempting an interop that fails — on Windows the log shows
      // "dxva2-egl: Failed to create EGL surface". `auto-safe` is mpv's own
      // conservative pick and is exactly what the design's Player settings
      // page calls "Auto (safe)".
      await platform.setProperty('hwdec', 'auto-safe');
    } catch (e) {
      // Tuning is best-effort: playback works without it, and a failure here
      // must not stop a file from opening.
      debugPrint('Could not apply mpv tuning: $e');
    }
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
      codec: t.codec as String?,
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
    _chaptersLoaded = false;

    if (player == null) return;

    // Stop before disposing. `dispose()` alone can leave the audio thread
    // running long enough to be heard after the screen is gone, and each step
    // is guarded so a failure in one still lets the next run — a leaked
    // decoder keeps playing forever.
    try {
      await player.stop();
    } catch (_) {
      // Already gone; disposing is still worth attempting.
    }
    try {
      await player.dispose();
    } catch (_) {
      // Nothing further we can do, and throwing out of teardown would take
      // the navigation pop down with it.
    }
  }
}
