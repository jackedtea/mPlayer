// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:io' show Directory, File, Platform;
import 'dart:typed_data' show Uint8List;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Where a frame grabbed from the player is written.
///
/// No gallery plugin: saving into the system photo library means a native
/// dependency and a runtime permission on every platform, for a file the user
/// asked for once. A folder they can reach with a file manager is the whole
/// requirement, so this writes to the most public directory `path_provider`
/// offers without asking for anything:
///
/// * Android — the app's own external directory, which is world-readable and
///   needs no permission on any supported API level.
/// * Desktop — Downloads, which is where a browser would have put it.
/// * iOS — the documents directory, which the Files app shows.
Future<Directory> screenshotDirectory() async {
  Directory? base;

  try {
    if (Platform.isAndroid) {
      base = await getExternalStorageDirectory();
    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      base = await getDownloadsDirectory();
    }
  } catch (e) {
    // A platform that cannot answer falls through to documents rather than
    // failing the save.
    debugPrint('Could not find a screenshot directory: $e');
  }

  base ??= await getApplicationDocumentsDirectory();

  final dir = Directory(p.join(base.path, 'mPlayer', 'Screenshots'));
  await dir.create(recursive: true);
  return dir;
}

/// Writes [bytes] beside the title and position they were grabbed at.
///
/// Returns the file, or null when it could not be written — a full disk or a
/// directory the platform refuses is worth telling the user about, but never
/// worth throwing out of a button press.
Future<File?> saveScreenshot(
  Uint8List bytes, {
  required String title,
  required Duration at,
  DateTime? now,
}) async {
  try {
    final dir = await screenshotDirectory();
    final file = File(p.join(dir.path, screenshotName(title: title, at: at,
        now: now ?? DateTime.now())));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  } catch (e) {
    debugPrint('Could not save a screenshot: $e');
    return null;
  }
}

/// `Nightfall S01E02 - 00-12-04 - 20260907-193355.jpg`.
///
/// The position is in the name because that is what the viewer was looking
/// at; the wall clock is there because two grabs of the same frame must not
/// overwrite each other.
String screenshotName({
  required String title,
  required Duration at,
  required DateTime now,
}) {
  final position = <int>[
    at.inHours,
    at.inMinutes.remainder(60),
    at.inSeconds.remainder(60),
  ].map((n) => n.toString().padLeft(2, '0')).join('-');

  final stamp = '${now.year}'
      '${_two(now.month)}${_two(now.day)}-'
      '${_two(now.hour)}${_two(now.minute)}${_two(now.second)}';

  return '${sanitiseFileName(title)} - $position - $stamp.jpg';
}

/// Strips what no filesystem in use will take, and trims the result to
/// something a path length limit can live with.
///
/// A media title is whatever a muxer or a server put there — colons in
/// "Series: Part One" and slashes in a date are both common, and both are
/// path separators on some platform.
String sanitiseFileName(String title) {
  final cleaned = title
      .replaceAll(RegExp(r'[\/:*?"<>|\x00-\x1f]'), '_')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  if (cleaned.isEmpty) return 'Video';
  return cleaned.length <= 60 ? cleaned : cleaned.substring(0, 60).trim();
}

String _two(int n) => n.toString().padLeft(2, '0');
