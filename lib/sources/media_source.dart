// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/foundation.dart';

import '../core/models/library_models.dart';
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

/// A source that is a filesystem: device storage, SMB, WebDAV, NFS.
///
/// Kept separate from [MediaSource] because a Jellyfin library is browsed by
/// collection and id, not by path — the browser screen (1b) only ever talks to
/// this interface.
/// A source whose item ids describe a *route* rather than a file.
///
/// SAF is the reason this exists: its ids carry the folder they were reached
/// through, so the same document browsed from two places yields two ids — and
/// anything keyed on the id, the Continue-watching shelf most of all, then
/// holds the same film twice with two different positions.
abstract interface class StableItemId {
  /// The same file always yields the same value, whatever route reached it.
  String stableItemId(String itemId);
}

/// The identity to file [itemId] under.
///
/// Falls back to the id itself, which is already stable for every source that
/// does not implement [StableItemId].
String stableIdFor(MediaSource? source, String itemId) {
  if (source case final StableItemId stable) return stable.stableItemId(itemId);
  return itemId;
}

/// A source that keeps watch state somewhere other than this device.
///
/// Implemented by servers. `PlaybackController` calls it alongside the local
/// resume write, so a film paused on a phone is where you left it on a
/// television — and so a transcode is torn down when playback stops rather
/// than left running until the server times it out.
abstract interface class ProgressReporting {
  Future<void> reportProgress(
    String itemId, {
    required Duration position,
    required bool isPaused,
  });

  Future<void> reportStopped(String itemId, {required Duration position});
}

abstract interface class BrowsableSource implements MediaSource {
  /// Path shown as the breadcrumb root, e.g. `smb://nas/media`.
  String get rootLabel;

  /// Lists one directory. Pass an empty path for the share root.
  ///
  /// Throws [MediaSourceException] when the directory cannot be read — an
  /// unreachable share must surface inline, never as a crash.
  Future<BrowseListing> listDirectory(String path);

  /// The directory holding [path].
  ///
  /// Each driver answers for its own path style: local paths use the
  /// platform separator, a WebDAV href is always POSIX. Getting this wrong
  /// silently produces an empty playlist rather than an error.
  String parentOf(String path);
}

/// The videos beside [mediaRef], in the order a file manager would show them,
/// with the index of [mediaRef] itself.
///
/// This is what makes prev/next work after opening a single file: the folder
/// it came from *is* the playlist.
Future<({List<MediaRef> items, int index})> siblingVideosOf(
  BrowsableSource source,
  MediaRef mediaRef,
) async {
  final parent = source.parentOf(mediaRef.itemId);
  final listing = await source.listDirectory(parent);

  final videos = listing.entries.where((e) => e.isPlayable).toList();

  final items = <MediaRef>[
    for (final BrowseEntry e in videos)
      MediaRef(sourceId: source.id, itemId: e.path, title: e.name),
  ];

  // The opened file may not be in the listing — a picker can hand over a file
  // from a directory the driver cannot list, and on Android it hands over a
  // copy in the cache. Falling back to a single-item queue keeps playback
  // working instead of failing to find an index.
  final index = items.indexWhere((m) => m.itemId == mediaRef.itemId);
  if (index < 0) {
    return (items: <MediaRef>[mediaRef], index: 0);
  }

  return (items: items, index: index);
}

/// Extensions the browser treats as playable video.
///
/// Not a whitelist for playback: [MediaSource.resolve] hands anything to the
/// backend and lets it decide. This only drives which icon a row gets.
const videoFileExtensions = <String>{
  'mp4', 'mkv', 'mov', 'avi', 'webm', 'm4v', 'ts', 'm2ts', 'mpg', 'mpeg',
  'wmv', 'flv', '3gp', 'ogv', 'rmvb', 'vob', 'mts', 'divx',
};

const subtitleFileExtensions = <String>{
  'srt', 'ass', 'ssa', 'sub', 'vtt', 'idx', 'sup',
};

/// Classifies a filename for the browser listing.
BrowseEntryKind classifyFile(String name) {
  final dot = name.lastIndexOf('.');
  if (dot < 0 || dot == name.length - 1) return BrowseEntryKind.other;
  final ext = name.substring(dot + 1).toLowerCase();

  if (videoFileExtensions.contains(ext)) return BrowseEntryKind.video;
  if (subtitleFileExtensions.contains(ext)) return BrowseEntryKind.subtitle;
  return BrowseEntryKind.other;
}
