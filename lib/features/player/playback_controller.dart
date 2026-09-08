// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:async';
import 'dart:io' show Directory, Platform;

import 'package:flutter/foundation.dart' show Uint8List, debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../core/models/library_models.dart';
import '../../core/resume_repository.dart';
import '../../servers/media_library_source.dart';
import '../settings/player_settings.dart';
import '../../sources/local_source.dart';
import '../../sources/media_source.dart';
import '../../sources/media_store_source.dart';
import '../../sources/source_registry.dart';
import 'playback_state.dart';
import 'segment_skipper.dart';
import 'smart_subtitles.dart';

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

  /// Last value read from libmpv's `hwdec-current`.
  ///
  /// Held here rather than fetched where it is needed: the stats snapshot is
  /// built synchronously from several streams, and reading an mpv property is
  /// asynchronous. So the property is polled at the points it can change — a
  /// new file, a new track list, a change to the setting — and the snapshot
  /// takes whatever the last read produced.
  String? _hwdec;
  final List<StreamSubscription<void>> _subs = <StreamSubscription<void>>[];

  /// Guards against re-reading the chapter list on every duration tick.
  bool _chaptersLoaded = false;

  /// Held while a step is in flight, so the end of a file cannot be acted on
  /// twice — the closing report the step waits on takes long enough that a
  /// second `completed` would otherwise skip an episode.
  bool _stepping = false;

  /// Where the position stream last reported, so [_applySegments] can tell a
  /// second of playback from a seek. Null until the first tick of a file.
  Duration? _lastPosition;

  /// The segments already seeked past on this file.
  ///
  /// An auto-skip lands on the segment's end, which is one millisecond from
  /// still being inside it; without this a rounding error or a rewind to just
  /// before the end can bounce the viewer out a second time.
  final Set<MediaSegment> _skipped = <MediaSegment>{};

  /// Smart subtitles run once per file, on the first real track list. Rerunning
  /// on every later one would undo a track the user picked by hand.
  bool _smartSubtitlesApplied = false;

  /// Whether the media index has already been asked for this session.
  ///
  /// A refusal must not put a system dialog in front of every file the user
  /// opens afterwards, so the question is asked once and then let go of.
  bool _askedForIndexAccess = false;

  bool get autoPlayNext => ref.read(playerSettingsProvider).autoPlayNext;

  /// Throttles resume writes. The position stream fires several times a
  /// second; persisting that often would hammer storage for no benefit.
  DateTime _lastResumeWrite = DateTime.fromMillisecondsSinceEpoch(0);
  static const _resumeInterval = Duration(seconds: 5);

  /// Throttles the frame grab behind the resume write. Decoding and encoding
  /// a still is far heavier than writing a position, so the shelf's artwork
  /// only follows playback every so often — and always on the final write,
  /// which is the frame the user actually left off on.
  DateTime _lastThumbnail = DateTime.fromMillisecondsSinceEpoch(0);
  static const _thumbnailInterval = Duration(seconds: 30);

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
    _smartSubtitlesApplied = false;
    _lastPosition = null;
    _skipped.clear();
    // A new file gets its own still straight away rather than waiting out
    // the previous one's interval.
    _lastThumbnail = DateTime.fromMillisecondsSinceEpoch(0);
    // The next file may well decode differently from this one — the setting
    // is the same, the codec is not — so the reading is dropped rather than
    // carried over and shown against the wrong video.
    _hwdec = null;

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
      return;
    }

    // After the open, not before: `sub-files-append` is read when a file is
    // loaded, so appending first would attach this file's subtitles to
    // whatever was already playing.
    await _loadServerSubtitles(media.externalSubtitles);
  }

  /// Hands libmpv the subtitle files a server keeps beside the video.
  ///
  /// Appended without being selected. Which one to show is smart subtitles'
  /// decision or the user's, and a server that holds six languages would
  /// otherwise leave whichever it listed last on the screen.
  Future<void> _loadServerSubtitles(List<ExternalSubtitle> subtitles) async {
    if (subtitles.isEmpty) return;

    final platform = _player?.platform;
    if (platform is! NativePlayer) return;

    for (final ExternalSubtitle subtitle in subtitles) {
      try {
        await platform.setProperty('sub-files-append', subtitle.uri.toString());
      } catch (e) {
        // One unreadable subtitle must not cost the user the other five, and
        // it costs them nothing they can see: the track simply is not listed.
        debugPrint('Could not attach ${subtitle.label}: $e');
      }
    }
  }

  /// Acts on the stretch [now] has just entered, if the user asked for it.
  ///
  /// The rule itself lives in [segmentToSkip], where it can be tested against
  /// a table of positions rather than against a decoder.
  Future<void> _applySegments(Duration? previous, Duration now) async {
    final settings = ref.read(playerSettingsProvider);

    final segment = segmentToSkip(
      segments: state.segments,
      previous: previous,
      now: now,
      actionFor: settings.actionFor,
      alreadySkipped: _skipped,
    );
    if (segment == null) return;

    _skipped.add(segment);
    await seek(segment.end);
  }

  /// Works out what [mediaRef] plays alongside and turns it into the
  /// playlist.
  ///
  /// Two shapes of answer, because sources come in two shapes: a folder to
  /// list, or a server that has to be asked which episodes belong to the
  /// series. Without the second, an episode opened from a library plays alone
  /// — no prev/next, and nothing for "Auto-play next episode" to roll on to.
  ///
  /// Runs *after* playback has started, deliberately: the file the user asked
  /// for should begin immediately rather than waiting on a listing that may
  /// cross a network. Prev/next simply appear a moment later.
  ///
  /// Failure is silent by design — a listing that cannot be read costs the
  /// user the step buttons, not their video.
  Future<void> loadSiblingQueue(MediaRef mediaRef) async {
    final source = ref.read(mediaSourcesProvider)[mediaRef.sourceId];

    // The source's own answer first, the media index second. The second is
    // what a hand-off from another app needs: it arrives on the device source
    // carrying a `content://` URI, which has no directory to list.
    final siblings = await _sourceSiblings(source, mediaRef) ??
        await _indexedSiblings(mediaRef);
    if (siblings == null || siblings.items.length <= 1) return;

    state = state.copyWith(
      queue: PlaybackQueue(
        items: siblings.items,
        index: siblings.index,
        // Only a server answers with a series; a folder holds whatever it
        // holds, and the prompt says so.
        isSeries: source is QueueableSource,
      ),
    );
  }

  /// What the item's own source says plays beside it.
  ///
  /// Null rather than throwing, and null for a run of one: both mean "no
  /// playlist from here", and the caller has somewhere else to ask.
  Future<({List<MediaRef> items, int index})?> _sourceSiblings(
    MediaSource? source,
    MediaRef mediaRef,
  ) async {
    try {
      final found = switch (source) {
        final BrowsableSource s => await siblingVideosOf(s, mediaRef),
        final QueueableSource s => await s.siblingsOf(mediaRef),
        _ => null,
      };
      return (found == null || found.items.length <= 1) ? null : found;
    } catch (e) {
      debugPrint('No playlist from ${mediaRef.sourceId}: $e');
      return null;
    }
  }

  /// The folder the media index files [mediaRef] under.
  ///
  /// A file manager hands a video over with a URI it owns — its own
  /// `FileProvider`, a `MediaStore` id, a bare path — and the device source
  /// can list none of those. The index can: it is asked which row the URI is,
  /// and the bucket that row sits in becomes the playlist.
  ///
  /// The queue is rebuilt on the index's own source, so stepping resolves
  /// through it rather than through the URI the hand-off happened to use.
  Future<({List<MediaRef> items, int index})?> _indexedSiblings(
    MediaRef mediaRef,
  ) async {
    if (!MediaStoreSource.isSupported) return null;

    final index = ref.read(mediaStoreSourceProvider);
    try {
      if (!await _indexReadable(index)) {
        debugPrint('No playlist: the media index may not be read.');
        return null;
      }

      final video = await index.bucketForUri(mediaRef.itemId);
      if (video == null) {
        debugPrint('No playlist: ${mediaRef.itemId} is not in the index.');
        return null;
      }

      final listing = await index.listDirectory(video.bucketId);
      final items = <MediaRef>[
        for (final BrowseEntry e in listing.entries)
          if (e.isPlayable)
            MediaRef(
              sourceId: MediaStoreSource.sourceId,
              itemId: e.path,
              title: e.name,
            ),
      ];

      // The index's URI for the row, not the one the hand-off arrived on —
      // those differ for every foreign provider, and a miss here would put
      // the queue on the wrong file rather than merely lose it.
      final at = items.indexWhere((m) => m.itemId == video.uri);
      return at < 0 ? null : (items: items, index: at);
    } catch (e) {
      debugPrint('No playlist from the media index: $e');
      return null;
    }
  }

  /// Whether the media index may be read, asking for it if it never has been.
  ///
  /// A video handed over by another app opens the player directly, and the
  /// Files tab is the only screen that asks for this permission — so a fresh
  /// install could never step through the folder it was handed a file from,
  /// however many videos sat beside it. Asked here because this is the first
  /// moment the answer is actually needed.
  Future<bool> _indexReadable(MediaStoreSource index) async {
    if (await index.hasPermission()) return true;
    if (_askedForIndexAccess) return false;

    _askedForIndexAccess = true;
    return index.requestPermission();
  }

  /// Steps to the previous file in the folder.
  Future<void> playPrevious() => _step(-1);

  /// Steps to the next file in the folder.
  Future<void> playNext() => _step(1);

  Future<void> _step(int delta) async {
    if (_stepping) return;

    final next = state.queue.stepTo(state.queue.index + delta);
    if (next == null) return;

    final source = ref.read(mediaSourcesProvider)[next.current!.sourceId];
    if (source == null) return;

    _stepping = true;
    try {
      await _openAt(next, source);
    } finally {
      _stepping = false;
    }
  }

  /// Plays the first file of the folder again, for [LoopMode.all].
  Future<void> _restartQueue() async {
    if (_stepping) return;

    final first = state.queue.stepTo(0);
    if (first == null) return;

    final source = ref.read(mediaSourcesProvider)[first.current!.sourceId];
    if (source == null) return;

    _stepping = true;
    try {
      await _openAt(first, source);
    } finally {
      _stepping = false;
    }
  }

  Future<void> _openAt(PlaybackQueue queue, MediaSource source) async {
    final mediaRef = queue.current;
    if (mediaRef == null) return;

    // The episode being stepped away from is done with, and nothing else
    // will say so: the teardown that normally reports it only runs when the
    // player closes, so a binge would otherwise leave a session open on the
    // server for every episode it rolled through.
    await _closeCurrent();

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

  /// Steps the loop control on to its next mode.
  ///
  /// `all` is skipped for a lone video: mpv's playlist holds exactly one item
  /// whatever the folder holds, so repeating "the playlist" and repeating the
  /// file would be the same thing with two different labels.
  Future<void> cycleLoop() =>
      setLoop(state.loop.next(hasSiblings: state.queue.hasSiblings));

  /// Repeat one goes straight into libmpv, which loops the file without a
  /// gap. Repeat all cannot: the folder is the app's queue and mpv has never
  /// been told about it, so the roll back to the first file is done in the
  /// completion handler alongside auto-play-next.
  Future<void> setLoop(LoopMode mode) async {
    await _player?.setPlaylistMode(
      mode == LoopMode.one ? PlaylistMode.single : PlaylistMode.none,
    );
    state = state.copyWith(loop: mode);
  }

  /// The frame on screen right now, as JPEG bytes, or null.
  ///
  /// Null for an audio-only file, a frame that is not decoded yet, or a
  /// backend that cannot screenshot — the caller says so rather than writing
  /// an empty file.
  Future<Uint8List?> captureFrame() async {
    final player = _player;
    if (player == null) return null;

    try {
      return await player.screenshot();
    } catch (e) {
      debugPrint('Could not take a screenshot: $e');
      return null;
    }
  }

  /// Opens the current item again, at [at].
  ///
  /// What a quality change needs: the URL the server hands out encodes the
  /// decision it made, so a new cap only takes effect on a fresh
  /// `PlaybackInfo`. Reopening rather than seeking, because there is nothing
  /// to seek — the stream being played is a different stream afterwards.
  ///
  /// The position is passed in rather than read here: by the time this runs
  /// the sheet has been open for a moment and the film has moved on.
  Future<void> reopenCurrent({Duration? at}) async {
    final media = state.media;
    if (media == null) return;

    final source = ref.read(mediaSourcesProvider)[media.ref.sourceId];
    if (source == null) return;

    final resume = at ?? state.position;
    final queue = state.queue;

    state = state.copyWith(buffering: true, clearError: true);

    try {
      final resolved = await source.resolve(media.ref);
      await openResolved(
        resolved.startingAt(resume),
        queue: queue.isEmpty ? null : queue,
      );
    } on MediaSourceException catch (e) {
      state = state.copyWith(buffering: false, error: e.message);
    }
  }

  /// Releases the backend but keeps the notifier alive, so leaving the player
  /// screen does not strand a decoder.
  Future<void> stop() async {
    // Silence first, and synchronously as far as the decoder is concerned.
    //
    // Everything below this line waits on something slow — a frame grabbed
    // off the player, a write to disk, a report to a server that may be
    // unreachable — and until the teardown at the end of it the file is
    // still playing. That is what "I pressed back and the film kept going"
    // was: not a leaked route, just several seconds of bookkeeping with the
    // audio thread left running underneath it.
    await _player?.pause();

    await _closeCurrent();

    await _teardownAsync();
    state = const PlaybackState();

    // The Continue-watching shelf is built from what was just written.
    ref.invalidate(resumePointsProvider);
  }

  /// Files the closing report for whatever is playing now.
  ///
  /// Force a final write: the throttle would otherwise drop the last few
  /// seconds, which is exactly the position the user will resume from.
  /// Awaited, unlike the periodic writes — it grabs a frame off the player,
  /// and tearing the player down underneath that would lose the still. The
  /// server report goes second and while there is still a session to close:
  /// it is what ends the transcode and what marks a finished episode watched.
  ///
  /// Bounded, because none of it is worth holding anything open for: a server
  /// that has gone away must cost the user a progress report, not a player
  /// that never closes or a next episode that never starts.
  Future<void> _closeCurrent() async {
    if (state.media == null) return;

    try {
      await Future<void>(() async {
        await _recordProgress(force: true);
        await _reportStopped();
      }).timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('Gave up on the closing report: $e');
    }
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
        final previous = _lastPosition;
        _lastPosition = v;
        state = state.copyWith(position: v);
        unawaited(_applySegments(previous, v));
        unawaited(_recordProgress());
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
        if (!v) return;
        if (autoPlayNext && state.queue.hasNext) {
          unawaited(playNext());
        } else if (state.loop == LoopMode.all && !state.queue.hasNext) {
          // The end of the folder with repeat-all on: back to the top. mpv
          // never saw the folder, so this is the one loop it cannot do
          // itself. `hasNext` guards it so the roll-on above still wins
          // mid-folder.
          unawaited(_restartQueue());
        }
      }),
      s.volume.listen((v) => state = state.copyWith(volume: v)),
      s.rate.listen((v) => state = state.copyWith(speed: v)),
      s.tracks.listen((t) {
        state = state.copyWith(
          audioTracks: t.audio.map(_toTrack).toList(),
          subtitleTracks: t.subtitle.map(_toTrack).toList(),
        );

        // mpv publishes a list holding only its "auto" and "no" placeholders
        // before a file is demuxed; waiting for a real track keeps the rule
        // from running against nothing.
        final real = state.audioTracks.where((x) => !x.isAuto && !x.isOff);
        if (!_smartSubtitlesApplied && real.isNotEmpty) {
          _smartSubtitlesApplied = true;
          unawaited(applySmartSubtitles());
        }

        // A demuxed file is the earliest point mpv has chosen a decoder for
        // it, and a codec the GPU refuses is exactly the case worth
        // reporting — the setting says "prefer hardware" and the picture is
        // coming off the CPU regardless.
        unawaited(refreshDecoder());
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
  Future<void> _recordProgress({bool force = false}) async {
    final media = state.media;
    if (media == null || state.duration <= Duration.zero) return;

    final now = DateTime.now();
    if (!force && now.difference(_lastResumeWrite) < _resumeInterval) return;
    _lastResumeWrite = now;

    // Grabbed before the write so the still and the position it is shelved
    // with come from the same moment.
    final thumbnail = await _captureThumbnail(force: force, now: now);

    await ref.read(resumeRepositoryProvider).save(
          ResumePoint(
            sourceId: media.ref.sourceId,
            itemId: media.ref.itemId,
            title: media.title,
            kind: media.kind,
            position: state.position,
            duration: state.duration,
            updatedAt: now,
          ),
          thumbnail: thumbnail,
        );

    // A server keeps its own watch state, gathered from every device the
    // user owns. Told alongside the local write rather than instead of it:
    // the local point is what makes the shelf work offline.
    await _reportToSource(media, paused: !state.playing);
  }

  /// Passes the position on to a source that keeps watch state of its own.
  Future<void> _reportToSource(PlayableMedia media, {required bool paused}) {
    final source = ref.read(mediaSourcesProvider)[media.ref.sourceId];
    if (source case final ProgressReporting reporter) {
      return reporter.reportProgress(
        media.ref.itemId,
        position: state.position,
        isPaused: paused,
      );
    }
    return Future<void>.value();
  }

  /// The current video frame as JPEG, for the Continue-watching card.
  ///
  /// Null whenever there is nothing worth shelving — an audio-only file, a
  /// frame that is not decoded yet, or a backend that cannot screenshot. The
  /// card falls back to its gradient in every one of those cases, so a
  /// failure here is never worth surfacing.
  Future<Uint8List?> _captureThumbnail({
    required bool force,
    required DateTime now,
  }) async {
    final player = _player;
    if (player == null) return null;
    if (!force && now.difference(_lastThumbnail) < _thumbnailInterval) {
      return null;
    }
    _lastThumbnail = now;

    try {
      return await player.screenshot();
    } catch (e) {
      debugPrint('Could not grab a thumbnail: $e');
      return null;
    }
  }

  /// Switches between hardware and software decoding without leaving the film.
  ///
  /// The same preference the Player settings page owns, written through the
  /// same notifier — a shortcut to it, not a second setting. Reachable from
  /// the player because the file that needs it is the one already on screen:
  /// a driver that mishandles a codec shows a green or juddering picture, and
  /// "software" is the only way past it.
  ///
  /// mpv reinitialises the video chain on an `hwdec` change, so this takes
  /// effect on the frame after it rather than on the next file.
  Future<void> setHardwareDecoding(HardwareDecoding mode) async {
    final settings = ref.read(playerSettingsProvider);
    if (settings.hardwareDecoding == mode) return;

    final next = settings.copyWith(hardwareDecoding: mode);
    await ref.read(playerSettingsProvider.notifier).update(next);
    // Which also re-reads what mpv settled on, so there is one place that
    // pushes `hwdec` and one place that reports the result of having done so.
    await applySettings(next);
  }

  /// Re-reads which decoder is running and publishes it.
  ///
  /// Asking for hardware is not the same as getting it: mpv falls back to
  /// software on its own whenever the GPU cannot take a codec, and says so
  /// nowhere but this property. Without it the picker would report the
  /// user's request back to them as though it were the outcome.
  Future<void> refreshDecoder() async {
    final player = _player;
    final platform = player?.platform;
    // Any backend without the mpv property interface simply never reports a
    // decoder, and the stats line falls back to the description heuristic.
    if (player == null || platform is! NativePlayer) return;

    try {
      final value = (await platform.getProperty('hwdec-current')).trim();
      if (value.isEmpty || value == _hwdec) return;
      _hwdec = value;
      state = state.copyWith(stats: _statsFrom(player));
    } catch (e) {
      debugPrint('Could not read hwdec-current: $e');
    }
  }

  /// Waits out mpv's decoder reinitialisation, then reports what it landed on.
  ///
  /// The property does not change on the same turn the option is set — the
  /// video chain is torn down and rebuilt first — so reading it immediately
  /// gives the previous answer. Polled for the same reason
  /// [_awaitNewSubtitleTrack] is: there is no event to await, and a second is
  /// far longer than a reinit takes.
  Future<void> _awaitDecoderSwitch() async {
    const step = Duration(milliseconds: 60);
    final before = _hwdec;

    for (var waited = Duration.zero;
        waited < const Duration(seconds: 1);
        waited += step) {
      await Future<void>.delayed(step);
      await refreshDecoder();
      if (_hwdec != before) return;
    }
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
      // "dxva2-egl: Failed to create EGL surface".
      await applySettings(ref.read(playerSettingsProvider));
    } catch (e) {
      // Tuning is best-effort: playback works without it, and a failure here
      // must not stop a file from opening.
      debugPrint('Could not apply mpv tuning: $e');
    }
  }

  /// Pushes the user's preferences into libmpv.
  ///
  /// Called on open and again whenever the settings change, so a slider moved
  /// mid-playback takes effect without restarting the file.
  ///
  /// Subtitle styling reaches plain-text formats (SRT, WebVTT). ASS/SSA carry
  /// their own styling and libmpv honours that instead — deliberately, since
  /// overriding it would throw away the positioning and karaoke the file asks
  /// for.
  Future<void> applySettings(PlayerSettings settings) async {
    final platform = _player?.platform;
    if (platform is! NativePlayer) return;

    try {
      await platform.setProperty('hwdec', settings.hardwareDecoding.mpvValue);
      await platform.setProperty(
        'sub-font-size',
        '${settings.mpvSubtitleFontSize}',
      );
      await platform.setProperty('sub-color', settings.mpvSubtitleColour);
      await platform.setProperty(
        'sub-back-color',
        settings.mpvSubtitleBackColour,
      );
      await platform.setProperty(
        'sub-delay',
        '${settings.subtitleDelay.inMilliseconds / 1000}',
      );
      // mpv takes both delays in seconds, and both accept a negative value —
      // audio ahead of the picture is as common as behind it.
      await platform.setProperty(
        'audio-delay',
        '${settings.audioDelay.inMilliseconds / 1000}',
      );
      // Empty means "decode everything here", which is the safe default: a
      // device with no receiver attached plays silence otherwise.
      await platform.setProperty('audio-spdif', settings.mpvSpdif);
      await platform.setProperty('volume-max', '${settings.volumeBoost}');
      await platform.setProperty('gapless-audio', settings.gapless.mpvValue);
    } catch (e) {
      // Best-effort: a property mpv does not know must not stop playback.
      debugPrint('Could not apply player settings: $e');
    }

    // `hwdec` was just written, so whatever was last read about the decoder
    // may no longer be true. Here rather than only in [setHardwareDecoding]
    // because the Player settings page reaches this method directly, and a
    // change made there must not leave a stale reading behind it.
    unawaited(_awaitDecoderSwitch());
  }

  /// Picks the audio and subtitle tracks the user's language preference asks
  /// for, once per file.
  ///
  /// Public so the settings page can re-run it when the preference changes
  /// mid-film — the alternative is telling the user to reopen the file.
  Future<void> applySmartSubtitles() async {
    final settings = ref.read(playerSettingsProvider);
    if (!settings.smartSubtitles) return;

    final selection = smartSelection(
      audioTracks: state.audioTracks,
      subtitleTracks: state.subtitleTracks,
      activeAudio: state.activeAudio,
      preferred: settings.preferredLanguage,
    );
    if (selection.isEmpty) return;

    final audio = selection.audio;
    if (audio != null) await setAudioTrack(audio);

    if (selection.subtitlesOff) {
      await setSubtitleTrack(null);
    } else if (selection.subtitle != null) {
      await setSubtitleTrack(selection.subtitle);
    }
  }

  /// Loads a subtitle file that is not in the container.
  ///
  /// libmpv finds a sidecar beside a local file on its own; this covers the
  /// rest — a differently named file, one downloaded separately, or a video
  /// streaming from a share whose directory mpv never sees.
  ///
  /// `sub-files-append` rather than `SubtitleTrack.uri`: the latter keys the
  /// selection by the URI while mpv's own track list numbers it, so the
  /// picker would show the file twice and tick neither.
  Future<void> addExternalSubtitle(Uri uri, {String? title}) async {
    final platform = _player?.platform;
    if (platform is! NativePlayer) return;

    final before = state.subtitleTracks.map((t) => t.id).toSet();

    try {
      // `sub-files` is a path list, so a local file goes in as a path — a
      // file:// URL would reach mpv with its spaces percent-encoded.
      await platform.setProperty(
        'sub-files-append',
        uri.isScheme('file') ? uri.toFilePath() : uri.toString(),
      );
    } catch (e) {
      state = state.copyWith(error: 'Could not load that subtitle file.');
      debugPrint('sub-files-append failed: $e');
      return;
    }

    // Loading without selecting would leave the user to open the picker a
    // second time to see the file they just chose.
    final added = await _awaitNewSubtitleTrack(before);
    if (added != null) {
      await setSubtitleTrack(added);
    } else {
      // mpv rejects a file it cannot parse by simply not adding a track.
      state = state.copyWith(error: 'That subtitle file could not be read.');
    }
  }

  /// Waits for mpv to publish the track [addExternalSubtitle] just appended.
  ///
  /// The track list arrives on a stream, so there is nothing to await
  /// directly. A second is far longer than parsing a subtitle file takes and
  /// short enough that a rejected file reports promptly.
  Future<MediaTrack?> _awaitNewSubtitleTrack(Set<String> before) async {
    const step = Duration(milliseconds: 50);

    for (var waited = Duration.zero;
        waited < const Duration(seconds: 1);
        waited += step) {
      final added = state.subtitleTracks
          .where((t) => !t.isOff && !before.contains(t.id))
          .toList();
      if (added.isNotEmpty) return added.last;
      await Future<void>.delayed(step);
    }
    return null;
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
      hwdec: _hwdec,
    );
  }

  void _teardown() {
    unawaited(_teardownAsync());
  }

  /// Tells a server that playback ended.
  ///
  /// Separate from the throttled progress write because it must happen once
  /// and exactly once: it is what ends the session, and a transcode left
  /// unclosed keeps ffmpeg running on the far end until the server gives up
  /// on it.
  Future<void> _reportStopped() async {
    final media = state.media;
    if (media == null) return;

    final source = ref.read(mediaSourcesProvider)[media.ref.sourceId];
    if (source case final ProgressReporting reporter) {
      await reporter.reportStopped(
        media.ref.itemId,
        position: state.position,
      );
    }
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
    _smartSubtitlesApplied = false;

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
