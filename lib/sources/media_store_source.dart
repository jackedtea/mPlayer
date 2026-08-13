// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/library_models.dart';
import '../core/models/media_models.dart';
import 'local_source.dart' show formatBytes;
import 'media_source.dart';

/// A folder in the system media index.
@immutable
class MediaFolder {
  const MediaFolder({
    required this.id,
    required this.name,
    required this.path,
    required this.videoCount,
  });

  final String id;
  final String name;
  final String path;
  final int videoCount;
}

/// The device's videos, via Android's MediaStore.
///
/// Scoped storage means an app cannot list shared storage directly, so the
/// system media index is the sanctioned way to find the user's videos. The
/// native side queries the *files* collection filtered by extension rather
/// than the video collection, because MediaScanner files `.rmvb`, `.vob` and
/// `.divx` under `application/octet-stream` and they are absent from
/// `Video.Media` — measured on API 37, not assumed.
///
/// It still misses anything under a `.nomedia` folder; the SAF folder picker
/// is the answer for those, and is a separate piece of work.
class MediaStoreSource implements BrowsableSource {
  const MediaStoreSource();

  static const sourceId = 'mediastore';
  static const _channel = MethodChannel('dev.icedtea.mplayer/mediastore');

  /// Android only. Every other platform reads the filesystem directly.
  static bool get isSupported => Platform.isAndroid;

  @override
  String get id => sourceId;

  @override
  SourceKind get kind => SourceKind.device;

  @override
  SourceCapabilities get capabilities => SourceCapabilities.local;

  @override
  String get rootLabel => 'This device';

  /// Bucket ids are opaque, so the "parent" of a video is the folder it was
  /// listed from. Callers pass that through unchanged.
  @override
  String parentOf(String path) => '';

  Future<bool> hasPermission() async {
    if (!isSupported) return false;
    return await _channel.invokeMethod<bool>('hasPermission') ?? false;
  }

  /// Shows the system prompt. Returns whether it was granted.
  Future<bool> requestPermission() async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('requestPermission') ?? false;
    } on PlatformException catch (e) {
      debugPrint('Media permission request failed: $e');
      return false;
    }
  }

  /// Folders holding at least one video, newest first.
  Future<List<MediaFolder>> folders() async {
    if (!isSupported) return const <MediaFolder>[];

    final raw = await _invoke<List<Object?>>('videoFolders');
    if (raw == null) return const <MediaFolder>[];

    return <MediaFolder>[
      for (final Object? entry in raw)
        if (entry is Map)
          MediaFolder(
            id: entry['id'] as String? ?? '',
            name: entry['name'] as String? ?? 'Unknown',
            path: entry['path'] as String? ?? '',
            videoCount: entry['count'] as int? ?? 0,
          ),
    ];
  }

  /// Videos in a folder. An empty [path] lists every video on the device.
  @override
  Future<BrowseListing> listDirectory(String path) async {
    if (!isSupported) {
      throw const MediaSourceException(
        'The media index is only available on Android.',
      );
    }

    final raw = await _invoke<List<Object?>>(
      'videosIn',
      <String, Object?>{'bucketId': path.isEmpty ? null : path},
    );

    final entries = <BrowseEntry>[
      for (final Object? item in raw ?? const <Object?>[])
        if (item is Map)
          BrowseEntry(
            name: item['name'] as String? ?? '',
            kind: BrowseEntryKind.video,
            // The content:// URI, not the raw path: scoped storage can refuse
            // the path even for a file MediaStore happily lists.
            path: item['uri'] as String? ?? '',
            sizeBytes: (item['size'] as int?) ?? 0,
            modified: item['modifiedMs'] == null
                ? null
                : DateTime.fromMillisecondsSinceEpoch(
                    item['modifiedMs'] as int,
                  ),
            detail: formatBytes((item['size'] as int?) ?? 0),
          ),
    ];

    return BrowseListing(path: path, entries: entries);
  }

  @override
  Future<PlayableMedia> resolve(MediaRef ref) async {
    return PlayableMedia(
      ref: ref,
      uri: Uri.parse(ref.itemId),
      kind: kind,
      capabilities: capabilities,
      sourceLine: 'Device',
    );
  }

  Future<T?> _invoke<T>(String method, [Map<String, Object?>? args]) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on PlatformException catch (e) {
      if (e.code == 'permission_denied') {
        throw const MediaSourceException(
          'mPlayer needs permission to read your videos.',
        );
      }
      throw MediaSourceException('Could not read the media index.', cause: e);
    } on MissingPluginException catch (e) {
      // Desktop, or a hot restart before the channel was registered.
      throw MediaSourceException('Media index unavailable.', cause: e);
    }
  }
}

final mediaStoreSourceProvider =
    Provider<MediaStoreSource>((ref) => const MediaStoreSource());

/// Whether the media permission has been granted, so the UI can offer the
/// prompt rather than showing an unexplained empty list.
final mediaPermissionProvider = FutureProvider<bool>(
  (ref) => ref.watch(mediaStoreSourceProvider).hasPermission(),
);

/// Folders for the "This device" section.
final mediaFoldersProvider = FutureProvider<List<MediaFolder>>((ref) async {
  final granted = await ref.watch(mediaPermissionProvider.future);
  if (!granted) return const <MediaFolder>[];
  return ref.watch(mediaStoreSourceProvider).folders();
});
