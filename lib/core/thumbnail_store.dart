// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:convert' show utf8;
import 'dart:io' show Directory, File, FileSystemEntity;
import 'dart:typed_data' show Uint8List;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// The frames grabbed off the player for the Continue-watching shelf.
///
/// One JPEG per resume point, named from the point's key so writing and
/// deleting agree without having to trust a stored path — an app-support
/// directory is re-created under a new container path on iOS and macOS after
/// a reinstall, and a path written before that no longer resolves.
///
/// Application support rather than the temporary directory: a shelf that
/// loses its artwork whenever the OS reclaims caches looks broken. Everything
/// here is best-effort — a failed write costs the card its still, and the
/// gradient placeholder takes over.
class ThumbnailStore {
  /// [directory] is injectable so tests need no platform channel.
  ThumbnailStore({Future<Directory> Function()? directory})
      : _resolve = directory ?? _defaultDirectory;

  static const dirName = 'resume_thumbnails';

  final Future<Directory> Function() _resolve;
  Future<Directory>? _pending;

  static Future<Directory> _defaultDirectory() async {
    final base = await getApplicationSupportDirectory();
    return Directory(p.join(base.path, dirName)).create(recursive: true);
  }

  Future<Directory?> _directory() async {
    try {
      return await (_pending ??= _resolve());
    } catch (e) {
      // No writable directory means no stills, which the shelf survives.
      debugPrint('No thumbnail directory: $e');
      return null;
    }
  }

  /// Stable, filename-safe name for [key].
  ///
  /// The key is `sourceId::itemId`, so it carries separators and can run past
  /// the 255-byte filename limit — it is hashed (FNV-1a, masked to 63 bits so
  /// the result never prints a sign) rather than encoded.
  static String fileNameFor(String key) {
    var hash = 0xcbf29ce484222325;
    for (final int byte in utf8.encode(key)) {
      hash ^= byte;
      hash *= 0x100000001b3;
    }
    return '${(hash & 0x7FFFFFFFFFFFFFFF).toRadixString(16)}.jpg';
  }

  /// Writes [bytes] for [key] and returns the file's path, or null if it
  /// could not be written.
  Future<String?> write(String key, Uint8List bytes) async {
    final dir = await _directory();
    if (dir == null) return null;

    final file = File(p.join(dir.path, fileNameFor(key)));
    try {
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (e) {
      debugPrint('Could not write a thumbnail: $e');
      return null;
    }
  }

  Future<void> delete(String key) async {
    final dir = await _directory();
    if (dir == null) return;

    final file = File(p.join(dir.path, fileNameFor(key)));
    try {
      if (await file.exists()) await file.delete();
    } catch (e) {
      debugPrint('Could not delete a thumbnail: $e');
    }
  }

  /// Drops every still whose resume point is gone.
  ///
  /// Called after the shelf is trimmed: entries pushed past the cap are not
  /// removed one by one, so without this their frames would sit on disk for
  /// good.
  Future<void> retainOnly(Iterable<String> keys) async {
    final dir = await _directory();
    if (dir == null) return;

    final keep = keys.map(fileNameFor).toSet();
    try {
      await for (final FileSystemEntity entity in dir.list()) {
        if (entity is File && !keep.contains(p.basename(entity.path))) {
          await entity.delete();
        }
      }
    } catch (e) {
      debugPrint('Could not prune thumbnails: $e');
    }
  }
}

final thumbnailStoreProvider = Provider<ThumbnailStore>(
  (ref) => ThumbnailStore(),
);
