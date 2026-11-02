// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../servers/media_library_source.dart';
import 'download_engine.dart';
import 'download_models.dart';
import 'download_store.dart';
import 'offline_meta.dart';

/// Asks the server everything the player will want about [entry] and saves
/// it beside the file, with any external subtitles fetched alongside.
///
/// Taken before the bytes, while the server is certainly there. The
/// playback question is asked with no device profile — the same "I can play
/// anything" that makes the server answer with the original file — so the
/// track indexes it returns are the file on disk's own.
///
/// Best effort: a server that will not answer leaves the copy without a
/// `meta.json`, and the copy still plays.
Future<void> takeOfflineSnapshot(
  MediaLibrarySource source,
  DownloadEntry entry, {
  required DownloadStore store,
  required DownloadEngine engine,
}) async {
  try {
    final item = await source.item(entry.itemId);
    final segments = await source.segments(entry.itemId);
    final playback =
        await source.playback(entry.itemId, const PlaybackCapabilities());

    final subtitles = <OfflineSubtitle>[];
    for (final (int i, ExternalSubtitle s) in playback.externalSubtitles.indexed) {
      final ext = p.extension(s.uri.path).toLowerCase();
      final name = 'sub-${s.index ?? i}${ext.isEmpty ? '.srt' : ext}';
      if (await engine.fetchFile(s.uri, store.subtitleFile(entry, name))) {
        subtitles.add(
          OfflineSubtitle(
            fileName: name,
            label: s.label,
            language: s.language,
            index: s.index,
          ),
        );
      }
    }

    await store.writeMeta(
      entry,
      OfflineMeta(
        runtime: item.runtime,
        position: item.position,
        chapters: <OfflineChapter>[
          for (final c in item.chapters)
            OfflineChapter(title: c.title, start: c.start),
        ],
        segments: segments,
        streams: playback.streams,
        subtitles: subtitles,
        defaultAudioIndex: playback.defaultAudioIndex,
        defaultSubtitleIndex: playback.defaultSubtitleIndex,
      ),
    );
  } catch (e) {
    debugPrint('Could not describe ${entry.itemId} for offline play: $e');
  }
}
