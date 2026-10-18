// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/foundation.dart';

import '../servers/media_library_source.dart';

import '../core/models/media_models.dart';

/// What a given source can do beyond handing over bytes.
///
/// These flags are how the player decides whether to draw chapter ticks, a
/// "Skip intro" pill, or a transcode indicator. A server supports all of
/// them, which is now the only kind of source there is — the flags stay
/// because the *item* still varies: a server that has never run a detection
/// plugin advertises chapters and supplies none.
@immutable
class SourceCapabilities {
  const SourceCapabilities({
    this.chapters = false,
    this.reportsWatchState = false,
    this.transcoding = false,
    this.externalSubtitles = false,
  });

  /// The source supplies its own chapter list, with intro segments marked.
  ///
  /// False does **not** mean the media has no chapters: MKV and MP4 embed
  /// them, and the player reads those out of the container regardless. This
  /// flag is only about chapters the *source* knows — which is what makes
  /// reliable intro detection possible.
  final bool chapters;

  /// Playback progress is pushed back to a server as well as stored locally.
  final bool reportsWatchState;

  /// The server can re-encode; the player may show "transcoding 1080p"
  /// instead of "direct play" and offer a quality control.
  final bool transcoding;

  /// Sidecar subtitle files can be discovered next to the media.
  final bool externalSubtitles;

}

/// A pointer to an item inside a source, before it has been resolved.
///
/// Cheap and serialisable — this is what a browse listing, a resume record or
/// a search result holds, not [PlayableMedia].
@immutable
class MediaRef {
  const MediaRef({
    required this.sourceId,
    required this.itemId,
    required this.title,
  });

  /// Matches [MediaSourceRef.id].
  final String sourceId;

  /// Opaque to everything but the owning source: a Jellyfin item GUID.
  final String itemId;

  final String title;

  @override
  bool operator ==(Object other) =>
      other is MediaRef &&
      other.sourceId == sourceId &&
      other.itemId == itemId;

  @override
  int get hashCode => Object.hash(sourceId, itemId);
}

/// A named point in the timeline.
///
/// Chapters come from the source, not from the decoder: only a server knows
/// which chapter is an intro, which is what the skip-intro pill keys off.
@immutable
class MediaChapter {
  const MediaChapter({
    required this.title,
    required this.start,
    required this.end,
    this.isIntro = false,
    this.imageUri,
  });

  final String title;
  final Duration start;
  final Duration end;

  /// The still the source generated for this chapter, where it has one.
  ///
  /// Only ever set on a server chapter — a container carries titles and
  /// timestamps and no pictures.
  final Uri? imageUri;

  /// Drives the "Skip intro" pill, which appears only while playback is
  /// inside this chapter.
  final bool isIntro;

  bool contains(Duration position) => position >= start && position < end;
}

/// A resolved handle the player can open right now.
///
/// Resolving is deliberately separate from browsing: a stream URL carries a
/// short-lived token, so it does not survive being cached in a listing.
@immutable
class PlayableMedia {
  const PlayableMedia({
    required this.ref,
    required this.uri,
    required this.kind,
    required this.capabilities,
    required this.sourceLine,
    this.headers = const <String, String>{},
    this.startPosition = Duration.zero,
    this.chapters = const <MediaChapter>[],
    this.serverStreams = const <ServerStream>[],
    this.segments = const <MediaSegment>[],
    this.trickplay,
    this.externalSubtitles = const <ExternalSubtitle>[],
  });

  final MediaRef ref;

  /// What the playback backend opens. Always `http(s)://` now — the only
  /// thing that resolves anything is a media server.
  final Uri uri;

  final SourceKind kind;
  final SourceCapabilities capabilities;

  /// The line under the player's title — "Jellyfin · transcoding 1080p".
  /// The source words this itself.
  final String sourceLine;

  /// Auth headers for HTTP-backed sources.
  final Map<String, String> headers;

  /// Where playback should begin, as the server last recorded it.
  ///
  /// There is no local resume store to reconcile with any more: the server
  /// has been collecting this from every device the user owns, which is
  /// better than anything one device remembers.
  final Duration startPosition;

