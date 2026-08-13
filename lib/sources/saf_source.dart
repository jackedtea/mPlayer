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

/// A folder the user granted through the system picker.
@immutable
class SafFolder {
  const SafFolder({
    required this.treeUri,
    required this.documentId,
    required this.name,
  });

  final String treeUri;
  final String documentId;
  final String name;
}

/// Folder access through Android's Storage Access Framework.
///
/// Complements the media index rather than replacing it. MediaStore covers the
/// common case with no user action, but it cannot see a folder containing a
/// `.nomedia` file, nor anything MediaScanner declined to classify. A SAF
/// grant sees the folder as it really is, and survives reboots.
class SafSource implements BrowsableSource {
  const SafSource();

  static const sourceId = 'saf';
  static const _channel = MethodChannel('dev.icedtea.mplayer/saf');

  /// SAF is an Android concept; other platforms read the filesystem directly.
  static bool get isSupported => Platform.isAndroid;

  @override
  String get id => sourceId;

  @override
  SourceKind get kind => SourceKind.device;

  @override
  SourceCapabilities get capabilities => SourceCapabilities.local;

  @override
  String get rootLabel => 'Folders';

  /// Browse paths are `treeUri|parentDocumentId|documentId`.
  ///
  /// SAF document ids are opaque and offer no way to look up a parent, so the
  /// parent is carried along in the path. Without it, stepping through a
  /// folder with prev/next would have nothing to list.
  @override
  String parentOf(String path) {
    final parts = path.split('|');
    if (parts.length < 3) return path;
    return '${parts[0]}|${parts[1]}';
  }

  /// Opens the system folder picker. Null if the user cancelled.
  Future<SafFolder?> pickFolder() async {
    if (!isSupported) return null;
    try {
      final raw = await _channel.invokeMapMethod<String, Object?>('pickFolder');
      return raw == null ? null : _folderFrom(raw);
    } on PlatformException catch (e) {
      debugPrint('Folder picker failed: $e');
      return null;
    }
  }

  /// Folders granted earlier and still readable.
  Future<List<SafFolder>> folders() async {
    if (!isSupported) return const <SafFolder>[];
    try {
      final raw = await _channel.invokeListMethod<Object?>('persistedFolders');
      return <SafFolder>[
        for (final Object? entry in raw ?? const <Object?>[])
          if (entry is Map) _folderFrom(entry),
      ];
    } on PlatformException catch (e) {
      debugPrint('Could not read granted folders: $e');
      return const <SafFolder>[];
    }
  }

  Future<void> release(String treeUri) async {
    if (!isSupported) return;
    await _channel.invokeMethod<bool>(
      'releaseFolder',
      <String, Object?>{'treeUri': treeUri},
    );
  }

  @override
  Future<BrowseListing> listDirectory(String path) async {
    if (!isSupported) {
      throw const MediaSourceException('Folder access is Android-only.');
    }

    final parts = path.split('|');
    final treeUri = parts.isNotEmpty ? parts[0] : '';
    if (treeUri.isEmpty) {
      throw const MediaSourceException('No folder selected.');
    }
    // Listing the tree root when no document is named.
    final documentId = parts.length > 1 && parts.last.isNotEmpty
        ? parts.last
        : null;

    final List<Object?>? raw;
    try {
      raw = await _channel.invokeListMethod<Object?>(
        'listTree',
        <String, Object?>{'treeUri': treeUri, 'documentId': documentId},
      );
    } on PlatformException catch (e) {
      throw MediaSourceException(
        switch (e.code) {
          'permission_revoked' =>
            'Access to this folder was revoked. Grant it again.',
          'not_found' => 'That folder no longer exists.',
          _ => 'Could not read this folder.',
        },
        cause: e,
      );
    }

    final entries = <BrowseEntry>[
      for (final Object? item in raw ?? const <Object?>[])
        if (item is Map) _entryFrom(item, treeUri, documentId),
    ];

    entries.sort((a, b) {
      if (a.isFolder != b.isFolder) return a.isFolder ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return BrowseListing(path: path, entries: entries);
  }

  @override
  Future<PlayableMedia> resolve(MediaRef ref) async {
    // The itemId carries the document URI after the path parts; playback needs
    // the URI, not the id.
    final uri = ref.itemId.split('|').last;
    return PlayableMedia(
      ref: ref,
      uri: Uri.parse(uri),
      kind: kind,
      capabilities: capabilities,
      sourceLine: 'Device · folder',
    );
  }

  SafFolder _folderFrom(Map<Object?, Object?> raw) => SafFolder(
        treeUri: raw['treeUri'] as String? ?? '',
        documentId: raw['documentId'] as String? ?? '',
        name: raw['name'] as String? ?? 'Folder',
      );

  BrowseEntry _entryFrom(
    Map<Object?, Object?> item,
    String treeUri,
    String? parentId,
  ) {
    final name = item['name'] as String? ?? '';
    final isDir = item['isDirectory'] as bool? ?? false;
    final documentId = item['documentId'] as String? ?? '';
    final size = (item['size'] as int?) ?? 0;

    // Folders navigate by document id; files are opened by URI. Both keep the
    // parent so a sibling listing is possible later.
    final target = isDir ? documentId : (item['uri'] as String? ?? '');
    final parent = parentId ?? '';

    return BrowseEntry(
      name: name,
      kind: isDir ? BrowseEntryKind.folder : classifyFile(name),
      path: '$treeUri|$parent|$target',
      sizeBytes: isDir ? null : size,
      modified: item['modifiedMs'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(item['modifiedMs'] as int),
      detail: isDir ? 'Folder' : formatBytes(size),
    );
  }
}

final safSourceProvider = Provider<SafSource>((ref) => const SafSource());

/// Folders the user has granted, for the Files tab.
final safFoldersProvider = FutureProvider<List<SafFolder>>(
  (ref) => ref.watch(safSourceProvider).folders(),
);
