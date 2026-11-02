// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'download_models.dart';

/// The offline copies on disk, and the one file that lists them.
///
/// Laid out as `<root>/<profile>/<item>/`, one folder per item, so deleting
/// a copy is deleting a folder — the file, its poster and whatever else
/// later phases put beside it go together and nothing is left orphaned.
///
/// The index is a JSON file rather than a database: a few hundred records
/// at most, read once at launch, and the app already dropped `drift` for
/// having nothing that needed it.
class DownloadStore {
  DownloadStore(this.root);

  final Directory root;

  static const _indexName = 'index.json';
  static const _partName = 'media.part';
  static const posterName = 'poster.jpg';

  File get _index => File(p.join(root.path, _indexName));

  Directory itemDir(DownloadEntry entry) => Directory(
        p.join(root.path, _safe(entry.profileId), _safe(entry.itemId)),
      );

  /// Where the bytes go while they are still arriving.
  File partFile(DownloadEntry entry) =>
      File(p.join(itemDir(entry).path, _partName));

  /// The finished file, or null before there is one.
  File? mediaFile(DownloadEntry entry) {
    final name = entry.fileName;
    if (name == null) return null;
    return File(p.join(itemDir(entry).path, name));
  }

  File posterFile(DownloadEntry entry) =>
      File(p.join(itemDir(entry).path, posterName));

  /// Every copy the index lists, made consistent with the disk.
  ///
  /// Two things a killed process leaves behind are put right here: a copy
  /// still marked `downloading` goes back in the queue, and the byte count
  /// is taken from the partial file itself, which is the only figure a
  /// resume can trust — the index is written less often than the file.
  /// A completed copy whose file has gone is dropped.
  Future<List<DownloadEntry>> load() async {
    final String raw;
    try {
      if (!await _index.exists()) return const <DownloadEntry>[];
      raw = await _index.readAsString();
    } on FileSystemException catch (e) {
      debugPrint('Could not read the downloads index: $e');
      return const <DownloadEntry>[];
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException catch (e) {
      debugPrint('The downloads index is not JSON: $e');
      return const <DownloadEntry>[];
    }
    if (decoded is! List) return const <DownloadEntry>[];

    final entries = <DownloadEntry>[];
    for (final Object? json in decoded) {
      if (json is! Map<String, dynamic>) continue;
      final entry = DownloadEntry.fromJson(json);
      if (entry == null) continue;

      if (entry.status == DownloadStatus.completed) {
        if (mediaFile(entry)?.existsSync() ?? false) entries.add(entry);
        continue;
      }

      final part = partFile(entry);
      final onDisk = part.existsSync() ? part.lengthSync() : 0;
      entries.add(
        entry.copyWith(
          status: entry.status == DownloadStatus.downloading
              ? DownloadStatus.queued
              : entry.status,
          receivedBytes: onDisk,
        ),
      );
    }
    return entries;
  }

  /// The write under way, which the next one waits behind.
  Future<void> _writing = Future<void>.value();

  /// Replaces the index with [entries].
  ///
  /// Written beside and renamed over, so a crash mid-write leaves the old
  /// index rather than half of a new one. One write at a time: two saves a
  /// moment apart — a queue and the fetch it starts — would otherwise share
  /// the temporary file, and Windows refuses the second rename outright.
  Future<void> save(List<DownloadEntry> entries) {
    final next = _writing.then((_) => _write(entries));
    _writing = next.catchError((Object _) {});
    return next;
  }

  Future<void> _write(List<DownloadEntry> entries) async {
    await root.create(recursive: true);
    final tmp = File('${_index.path}.tmp');
    await tmp.writeAsString(
      jsonEncode(<Map<String, dynamic>>[for (final e in entries) e.toJson()]),
      flush: true,
    );

    // Windows refuses a rename over a file something else has open for a
    // moment — the indexer, an antivirus scan of the file just written — so
    // a few short retries before the write is given up on.
    for (var attempt = 1; ; attempt++) {
      try {
        await tmp.rename(_index.path);
        return;
      } on FileSystemException {
        if (attempt == 5) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 25 * attempt));
      }
    }
  }

  /// Removes everything kept for [entry], finished or not.
  Future<void> delete(DownloadEntry entry) async {
    final dir = itemDir(entry);
    try {
      if (await dir.exists()) await dir.delete(recursive: true);
    } on FileSystemException catch (e) {
      debugPrint('Could not delete ${dir.path}: $e');
    }
  }

  /// Bytes the copies take on disk, partial files included.
  Future<int> usedBytes() async {
    if (!await root.exists()) return 0;
    var total = 0;
    await for (final FileSystemEntity f in root.list(recursive: true)) {
      if (f is File && p.basename(f.path) != _indexName) {
        total += await f.length();
      }
    }
    return total;
  }

  /// A server id as a folder name. Jellyfin's are GUIDs already; this is
  /// for the one that is not, so it cannot climb out of [root].
  static String _safe(String id) => id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
}