  /// Empty unless [capabilities] advertises chapters. The scrubber draws a
  /// tick per entry; an empty list simply draws none.
  final List<MediaChapter> chapters;

  /// The tracks as the *server* described them, where one is involved.
  ///
  /// Kept beside the decoder's own list rather than merged into it: after a
  /// transcode the file the decoder opened has one audio track, and only this
  /// list still knows which of the original's the user chose.
  final List<ServerStream> serverStreams;

  /// The stretches a server has labelled — intro, outro, recap, and so on.
  ///
  /// Empty for everything but a server, and empty on a server that has never
  /// had a detection plugin run over the item. What makes "Skip intro" mean
  /// something rather than guess: a chapter named "Intro" is a rip's opinion,
  /// a segment is the server's.
  final List<MediaSegment> segments;

  /// The scrubber preview sheets, where the server generated them.
  final ServerTrickplay? trickplay;

  /// Subtitles the server keeps as files of their own, which the decoder
  /// would otherwise never see.
  final List<ExternalSubtitle> externalSubtitles;

  String get title => ref.title;

  /// The same media, opened somewhere else.
  ///
  /// What "Start over" needs: the resume point comes back from the server
  /// with the item, and the only thing that differs is where playback begins.
  PlayableMedia startingAt(Duration position) => PlayableMedia(
        ref: ref,
        uri: uri,
        kind: kind,
        capabilities: capabilities,
        sourceLine: sourceLine,
        headers: headers,
        startPosition: position,
        chapters: chapters,
        serverStreams: serverStreams,
        segments: segments,
        trickplay: trickplay,
        externalSubtitles: externalSubtitles,
      );

  /// The labelled stretch [position] falls in, or null outside any.
  MediaSegment? segmentAt(Duration position) {
    for (final MediaSegment s in segments) {
      if (s.contains(position)) return s;
    }
    return null;
  }

  /// The chapter [position] falls in, or null outside any.
  MediaChapter? chapterAt(Duration position) {
    for (final MediaChapter c in chapters) {
      if (c.contains(position)) return c;
    }
    return null;
  }
}

/// Raised when a source cannot produce a playable handle.
///
/// Carries a message fit to show the user — a dead share or an expired token
/// must surface as an inline error, never as a crash.
class MediaSourceException implements Exception {
  const MediaSourceException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'MediaSourceException: $message';
}

/// One place media comes from.
///
/// One implementation today, `JellyfinMediaSource`. The player depends on
/// this interface alone and not on Jellyfin, which is what would let an Emby
/// or Plex driver land beside it without the player noticing.
abstract interface class MediaSource {
  /// Matches the `id` of the [MediaSourceRef] this source was configured from.
  String get id;

  SourceKind get kind;

  SourceCapabilities get capabilities;

  /// Turns a reference into something openable. May hit the network.
  ///
  /// Throws [MediaSourceException] when the item cannot be resolved.
  Future<PlayableMedia> resolve(MediaRef ref);
}

/// A source that keeps watch state somewhere other than this device.
///
/// Implemented by servers, and the only place watch state lives now that the
/// local resume store is gone. `PlaybackController` calls it as playback
/// moves, so a film paused on a phone is where you left it on a television —
/// and so a transcode is torn down when playback stops rather than left
/// running until the server times it out.
abstract interface class ProgressReporting {
  Future<void> reportProgress(
    String itemId, {
    required Duration position,
    required bool isPaused,
  });

  Future<void> reportStopped(String itemId, {required Duration position});
}

/// A source that knows what plays *after* an item without a folder to list.
///
/// Servers are the reason this exists: a Jellyfin library has no directory
/// the player could read, so the run of episodes a tap on "Play" belongs to
/// has to be asked for by name. Implementing it is what gives an episode
/// prev/next and "Auto-play next episode"; a source that leaves it out simply
/// plays the one file.
abstract interface class QueueableSource implements MediaSource {
  /// The items belonging beside [mediaRef], in play order, with the index of
  /// [mediaRef] itself.
  ///
  /// Returns an empty list where the item has no run to belong to — a film,
  /// or an episode the server files under no series.
  Future<({List<MediaRef> items, int index})> siblingsOf(MediaRef mediaRef);
}
