// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../core/models/media_models.dart';
import '../servers/jellyfin_media_source.dart';
import '../servers/media_library_source.dart';
import '../sources/media_source.dart';
import 'download_models.dart';
import 'downloads_controller.dart';
import 'offline_meta.dart';

/// One profile's media, played from the device where a copy is whole and
/// streamed from the server otherwise.
///
/// What `mediaSourcesProvider` holds for every profile: wrapped around the
/// live server source when that profile is signed in, alone when it is not
/// and has copies. The player sees one `MediaSource` either way and never
/// learns which it got — the rule that one player serves every source,
/// one level down.
///
/// Watch state still goes to the server, which stays the only place it
/// lives. A local play reports without a play session (there is no stream
/// to tear down), and a stop the server cannot hear — no session, or no
/// network — is kept by [DownloadsController.recordUnreported] and handed
/// over at the next sign-in.
class OfflineMediaSource
    implements MediaSource, QueueableSource, ProgressReporting {
  OfflineMediaSource({
    required this.profileId,
    required this.downloads,
    this.online,
    this.serverTimeout = const Duration(seconds: 4),
  });

  final String profileId;
  final DownloadsController downloads;

  /// The server, when this profile is signed in.
  final JellyfinMediaSource? online;

  /// How long a local play waits for the server's resume point before
  /// settling for the one it has. A copy exists for the moments the server
  /// is slow or gone; a long wait for it would defeat the point.
  final Duration serverTimeout;

  /// Items resolved to a file on this device, whose reports are handled
  /// here rather than by [online].
  final Set<String> _local = <String>{};

  @override
  String get id => profileId;

  @override
  SourceKind get kind => SourceKind.jellyfin;

  @override
  SourceCapabilities get capabilities =>
      online?.capabilities ??
      const SourceCapabilities(
        chapters: true,
        reportsWatchState: true,
        externalSubtitles: true,
      );

  MediaLibrarySource? get _library => online?.library;

  DownloadEntry? _copyOf(String itemId) {
    final key = DownloadEntry.keyOf(profileId, itemId);
    for (final DownloadEntry e in downloads.entries) {
      if (e.key == key && e.status == DownloadStatus.completed) return e;
    }
    return null;
  }

  @override
  Future<PlayableMedia> resolve(MediaRef ref) async {
    final entry = _copyOf(ref.itemId);
    final store = downloads.store;
    final file = entry == null ? null : store?.mediaFile(entry);

    if (entry == null || store == null || file == null || !file.existsSync()) {
      final server = online;
      if (server == null) {
        throw const MediaSourceException(
          'This is not downloaded, and its server is not signed in.',
        );
      }
      return server.resolve(ref);
    }

    final meta = await store.readMeta(entry) ?? const OfflineMeta();
    _local.add(ref.itemId);

    return PlayableMedia(
      ref: MediaRef(sourceId: profileId, itemId: entry.itemId, title: entry.title),
      uri: Uri.file(file.path),
      kind: kind,
      capabilities: const SourceCapabilities(
        chapters: true,
        reportsWatchState: true,
        externalSubtitles: true,
      ),
      sourceLine: 'Downloaded · original',
      startPosition: entry.kind == ServerItemKind.audio
          ? Duration.zero
          : await _startOf(entry, meta),
      chapters: chaptersOf(meta, runtime: meta.runtime ?? entry.runtime),
      serverStreams: meta.streams,
      segments: meta.segments,
      externalSubtitles: <ExternalSubtitle>[
        for (final OfflineSubtitle s in meta.subtitles)
          if (store.subtitleFile(entry, s.fileName) case final File f
              when f.existsSync())
            ExternalSubtitle(
              uri: Uri.file(f.path),
              label: s.label,
              language: s.language,
              index: s.index,
            ),
      ],
      seriesId: entry.seriesId,
      // The file on disk is the server's original, so the decoder's track
      // list lines up with [serverStreams] exactly as a direct play does.
      isDirectPlay: true,
      defaultAudioIndex: meta.defaultAudioIndex,
      defaultSubtitleIndex: meta.defaultSubtitleIndex,
      // Artist and cover wait for music downloads (MUSIC_PLAN M3); what the
      // player needs now is to know a downloaded song is not a film.
      isAudio: entry.kind == ServerItemKind.audio,
    );
  }

  /// The server's resume point if it answers in time, else the last stop
  /// played here and not yet reported, else the one saved with the copy.
  Future<Duration> _startOf(DownloadEntry entry, OfflineMeta meta) async {
    final library = _library;
    if (library != null) {
      try {
        final item = await library.item(entry.itemId).timeout(serverTimeout);
        // A newer stop kept on this device wins over what the server has
        // not heard about yet.
        return downloads.unreportedPosition(profileId, entry.itemId) ??
            item.position ??
            Duration.zero;
      } catch (e) {
        debugPrint('Playing ${entry.itemId} without the server: $e');
      }
    }
    return downloads.unreportedPosition(profileId, entry.itemId) ??
        meta.position ??
        Duration.zero;
  }

  /// The server's run of episodes when it answers; otherwise the episodes
  /// of the same series that are on the device, in airing order.
  @override
  Future<({List<MediaRef> items, int index})> siblingsOf(
    MediaRef mediaRef,
  ) async {
    final server = online;
    if (server != null) {
      try {
        return await server.siblingsOf(mediaRef);
      } on MediaSourceException catch (e) {
        debugPrint('Queueing from the downloads instead: ${e.message}');
      }
    }

    const ({List<MediaRef> items, int index}) none = (
      items: <MediaRef>[],
      index: 0,
    );
    final seriesId = _copyOf(mediaRef.itemId)?.seriesId;
    if (seriesId == null) return none;

    final episodes = <DownloadEntry>[
      for (final DownloadEntry e in downloads.entries)
        if (e.profileId == profileId &&
            e.seriesId == seriesId &&
            e.status == DownloadStatus.completed)
          e,
    ]..sort((a, b) {
        final season = (a.seasonNumber ?? 0).compareTo(b.seasonNumber ?? 0);
        return season != 0
            ? season
            : (a.episodeNumber ?? 0).compareTo(b.episodeNumber ?? 0);
      });

    final items = <MediaRef>[
      for (final DownloadEntry e in episodes)
        MediaRef(sourceId: profileId, itemId: e.itemId, title: e.title),
    ];
    final index = items.indexWhere((m) => m.itemId == mediaRef.itemId);
    return index < 0 ? none : (items: items, index: index);
  }

  @override
  Future<void> reportProgress(
    String itemId, {
    required Duration position,
    required bool isPaused,
    int? audioStreamIndex,
    int? subtitleStreamIndex,
  }) async {
    if (!_local.contains(itemId)) {
      await online?.reportProgress(
        itemId,
        position: position,
        isPaused: isPaused,
        audioStreamIndex: audioStreamIndex,
        subtitleStreamIndex: subtitleStreamIndex,
      );
      return;
    }

    // A dropped progress report costs nothing: the stop carries the
    // position that matters, and is kept if it cannot be delivered.
    try {
      await _library?.reportProgress(
        itemId,
        position: position,
        isPaused: isPaused,
        audioStreamIndex: audioStreamIndex,
        subtitleStreamIndex: subtitleStreamIndex,
      );
    } catch (_) {}
  }

  @override
  Future<void> reportStopped(String itemId, {required Duration position}) async {
    if (!_local.contains(itemId)) {
      await online?.reportStopped(itemId, position: position);
      return;
    }

    await _deliverStop(itemId, position);
    // After the report, so the server has heard about the watch before the
    // copy that carried it is gone.
    await downloads.watchedTo(profileId, itemId, position);
  }

  Future<void> _deliverStop(String itemId, Duration position) async {
    final library = _library;
    if (library != null) {
      try {
        await library.reportStopped(itemId, position: position);
        return;
      } catch (e) {
        debugPrint('Keeping an offline stop for later: $e');
      }
    }
    await downloads.recordUnreported(profileId, itemId, position);
  }
}

/// The saved chapters with an end each, taken from the next one's start —
/// the last runs to [runtime], or stands as a tick alone without one.
@visibleForTesting
List<MediaChapter> chaptersOf(OfflineMeta meta, {Duration? runtime}) {
  final chapters = meta.chapters;
  if (chapters.isEmpty) return const <MediaChapter>[];
  final end = runtime ?? chapters.last.start;

  return <MediaChapter>[
    for (var i = 0; i < chapters.length; i++)
      MediaChapter(
        title: chapters[i].title,
        start: chapters[i].start,
        end: i + 1 < chapters.length ? chapters[i + 1].start : end,
      ),
  ];
}
