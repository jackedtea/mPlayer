// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/foundation.dart';

import '../core/models/media_models.dart';
import '../sources/media_source.dart';
import 'media_library_source.dart';
import 'stream_preferences.dart';

/// A signed-in server, as something the **player** can open.
///
/// The bridge between the two halves of the app: `MediaLibrarySource` hands
/// over catalogue data, and `MediaSource` is what `PlaybackController`
/// resolves against. Registering one of these means the player, the
/// folder queue, resume points and casting all work against a server without
/// knowing that a server is what they are talking to.
class JellyfinMediaSource
    implements MediaSource, QueueableSource, ProgressReporting {
  JellyfinMediaSource(this.library, {StreamPreferences Function()? preferences})
    : _preferences = preferences ?? _none;

  final MediaLibrarySource library;

  /// Read at resolve time rather than captured at construction: the source
  /// map is built once and resolves many times, and a quality picked in the
  /// player has to reach the *next* file without rebuilding the map.
  final StreamPreferences Function() _preferences;

  static StreamPreferences _none() => const StreamPreferences();

  /// The session the server handed out for each item, kept so progress
  /// reports can quote it.
  ///
  /// Without it a report is filed against no session, and a transcode the
  /// user walked away from is never torn down.
  final Map<String, String> _sessions = <String, String>{};

  /// The series each played episode belongs to, remembered from the resolve
  /// that already fetched it.
  ///
  /// Saves the queue a second round trip for the item the player just opened,
  /// which is the only item it ever asks about.
  final Map<String, String> _series = <String, String>{};

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
    // A server extracts its own chapter list, stills and all. Whether a
    // given item has one is a different question, answered by the list
    // coming back empty.
    chapters: true,
    // Subtitles the server keeps beside the video, handed to the player
    // as URLs rather than found on a disk it cannot see.
    externalSubtitles: true,
  );

  @override
  Future<PlayableMedia> resolve(MediaRef ref) async {
    try {
      final item = await library.item(ref.itemId);

      final preferences = _preferences();
      final quality = preferences.quality;
      // Only if it was made for *this* item: the indexes are positions in one
      // file's track list and mean something else in the next.
      final choice = preferences.trackChoice?.itemId == ref.itemId
          ? preferences.trackChoice
          : null;

      // Fetched alongside the playback resolve rather than after it: the
      // call is independent of everything the resolve decides, and waiting
      // for it in series would add a round trip to every press of Play.
      final segmentsFuture = library.segments(ref.itemId);

      final playback = await library.playback(
        ref.itemId,
        PlaybackCapabilities(
          maxBitrate: quality.maxBitrate,
          maxHeight: quality.maxHeight,
        ),
        audioStreamIndex: choice?.audioStreamIndex,
        subtitleStreamIndex: choice?.subtitleStreamIndex,
        mediaSourceId: choice?.mediaSourceId,
      );

      final segments = await segmentsFuture;

      final session = playback.playSessionId;
      if (session != null) _sessions[ref.itemId] = session;

      final series = item.seriesId;
      if (series != null) _series[ref.itemId] = series;

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
        // collecting that from every device, not just this one. A song starts
        // at its start: nobody resumes one, and a queue skipping in halfway
        // through a track reads as a fault.
        startPosition: item.kind == ServerItemKind.audio
            ? Duration.zero
            : item.position ?? Duration.zero,
        sourceLine: _sourceLine(playback),
        // What the server actually produced, so the player can label its
        // quality control with the truth rather than with what was asked for.
        serverStreams: playback.streams,
        chapters: _chaptersOf(item),
        segments: segments,
        trickplay: item.trickplay,
        externalSubtitles: playback.externalSubtitles,
        seriesId: item.seriesId,
        isDirectPlay: playback.isDirectPlay,
        defaultAudioIndex: playback.defaultAudioIndex,
        defaultSubtitleIndex: playback.defaultSubtitleIndex,
        tracksChosen: choice != null,
        isAudio: item.kind == ServerItemKind.audio,
        artist: item.artistLine,
        album: item.album,
        // A track is handed the album's cover when it has none of its own
        // (see `_primaryImageTag`), so this is the album art in practice.
        // Sized for Now playing on a 3x phone; the notification scales down.
        artworkUri: item.kind == ServerItemKind.audio
            ? library.imageUrl(item, maxWidth: 1024)
            : null,
        seriesTitle: item.kind == ServerItemKind.episode
            ? item.seriesTitle
            : null,
        seasonNumber: item.kind == ServerItemKind.episode
            ? item.seasonNumber
            : null,
        episodeNumber: item.kind == ServerItemKind.episode
            ? item.episodeNumber
            : null,
        year: item.year,
        sourceBitrate: playback.bitrate,
      );
    } on ServerException catch (e) {
      // The player renders this inline; it must read as a sentence.
      throw MediaSourceException(e.message);
    }
  }

  /// The other episodes of the series [mediaRef] belongs to, in play order.
  ///
  /// The whole series rather than the season: the episode after a finale is
  /// the next season's opener, and stopping at a season boundary is exactly
  /// the point in a binge where auto-play should not give up.
  ///
  /// A film returns nothing — it has no run to step through, and the player
  /// reads the empty list as "no playlist" rather than as an error.
  @override
  Future<({List<MediaRef> items, int index})> siblingsOf(
    MediaRef mediaRef,
  ) async {
    const ({List<MediaRef> items, int index}) none = (
      items: <MediaRef>[],
      index: 0,
    );

    try {
      final seriesId =
          _series[mediaRef.itemId] ??
          (await library.item(mediaRef.itemId)).seriesId;
      if (seriesId == null) return none;

      final episodes = await library.episodes(seriesId);

      final items = <MediaRef>[
        for (final ServerItem e in episodes)
          MediaRef(sourceId: id, itemId: e.id, title: e.title),
      ];

      // A server that answered with a list the played episode is not in has
      // told us nothing usable; a queue positioned at the wrong index would
      // send "next" to the wrong episode.
      final index = items.indexWhere((m) => m.itemId == mediaRef.itemId);
      if (index < 0) return none;

      return (items: items, index: index);
    } on ServerException catch (e) {
      throw MediaSourceException(e.message);
    }
  }

  @override
  Future<void> reportProgress(
    String itemId, {
    required Duration position,
    required bool isPaused,
    int? audioStreamIndex,
    int? subtitleStreamIndex,
  }) async {
    try {
      await library.reportProgress(
        itemId,
        position: position,
        isPaused: isPaused,
        playSessionId: _sessions[itemId],
        audioStreamIndex: audioStreamIndex,
        subtitleStreamIndex: subtitleStreamIndex,
      );
    } catch (e) {
      // A dropped report costs the server one update. The local resume point
      // is already written, so nothing the user can see is lost.
      debugPrint('Could not report progress: $e');
    }
  }

  @override
  Future<void> reportStopped(
    String itemId, {
    required Duration position,
  }) async {
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

  /// The server's chapter list, with an end derived from the neighbour.
  ///
  /// `isIntro` stays false on every one of them. The player's title
  /// heuristic exists for containers, where a name is the only signal there
  /// is; a server that knows what an intro is says so through
  /// [MediaLibrarySource.segments] instead, and letting a chapter called
  /// "Opening" claim to be one as well would put two pills on the screen.
  List<MediaChapter> _chaptersOf(ServerItem item) {
    final chapters = item.chapters;
    if (chapters.isEmpty) return const <MediaChapter>[];

    // The last chapter runs to the end of the film; with no runtime there is
    // nothing to run to, so it gets its own start and draws as a tick alone.
    final runtime = item.runtime ?? chapters.last.start;

    return <MediaChapter>[
      for (var i = 0; i < chapters.length; i++)
        MediaChapter(
          title: chapters[i].title,
          start: chapters[i].start,
          end: i + 1 < chapters.length ? chapters[i + 1].start : runtime,
          imageUri: library.chapterImageUrl(
            item.id,
            chapters[i],
            // Wide enough for the sheet's thumbnail on a 3x screen, and far
            // short of the full frame the server would otherwise send for
            // every chapter at once.
            maxWidth: 480,
          ),
        ),
    ];
  }

  /// "direct play · 2.1 Mbps" / "transcoding · 8.0 Mbps". The server's name
  /// is left out: the icon beside the line already says where it came from.
  String _sourceLine(ServerPlayback playback) {
    final parts = <String>[
      playback.isDirectPlay ? 'direct play' : 'transcoding',
      if (playback.bitrate != null)
        '${(playback.bitrate! / 1000000).toStringAsFixed(1)} Mbps',
    ];
    return parts.join(' · ');
  }
}
