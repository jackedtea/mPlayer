// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;

import '../core/models/media_models.dart';
import 'media_source.dart';

/// Files already on the device.
///
/// The one source that always exists and can never be offline — it is why the
/// app opens straight onto Storage with nothing configured.
class LocalSource implements MediaSource {
  const LocalSource();

  /// Fixed: there is exactly one device.
  static const sourceId = 'device';

  /// Containers libmpv handles that are worth offering in a picker. Not a
  /// whitelist for playback — [resolve] will hand any path to the backend and
  /// let it decide.
  static const videoExtensions = <String>[
    'mp4', 'mkv', 'mov', 'avi', 'webm', 'm4v', 'ts', 'm2ts', 'mpg', 'mpeg',
    'wmv', 'flv', '3gp', 'ogv', 'rmvb',
  ];

  @override
  String get id => sourceId;

  @override
  SourceKind get kind => SourceKind.device;

  @override
  SourceCapabilities get capabilities => SourceCapabilities.local;

  @override
  Future<PlayableMedia> resolve(MediaRef ref) async {
    final path = ref.itemId;

    // A content:// URI from the Android picker is already a handle; there is
    // no filesystem entry to stat, so it goes straight through.
    if (path.startsWith('content://')) {
      return PlayableMedia(
        ref: ref,
        uri: Uri.parse(path),
        kind: kind,
        capabilities: capabilities,
        sourceLine: 'Device · content provider',
      );
    }

    final file = File(path);
    if (!await file.exists()) {
      throw MediaSourceException('File no longer exists:\n$path');
    }

    final size = await file.length();
    return PlayableMedia(
      ref: ref,
      uri: Uri.file(path),
      kind: kind,
      capabilities: capabilities,
      sourceLine: 'Device · ${p.extension(path).replaceFirst('.', '').toUpperCase()}'
          ' · ${formatBytes(size)}',
    );
  }

  /// Opens the platform picker and returns a reference, or null if cancelled.
  ///
  /// Picking is local-only, so it lives here rather than on [MediaSource] —
  /// a Jellyfin library has nothing analogous.
  Future<MediaRef?> pickVideo() async {
    final group = XTypeGroup(
      label: 'Video',
      extensions: videoExtensions,
      // UTIs and MIME types are required on Apple platforms and Android
      // respectively; extensions alone are ignored there.
      uniformTypeIdentifiers: const <String>['public.movie', 'public.video'],
      mimeTypes: const <String>['video/*'],
    );

    final XFile? file = await openFile(acceptedTypeGroups: <XTypeGroup>[group]);
    if (file == null) return null;

    return MediaRef(
      sourceId: sourceId,
      itemId: file.path,
      title: file.name.isNotEmpty ? file.name : p.basename(file.path),
    );
  }
}

/// 1.4 TB / 18.4 GB / 842 MB, matching the browser and detail screens.
String formatBytes(int bytes) {
  const units = <String>['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final fractionDigits = value >= 100 || unit == 0 ? 0 : 1;
  return '${value.toStringAsFixed(fractionDigits)} ${units[unit]}';
}
