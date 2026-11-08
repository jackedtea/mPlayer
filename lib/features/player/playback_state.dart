// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:math' show Random;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../servers/media_library_source.dart';
import '../../sources/media_source.dart';

/// How many times each item's stop has reached its server, this launch.
///
/// What an item's cached details listen to: a stop is when the server's resume
/// position changes, and nothing else on the way out of the player says so.
final playbackStopsProvider =
    NotifierProvider<PlaybackStops, Map<String, int>>(PlaybackStops.new);

class PlaybackStops extends Notifier<Map<String, int>> {
  @override
  Map<String, int> build() => const <String, int>{};

  void record(String itemId) {
    state = <String, int>{...state, itemId: (state[itemId] ?? 0) + 1};
  }
}

/// What a [PlaybackQueue] is a run of, which decides how it ends and what the
/// player promises about what comes next.
enum PlaybackQueueKind {
  /// Videos with nothing more in common: a playlist, a shuffled series.
  single,

  /// The episodes of one series. Only this may say "Next episode": it is a
  /// promise about what comes next, and a run of unrelated films must not
  /// make it.
  series,

  /// Songs. A record plays through whatever the auto-play setting says, which
  /// is about binging episodes, and nothing offers a way past its credits.
  music,
}

/// What plays after what, as an explicit list.
///
/// Immutable like the rest of [PlaybackState]: every change below returns a
/// new queue. They answer with this same queue where there is nothing to do,
/// so a stale index from a list on screen costs nothing.
@immutable
class PlaybackQueue {
  const PlaybackQueue({
    this.items = const <MediaRef>[],
    this.index = 0,
    this.kind = PlaybackQueueKind.single,
    this.unshuffled,
  });

  /// [items] dealt in a random order, starting at the top of the deal.
  ///
  /// For a Shuffle button, where the first song should be a surprise too.
  /// [shuffled] is the other one, for a queue already playing.
  factory PlaybackQueue.shuffledFrom(
    List<MediaRef> items, {
    PlaybackQueueKind kind = PlaybackQueueKind.single,
    Random? random,
  }) {
    return PlaybackQueue(
      items: List<MediaRef>.of(items)..shuffle(random),
      kind: kind,
      unshuffled: List<MediaRef>.of(items),
    );
  }

  final List<MediaRef> items;
  final int index;
  final PlaybackQueueKind kind;

  /// The order to go back to when shuffle is turned off. Null while it is off.
  final List<MediaRef>? unshuffled;

  bool get isShuffled => unshuffled != null;

  bool get isSeries => kind == PlaybackQueueKind.series;
  bool get isMusic => kind == PlaybackQueueKind.music;

  bool get isEmpty => items.isEmpty;

  /// A folder holding one video is not a playlist worth showing controls for.
  bool get hasSiblings => items.length > 1;

  bool get hasPrevious => index > 0;
  bool get hasNext => index >= 0 && index < items.length - 1;

  MediaRef? get current =>
      (index >= 0 && index < items.length) ? items[index] : null;

  /// Whether the end of the current file starts the next by itself.
  ///
  /// [autoPlay] is the "Auto-play next episode" setting. Music does not ask
  /// it: turning off a binge must not stop an album after its first song.
  bool rollsOn({required bool autoPlay}) => hasNext && (autoPlay || isMusic);

  PlaybackQueue? stepTo(int next) {
    if (next < 0 || next >= items.length) return null;
    return _with(index: next);
  }

  /// [ref] straight after the current item.
  PlaybackQueue playingNext(MediaRef ref) {
    final at = isEmpty ? 0 : index + 1;
    final original = unshuffled;
    return _with(
      items: <MediaRef>[...items]..insert(at, ref),
      unshuffled: original == null
          ? null
          // After the current item there too, or turning shuffle off would
          // send a song that was promised next to wherever it fell.
          : (<MediaRef>[...original]
              ..insert(current == null ? 0 : original.indexOf(current!) + 1, ref)),
    );
  }

  /// [ref] at the very end.
  PlaybackQueue appended(MediaRef ref) {
    final original = unshuffled;
    return _with(
      items: <MediaRef>[...items, ref],
      unshuffled: original == null ? null : <MediaRef>[...original, ref],
    );
  }

