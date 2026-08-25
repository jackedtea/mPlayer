// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/foundation.dart';

import '../../sources/media_source.dart';

/// The folder a file was opened from, as a playlist.
///
/// Opening one video from a file manager should let the user step through the
/// rest of that folder, which is what every other video player does.
@immutable
class PlaybackQueue {
  const PlaybackQueue({this.items = const <MediaRef>[], this.index = 0});

  final List<MediaRef> items;
  final int index;

  bool get isEmpty => items.isEmpty;

  /// A folder holding one video is not a playlist worth showing controls for.
  bool get hasSiblings => items.length > 1;

  bool get hasPrevious => index > 0;
  bool get hasNext => index >= 0 && index < items.length - 1;

  MediaRef? get current =>
      (index >= 0 && index < items.length) ? items[index] : null;

  PlaybackQueue? stepTo(int next) {
    if (next < 0 || next >= items.length) return null;
    return PlaybackQueue(items: items, index: next);
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

  /// True when the decoder description mentions a hardware pipeline.
  bool get isHardwareDecoded {
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

  /// The intro chapter currently playing, if any — the skip pill's trigger.
  MediaChapter? get currentIntro {
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
