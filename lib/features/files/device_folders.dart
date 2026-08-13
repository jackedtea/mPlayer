// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/models/library_models.dart';
import '../../sources/media_source.dart';

/// A real folder on this device, offered as a shortcut on the Files tab.
@immutable
class DeviceFolder {
  const DeviceFolder({
    required this.label,
    required this.path,
    required this.icon,
    required this.videoCount,
  });

  final String label;
  final String path;
  final IconData icon;

  /// Videos directly inside the folder. Not recursive: walking a whole
  /// storage volume to render a subtitle would make the tab slow to open,
  /// and the number is a hint, not an inventory.
  final int videoCount;

  String get subtitle =>
      videoCount == 0 ? path : '$videoCount videos · $path';
}

/// The device shortcuts, resolved against the filesystem.
///
/// Only folders that actually exist are listed — offering "Camera" on a
/// desktop, or "Movies" on a phone that has none, is worse than a short list.
final deviceFoldersProvider = FutureProvider<List<DeviceFolder>>((ref) async {
  final candidates = await _candidateFolders();

  final folders = <DeviceFolder>[];
  for (final (String label, String path, IconData icon) in candidates) {
    final dir = Directory(path);
    if (!await dir.exists()) continue;

    folders.add(
      DeviceFolder(
        label: label,
        path: path,
        icon: icon,
        videoCount: await _countVideos(dir),
      ),
    );
  }
  return folders;
});

Future<List<(String, String, IconData)>> _candidateFolders() async {
  if (Platform.isAndroid) {
    final external = await getExternalStorageDirectory();
    final root = external?.path;
    if (root == null) return const <(String, String, IconData)>[];

    // getExternalStorageDirectory returns the app-private directory; the
    // shared folders sit above it, which is where a user's videos actually
    // live.
    final shared = _sharedRootFrom(root);

    return <(String, String, IconData)>[
      ('Internal storage', shared, Icons.sd_storage_rounded),
      ('Movies', p.join(shared, 'Movies'), Icons.movie_rounded),
      ('Downloads', p.join(shared, 'Download'), Icons.download_for_offline_rounded),
      ('Camera', p.join(shared, 'DCIM'), Icons.photo_library_rounded),
    ];
  }

  final env = Platform.environment;
  final home = env['USERPROFILE'] ?? env['HOME'];
  if (home == null) return const <(String, String, IconData)>[];

  return <(String, String, IconData)>[
    ('Home', home, Icons.sd_storage_rounded),
    ('Videos', p.join(home, 'Videos'), Icons.movie_rounded),
    ('Downloads', p.join(home, 'Downloads'), Icons.download_for_offline_rounded),
  ];
}

/// `/storage/emulated/0/Android/data/<pkg>/files` -> `/storage/emulated/0`.
///
/// Falls back to the given path when the layout is not the familiar one,
/// rather than guessing at a root that may not exist.
String _sharedRootFrom(String appPrivatePath) {
  final marker = '${p.separator}Android${p.separator}data${p.separator}';
  final index = appPrivatePath.indexOf(marker);
  return index > 0 ? appPrivatePath.substring(0, index) : appPrivatePath;
}

Future<int> _countVideos(Directory dir) async {
  var count = 0;
  try {
    await for (final FileSystemEntity entity in dir.list()) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (name.startsWith('.')) continue;
      if (classifyFile(name) == BrowseEntryKind.video) count++;
    }
  } on FileSystemException {
    // Scoped storage and permissions both land here. A folder we cannot read
    // is still worth listing; the browser will report why when opened.
    return 0;
  }
  return count;
}