  /// The item at [from] moved so that it ends up at [to], with the current
  /// item still current wherever it now sits.
  PlaybackQueue moved(int from, int to) {
    if (from == to ||
        from < 0 ||
        to < 0 ||
        from >= items.length ||
        to >= items.length) {
      return this;
    }

    final next = <MediaRef>[...items];
    next.insert(to, next.removeAt(from));

    var nextIndex = index;
    if (from == index) {
      nextIndex = to;
    } else if (from < index && to >= index) {
      nextIndex = index - 1;
    } else if (from > index && to <= index) {
      nextIndex = index + 1;
    }

    return _with(items: next, index: nextIndex);
  }

  /// The queue without the item at [at]. The current item stays: what is
  /// playing is stopped or stepped past, not deleted out from under the
  /// decoder.
  PlaybackQueue removedAt(int at) {
    if (at < 0 || at >= items.length || at == index) return this;

    final removed = items[at];
    final original = unshuffled;
    return _with(
      items: <MediaRef>[...items]..removeAt(at),
      index: at < index ? index - 1 : index,
      unshuffled: original == null
          ? null
          : (<MediaRef>[...original]..remove(removed)),
    );
  }

  /// Everything but what is playing.
  PlaybackQueue clearedUpcoming() {
    final playing = current;
    if (playing == null || items.length <= 1) return this;
    return PlaybackQueue(items: <MediaRef>[playing], kind: kind);
  }

  /// The rest of the queue in a random order, with the current item first so
  /// that turning shuffle on does not interrupt it.
  PlaybackQueue shuffled([Random? random]) {
    final playing = current;
    if (playing == null) return this;

    final rest = <MediaRef>[...items]..removeAt(index);
    rest.shuffle(random);
    return _with(
      items: <MediaRef>[playing, ...rest],
      index: 0,
      unshuffled: unshuffled ?? items,
    );
  }

  /// Back to the order before [shuffled], still on the same item.
  PlaybackQueue inOriginalOrder() {
    final original = unshuffled;
    if (original == null) return this;

    final found = current == null ? -1 : original.indexOf(current!);
    return PlaybackQueue(
      items: original,
      index: found < 0 ? 0 : found,
      kind: kind,
    );
  }

  /// [unshuffled] is passed as it stands by the changes that alter it, and
  /// kept by the one that does not name it: a step or a reorder must not lose
  /// the way back.
  PlaybackQueue _with({
    List<MediaRef>? items,
    int? index,
    List<MediaRef>? unshuffled,
  }) {
    return PlaybackQueue(
      items: items ?? this.items,
      index: index ?? this.index,
      kind: kind,
      unshuffled: unshuffled ?? this.unshuffled,
    );
  }

  /// Human position, e.g. "3 of 10".
  String get position => '${index + 1} of ${items.length}';
}

/// Which stream a [MediaTrack] belongs to.
enum TrackKind { video, audio, subtitle }

/// A selectable stream inside the media, flattened out of the backend's own
/// track type so the sheets and the control row never see `media_kit`.
@immutable
class MediaTrack {
  const MediaTrack({
    required this.id,
    required this.kind,
    required this.label,
    this.language,
    this.isDefault = false,
    this.codec,
  });

  final String id;
  final TrackKind kind;

  /// What the pill and the sheet show — "English SDH", "TrueHD 7.1".
  final String label;

  final String? language;
  final bool isDefault;

  /// Demuxer codec name, e.g. `hdmv_pgs_subtitle`, `ass`, `subrip`.
  final String? codec;

  /// media_kit exposes "no track" and "auto" as reserved ids.
  bool get isOff => id == 'no';
  bool get isAuto => id == 'auto';

  /// Bitmap subtitles — PGS (Blu-ray), VobSub (DVD), DVB and XSUB.
  ///
  /// These are pictures, not text, so libass never touches them: mpv has to
  /// composite them into the video frame. media_kit's render path does not,
  /// so selecting one currently shows nothing at all
  /// (media-kit/media-kit#1371). The picker uses this to say so rather than
  /// letting the choice fail in silence.
  bool get isImageBased {
    final c = codec?.toLowerCase();
    if (c == null) return false;
    return c.contains('pgs') ||
        c.contains('hdmv') ||
        c == 'dvd_subtitle' ||
        c == 'dvb_subtitle' ||
        c == 'dvbsub' ||
        c == 'xsub' ||
        c == 'vobsub';
  }
}

/// What happens when the file being played reaches its end.
///
/// `all` only means something where the file was opened from a folder holding
/// others: it is the queue that is repeated, not the file. The control skips
/// straight back to `off` for a lone video rather than offering a mode that
/// would behave identically to `one`.
enum LoopMode {
  off,
  one,
  all;

