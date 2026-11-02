// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'download_models.dart';
import 'offline_meta.dart';

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
  static const _metaName = 'meta.json';
  static const _pendingName = 'pending_reports.json';

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

  File metaFile(DownloadEntry entry) =>
      File(p.join(itemDir(entry).path, _metaName));

  /// An external subtitle saved for [entry]. [name] is this app's own.
  File subtitleFile(DownloadEntry entry, String name) =>
      File(p.join(itemDir(entry).path, name));

  /// What the server said about the copy, or null where nothing was saved.
  Future<OfflineMeta?> readMeta(DownloadEntry entry) async {
    final file = metaFile(entry);
    try {
      if (!await file.exists()) return null;
      final json = jsonDecode(await file.readAsString());
      return json is Map<String, dynamic> ? OfflineMeta.fromJson(json) : null;
    } on Object catch (e) {
      debugPrint('Could not read ${file.path}: $e');
      return null;
    }
  }

  Future<void> writeMeta(DownloadEntry entry, OfflineMeta meta) async {
    final file = metaFile(entry);
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(meta.toJson()), flush: true);
  }

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
  Future<void> save(List<DownloadEntry> entries) => _replace(
        _index,
        jsonEncode(<Map<String, dynamic>>[for (final e in entries) e.toJson()]),
      );

  /// Writes [content] beside [target] and renames it over, behind whatever
  /// write is already under way.
  Future<void> _replace(File target, String content) {
    final next = _writing.then((_) => _replaceNow(target, content));
    _writing = next.catchError((Object _) {});
    return next;
  }

  Future<void> _replaceNow(File target, String content) async {
    await root.create(recursive: true);
    final tmp = File('${target.path}.tmp');
    await tmp.writeAsString(content, flush: true);

    // Windows refuses a rename over a file something else has open for a
    // moment — the indexer, an antivirus scan of the file just written, a
    // reader — so a few short retries before the write is given up on.
    for (var attempt = 1; ; attempt++) {
      try {
        await tmp.rename(target.path);
        return;
      } on FileSystemException {
        if (attempt == 5) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 25 * attempt));
      }
    }
  }

  File get _pending => File(p.join(root.path, _pendingName));

  /// Where offline playback stopped, keyed by [DownloadEntry.keyOf], for
  /// the server to hear once it can be reached again.
  Future<Map<String, Duration>> readPendingReports() async {
    try {
      if (!await _pending.exists()) return <String, Duration>{};
      final json = jsonDecode(await _pending.readAsString());
      if (json is! Map<String, dynamic>) return <String, Duration>{};
      return <String, Duration>{
        for (final MapEntry<String, dynamic> e in json.entries)
          if (e.value is int) e.key: Duration(milliseconds: e.value as int),
      };
    } on Object catch (e) {
      debugPrint('Could not read the pending reports: $e');
      return <String, Duration>{};
    }
  }

  /// Replaced whole, like the index; an empty map is written as `{}`
  /// rather than deleted, which Windows refuses while a reader has it open.
  Future<void> writePendingReports(Map<String, Duration> reports) => _replace(
        _pending,
        jsonEncode(<String, int>{
          for (final e in reports.entries) e.key: e.value.inMilliseconds,
        }),
      );

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
