// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/foundation.dart';

import '../core/models/media_models.dart';
import '../sources/media_source.dart';
import 'media_library_source.dart';

/// A signed-in server, as something the **player** can open.
///
/// The bridge between the two halves of the app: `MediaLibrarySource` hands
/// over catalogue data, and `MediaSource` is what `PlaybackController`
/// resolves against. Registering one of these means the player, the
/// folder queue, resume points and casting all work against a server without
/// knowing that a server is what they are talking to.
class JellyfinMediaSource implements MediaSource, ProgressReporting {
  JellyfinMediaSource(this.library);

  final MediaLibrarySource library;

  /// The session the server handed out for each item, kept so progress
  /// reports can quote it.
  ///
  /// Without it a report is filed against no session, and a transcode the
  /// user walked away from is never torn down.
  final Map<String, String> _sessions = <String, String>{};

  @override
  String get id => library.profile.id;

  @override
  SourceKind get kind => SourceKind.jellyfin;

  @override
  SourceCapabilities get capabilities => const SourceCapabilities(
        // The server decides between handing the file over and re-encoding,
        // which is what makes the quality control mean anything.
        transcoding: true,
        reportsWatchState: true,
      );

  @override
  Future<PlayableMedia> resolve(MediaRef ref) async {
    try {
      final item = await library.item(ref.itemId);
      final playback = await library.playback(
        ref.itemId,
        const PlaybackCapabilities(),
      );

      final session = playback.playSessionId;
      if (session != null) _sessions[ref.itemId] = session;

      return PlayableMedia(
        ref: MediaRef(
          sourceId: id,
          itemId: ref.itemId,
          // The listing may have handed over a bare id; the server's own
          // title is better than whatever the caller guessed.
          title: item.title.isEmpty ? ref.title : item.title,
        ),
        uri: playback.uri,
        kind: kind,
        capabilities: capabilities,
        headers: playback.headers,
        // The server is the authority on where the user got to: it has been
        // collecting that from every device, not just this one.
        startPosition: item.position ?? Duration.zero,
        sourceLine: _sourceLine(playback),
      );
    } on ServerException catch (e) {
      // The player renders this inline; it must read as a sentence.
      throw MediaSourceException(e.message);
    }
  }

  @override
  Future<void> reportProgress(
    String itemId, {
    required Duration position,
    required bool isPaused,
  }) async {
    try {
      await library.reportProgress(
        itemId,
        position: position,
        isPaused: isPaused,
        playSessionId: _sessions[itemId],
      );
    } catch (e) {
      // A dropped report costs the server one update. The local resume point
      // is already written, so nothing the user can see is lost.
      debugPrint('Could not report progress: $e');
    }
  }

  @override
  Future<void> reportStopped(String itemId, {required Duration position}) async {
    try {
      await library.reportStopped(
        itemId,
        position: position,
        playSessionId: _sessions.remove(itemId),
      );
    } catch (e) {
      debugPrint('Could not report the stop: $e');
    }
  }

  /// "Jellyfin · direct play" / "Jellyfin · transcoding · 8.0 Mbps".
  String _sourceLine(ServerPlayback playback) {
    final parts = <String>[
      library.profile.kind.label,
      playback.isDirectPlay ? 'direct play' : 'transcoding',
      if (playback.bitrate != null)
        '${(playback.bitrate! / 1000000).toStringAsFixed(1)} Mbps',
    ];
    return parts.join(' · ');
  }
}