  /// The next mode the loop control cycles to.
  ///
  /// [hasSiblings] is the queue's, not a preference: repeating a folder of one
  /// is repeating the file, and two buttons that do the same thing is one
  /// button too many.
  LoopMode next({required bool hasSiblings}) => switch (this) {
        LoopMode.off => LoopMode.one,
        LoopMode.one => hasSiblings ? LoopMode.all : LoopMode.off,
        LoopMode.all => LoopMode.off,
      };
}

/// Everything the stats overlay reports. All fields are optional because a
/// stream reveals them at different times, and a missing value must render as
/// "—" rather than a zero that looks real.
@immutable
class PlaybackStats {
  const PlaybackStats({
    this.width,
    this.height,
    this.videoCodec,
    this.videoDecoder,
    this.fps,
    this.videoBitrate,
    this.audioCodec,
    this.audioChannels,
    this.audioSampleRate,
    this.hwdec,
    this.audioBitrate,
  });

  final int? width;
  final int? height;
  final String? videoCodec;

  /// Includes whether the decoder is hardware or software.
  final String? videoDecoder;

  final double? fps;
  final int? videoBitrate;
  final String? audioCodec;
  final String? audioChannels;
  final int? audioSampleRate;
  final double? audioBitrate;

  /// libmpv's `hwdec-current` — the API that is decoding *right now*, e.g.
  /// `d3d11va-copy`, `mediacodec`, or the literal `no` for software.
  ///
  /// This is the answer to the only question the decoder setting raises:
  /// asking for hardware is not the same as getting it, and mpv falls back to
  /// software silently whenever the GPU cannot take a codec. Null until the
  /// property has been read, or on a backend without the mpv property
  /// interface at all.
  final String? hwdec;

