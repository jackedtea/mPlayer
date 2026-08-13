// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:async';

import 'package:dart_smb2/dart_smb2.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../core/models/library_models.dart';
import '../core/models/media_models.dart';
import 'local_source.dart' show formatBytes;
import 'media_proxy_server.dart';
import 'media_source.dart';
import 'source_config.dart';

/// SMB2/3 shares.
///
/// Playback goes through [MediaProxyServer] rather than straight to libmpv:
/// libmpv cannot read a Dart stream, and SMB offers random-access reads and
/// nothing addressable by URL. The proxy turns `Range` requests into
/// `readFromHandle(offset:)`, which is what makes seeking work — a sequential
/// stream would only ever play forwards.
class SmbSource implements BrowsableSource {
  SmbSource({
    required this.config,
    required this.password,
    required MediaProxyServer proxy,
  })  :
        // A private field cannot be an initializing formal.
        // ignore: prefer_initializing_formals
        _proxy = proxy;

  final SourceConfig config;

  /// Read from the keychain just before construction; never persisted beside
  /// [config].
  final String? password;

  final MediaProxyServer _proxy;

  Smb2Pool? _pool;
  Future<Smb2Pool>? _connecting;

  /// Handles the proxy is currently serving, so they can be closed when the
  /// player moves on. A leaked handle holds a share connection open.
  final Map<String, Smb2PoolHandle> _openHandles = <String, Smb2PoolHandle>{};

  @override
  String get id => config.id;

  @override
  SourceKind get kind => SourceKind.smb;

  @override
  SourceCapabilities get capabilities =>
      const SourceCapabilities(externalSubtitles: true);

  @override
  String get rootLabel => config.name;

  /// SMB paths are POSIX-shaped regardless of the host's separator.
  @override
  String parentOf(String path) => p.posix.dirname(path);

  /// `smb://host/share` — the share is the first path segment.
  ({String host, String share}) get _target {
    final uri = Uri.parse(config.uri);
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    return (
      host: uri.host.isNotEmpty ? uri.host : config.uri,
      share: segments.isEmpty ? '' : segments.first,
    );
  }

  /// One pool per source, created on first use.
  ///
  /// Concurrent callers share the same in-flight connect rather than each
  /// opening their own: the browser and a playlist load can easily land at
  /// the same moment.
  Future<Smb2Pool> _connect() {
    final existing = _pool;
    if (existing != null) return Future<Smb2Pool>.value(existing);
    return _connecting ??= _openPool();
  }

  Future<Smb2Pool> _openPool() async {
    final target = _target;
    if (target.share.isEmpty) {
      _connecting = null;
      throw MediaSourceException(
        'No share in "${config.uri}". Expected smb://host/share.',
      );
    }

    try {
      final pool = await Smb2Pool.connect(
        host: target.host,
        share: target.share,
        user: config.username.isEmpty ? null : config.username,
        password: password,
      );
      _pool = pool;
      return pool;
    } on Smb2Exception catch (e) {
      _connecting = null;
      throw MediaSourceException(_describe(e, target.host), cause: e);
    } catch (e) {
      _connecting = null;
      throw MediaSourceException(
        'Could not reach ${target.host}.',
        cause: e,
      );
    }
  }

  static String _describe(Smb2Exception e, String host) {
    final text = e.toString().toLowerCase();
    if (text.contains('logon') ||
        text.contains('access denied') ||
        text.contains('auth')) {
      return 'Access denied by $host. Check the username and password.';
    }
    if (text.contains('timed out') || text.contains('timeout')) {
      return '$host did not respond.';
    }
    return 'Could not reach $host.';
  }

  @override
  Future<BrowseListing> listDirectory(String path) async {
    final pool = await _connect();
    // libsmb2 wants a share-relative path with no leading slash.
    final relative = _relative(path);

    final List<Smb2DirEntry> raw;
    try {
      raw = await pool.listDirectory(relative);
    } on Smb2Exception catch (e) {
      throw MediaSourceException(
        'Could not read $path on ${_target.host}.',
        cause: e,
      );
    }

    final entries = <BrowseEntry>[
      for (final Smb2DirEntry entry in raw)
        if (entry.name != '.' && entry.name != '..' && !entry.name.startsWith('.'))
          BrowseEntry(
            name: entry.name,
            kind: entry.isDirectory
                ? BrowseEntryKind.folder
                : classifyFile(entry.name),
            path: p.posix.join(path.isEmpty ? '/' : path, entry.name),
            sizeBytes: entry.isDirectory ? null : entry.stat.size,
            modified: entry.stat.modified,
            detail: entry.isDirectory ? 'Folder' : formatBytes(entry.stat.size),
          ),
    ];

    entries.sort((a, b) {
      if (a.isFolder != b.isFolder) return a.isFolder ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return BrowseListing(path: path, entries: entries);
  }

  @override
  Future<PlayableMedia> resolve(MediaRef ref) async {
    final pool = await _connect();
    final relative = _relative(ref.itemId);

    // A previous play of the same file may still hold a handle.
    await _release(ref.itemId);

    final (Smb2PoolHandle handle, int size) =
        await pool.openFileWithSize(relative);
    _openHandles[ref.itemId] = handle;

    final url = await _proxy.publish(
      ProxiedMedia(
        id: '${config.id}:${ref.itemId}',
        name: ref.title,
        size: size,
        read: (offset, length) =>
            pool.readFromHandle(handle, offset: offset, length: length),
        close: () => _release(ref.itemId),
      ),
    );

    return PlayableMedia(
      ref: ref,
      uri: url,
      kind: kind,
      capabilities: capabilities,
      // Honest about the hop: bytes come off the share and through a local
      // socket, so this is not the direct play WebDAV gets.
      sourceLine: '${config.name} · SMB · ${formatBytes(size)}',
    );
  }

  Future<void> _release(String itemId) async {
    final handle = _openHandles.remove(itemId);
    if (handle == null) return;

    try {
      await _pool?.closeHandle(handle);
    } catch (e) {
      debugPrint('Could not close SMB handle: $e');
    }
  }

  /// Closes every handle and the pool. Called when the source is removed or
  /// reconfigured.
  Future<void> dispose() async {
    for (final String id in _openHandles.keys.toList()) {
      await _release(id);
    }
    await _pool?.disconnect();
    _pool = null;
    _connecting = null;
  }

  static String _relative(String path) {
    final trimmed = path.startsWith('/') ? path.substring(1) : path;
    return trimmed;
  }
}
