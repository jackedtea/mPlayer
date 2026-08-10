// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/foundation.dart';

import '../core/models/media_models.dart';

/// What a given source can do beyond handing over bytes.
///
/// The player screen is the same for every source; these flags are how it
/// decides whether to draw chapter ticks, a "Skip intro" pill, or a transcode
/// indicator. A local file supports none of them, Jellyfin supports all.
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

  static const local = SourceCapabilities(externalSubtitles: true);
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

  /// Opaque to everything but the owning source: a file path, an SMB path, a
  /// Jellyfin item GUID.
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
  });

  final String title;
  final Duration start;
  final Duration end;

  /// Drives the "Skip intro" pill, which appears only while playback is
  /// inside this chapter.
  final bool isIntro;

  bool contains(Duration position) => position >= start && position < end;
}

/// A resolved handle the player can open right now.
///
/// Resolving is deliberately separate from browsing: a Jellyfin stream URL
/// carries a short-lived token, and an SMB path may need a mounted session, so
/// neither survives being cached in a listing.
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
  });

  final MediaRef ref;

  /// What the playback backend opens. `file://` for local, `smb://`,
  /// `http(s)://` for WebDAV and server streams.
  final Uri uri;

  final SourceKind kind;
  final SourceCapabilities capabilities;

  /// The line under the player's title — "NAS · SMB · direct play · 18.4 Mbps"
  /// or "Jellyfin · transcoding 1080p". Each source words this itself.
  final String sourceLine;

  /// Auth headers for HTTP-backed sources.
  final Map<String, String> headers;

  /// Where playback should begin, from the local resume point reconciled with
  /// the server's.
  final Duration startPosition;

  /// Empty unless [capabilities] advertises chapters. The scrubber draws a
  /// tick per entry; an empty list simply draws none.
  final List<MediaChapter> chapters;

  String get title => ref.title;

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
/// Implementations: local files, SMB, WebDAV, NFS, and Jellyfin/Emby streams.
/// The player depends on this interface alone, which is what keeps a single
/// player screen serving all of them.
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