  /// Whether the picture is coming off the GPU.
  ///
  /// [hwdec] answers this outright when it has been read. The decoder
  /// description is only a fallback for the moment before that, and it is a
  /// guess: it names the codec implementation, which mentions the hardware
  /// API on some platforms and not others.
  bool get isHardwareDecoded {
    final current = hwdec;
    if (current != null) return current != 'no' && current.isNotEmpty;

    final d = videoDecoder?.toLowerCase();
    if (d == null) return false;
    return d.contains('d3d') ||
        d.contains('dxva') ||
        d.contains('vaapi') ||
        d.contains('videotoolbox') ||
        d.contains('mediacodec') ||
        d.contains('nvdec') ||
        d.contains('cuda') ||
        d.contains('vulkan');
  }
}

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
    this.audioTracks = const <MediaTrack>[],
    this.subtitleTracks = const <MediaTrack>[],
    this.activeAudio,
    this.activeSubtitle,
    this.stats = const PlaybackStats(),
    this.containerChapters = const <MediaChapter>[],
    this.logLines = const <String>[],
    this.queue = const PlaybackQueue(),
    this.loop = LoopMode.off,
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

  final List<MediaTrack> audioTracks;
  final List<MediaTrack> subtitleTracks;
  final MediaTrack? activeAudio;
  final MediaTrack? activeSubtitle;

  final PlaybackStats stats;

  /// Chapters read out of the container by the decoder — MKV and MP4 commonly
  /// embed them, so a plain local file is not chapterless.
  final List<MediaChapter> containerChapters;

  /// Recent warnings and errors straight from libmpv, newest last and capped
  /// at [logLimit].
  ///
  /// Surfaced in the stats overlay because a subtitle or codec that fails to
  /// load says so here and nowhere else — "Could not find subtitle decoder
  /// for format 'hdmv_pgs_subtitle'" is a very different problem from a
  /// decoder that loads and then renders nothing.
  final List<String> logLines;

  static const logLimit = 20;

  /// The folder the current file came from; empty when opened standalone.
  final PlaybackQueue queue;

  /// Whether the file, or the folder it came from, plays again at the end.
  ///
  /// Playback state rather than chrome state: it is a property pushed into
  /// libmpv and it outlives the controls being tapped away.
  final LoopMode loop;

  bool get hasMedia => media != null;

  /// Source chapters win when present: a server marks which chapter is an
  /// intro, which the container cannot say for certain. Otherwise fall back to
  /// whatever the file itself carries.
  List<MediaChapter> get chapters {
    final fromSource = media?.chapters ?? const <MediaChapter>[];
    return fromSource.isNotEmpty ? fromSource : containerChapters;
  }

  MediaChapter? chapterAt(Duration at) {
    for (final MediaChapter c in chapters) {
      if (c.contains(at)) return c;
    }
    return null;
  }

  /// How far into a chapter "previous" still means its own start, as every
  /// player and CD deck has it: a press right after a chapter began goes back
  /// one; a press further in starts this one again.
  static const chapterRestartWindow = Duration(seconds: 3);

  List<MediaChapter> get _chaptersInOrder =>
      List<MediaChapter>.of(chapters)
        ..sort((a, b) => a.start.compareTo(b.start));

  /// Where "previous chapter" goes from [position], or null with fewer than
  /// two chapters to move between.
  Duration? previousChapterStart([Duration? from]) {
    final ordered = _chaptersInOrder;
    if (ordered.length < 2) return null;
    final at = from ?? position;

    final current = ordered.lastIndexWhere((c) => c.start <= at);
    if (current < 0) return Duration.zero;
    if (at - ordered[current].start > chapterRestartWindow || current == 0) {
      return ordered[current].start;
    }
    return ordered[current - 1].start;
  }

  /// Where "next chapter" goes from [position], or null in the last one.
  Duration? nextChapterStart([Duration? from]) {
    final ordered = _chaptersInOrder;
    if (ordered.length < 2) return null;
    final at = from ?? position;

    for (final MediaChapter c in ordered) {
      if (c.start > at) return c.start;
    }
    return null;
  }

  /// What the source says about this file, stretch by stretch.
  ///
  /// Empty for a local file, an SMB share and any server that has never had a
  /// segment plugin run over the item.
  List<MediaSegment> get segments => media?.segments ?? const <MediaSegment>[];

  /// The labelled stretch playing right now, if any.
  MediaSegment? get currentSegment {
    for (final MediaSegment s in segments) {
      if (s.contains(position)) return s;
    }
    return null;
  }

  /// The intro chapter currently playing, if any — the skip pill's trigger.
  ///
  /// Stands down entirely once the source supplies segments. A title
  /// heuristic and a server's own answer are two opinions about the same
  /// question, and letting both speak puts two pills on the screen.
  MediaChapter? get currentIntro {
    if (segments.isNotEmpty) return null;
    final chapter = chapterAt(position);
    return chapter != null && chapter.isIntro ? chapter : null;
  }

  /// Guards against a zero duration while the file is still being probed.
  double get progress {
    if (duration.inMilliseconds <= 0) return 0;
    return (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }

  Duration get remaining {
    final left = duration - position;
    return left.isNegative ? Duration.zero : left;
  }

  /// How close to the end the prompt for the next episode appears.
  ///
  /// Long enough to be read and pressed over the closing titles, short enough
  /// that it is not sitting on the picture through a scene the viewer is
  /// still watching.
  static const nextUpWindow = Duration(seconds: 15);

  /// Whether the "Next episode" prompt belongs on screen.
  ///
  /// Held off until a duration is known: at the moment a file opens, position
  /// and duration are both zero, and a prompt that flashes up before the
  /// episode has started reads as a bug. Shown whatever the auto-play setting
  /// says — it is how a viewer leaves the credits early, not a substitute for
  /// the roll-on.
  ///
  /// Not for music: the next song starts by itself in a moment, and a song
  /// has no credits to leave early.
  bool get nextUpDue =>
      !queue.isMusic &&
      queue.hasNext &&
      duration > Duration.zero &&
      remaining <= nextUpWindow;

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
    List<MediaTrack>? audioTracks,
    List<MediaTrack>? subtitleTracks,
    MediaTrack? activeAudio,
    MediaTrack? activeSubtitle,
    PlaybackStats? stats,
    List<MediaChapter>? containerChapters,
    List<String>? logLines,
    PlaybackQueue? queue,
    LoopMode? loop,
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
      audioTracks: audioTracks ?? this.audioTracks,
      subtitleTracks: subtitleTracks ?? this.subtitleTracks,
      activeAudio: activeAudio ?? this.activeAudio,
      activeSubtitle: activeSubtitle ?? this.activeSubtitle,
      stats: stats ?? this.stats,
      containerChapters: containerChapters ?? this.containerChapters,
      logLines: logLines ?? this.logLines,
      queue: queue ?? this.queue,
      loop: loop ?? this.loop,
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

/// What `/player` is handed when the caller assembled the queue itself.
///
/// A shuffled series or a playlist is not something the player can work out
/// from the file's neighbours, so it travels with the resolved item rather
/// than being rediscovered.
@immutable
class PlayerLaunch {
  const PlayerLaunch({required this.media, this.queue});

  final PlayableMedia media;
  final PlaybackQueue? queue;
}
