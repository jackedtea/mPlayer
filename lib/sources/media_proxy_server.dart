// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Reads [length] bytes from [offset]. The proxy's only view of a source.
typedef RangeReader = Future<Uint8List> Function(int offset, int length);

/// A file the proxy can serve.
@immutable
class ProxiedMedia {
  const ProxiedMedia({
    required this.id,
    required this.name,
    required this.size,
    required this.read,
    required this.close,
  });

  final String id;
  final String name;
  final int size;
  final RangeReader read;

  /// Releases the backend handle once nothing is playing it.
  final Future<void> Function() close;
}

/// Serves remote files to libmpv over loopback HTTP.
///
/// libmpv cannot read a Dart stream — it needs a URL or a path. SMB gives us
/// random-access reads and nothing else, so the gap is bridged by a tiny HTTP
/// server on 127.0.0.1 that turns `Range` requests into offset reads. libmpv
/// then treats the file as an ordinary seekable HTTP resource.
///
/// Bound to loopback on an ephemeral port: this is an implementation detail of
/// playback, never something reachable from the network.
class MediaProxyServer {
  HttpServer? _server;
  final Map<String, ProxiedMedia> _entries = <String, ProxiedMedia>{};

  int get port => _server?.port ?? 0;
  bool get isRunning => _server != null;

  Future<void> start() async {
    if (_server != null) return;

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    server.listen(_handle, onError: (Object e) {
      debugPrint('Media proxy error: $e');
    });
  }

  /// Registers [media] and returns the URL libmpv should open.
  Future<Uri> publish(ProxiedMedia media) async {
    await start();
    _entries[media.id] = media;
    return Uri.parse('http://127.0.0.1:$port/media/${media.id}');
  }

  /// Drops one entry and releases its backend handle.
  Future<void> withdraw(String id) async {
    final entry = _entries.remove(id);
    await entry?.close();
  }

  Future<void> shutdown() async {
    for (final ProxiedMedia entry in _entries.values.toList()) {
      await entry.close();
    }
    _entries.clear();

    await _server?.close(force: true);
    _server = null;
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;

    final id = Uri.decodeComponent(
      request.uri.pathSegments.length >= 2 ? request.uri.pathSegments[1] : '',
    );
    final media = _entries[id];

    if (media == null) {
      response.statusCode = HttpStatus.notFound;
      await response.close();
      return;
    }

    // libmpv probes with HEAD before deciding the file is seekable.
    if (request.method == 'HEAD') {
      _writeHeaders(response, media, null);
      await response.close();
      return;
    }

    final rangeHeader = request.headers.value(HttpHeaders.rangeHeader);
    _ByteRange? range;

    if (rangeHeader != null) {
      range = _ByteRange.parse(rangeHeader, media.size);
      if (range == null) {
        // 416 must carry the real size, or libmpv cannot correct itself.
        response
          ..statusCode = HttpStatus.requestedRangeNotSatisfiable
          ..headers.set(HttpHeaders.acceptRangesHeader, 'bytes')
          ..headers.set(HttpHeaders.contentRangeHeader, 'bytes */${media.size}');
        await response.close();
        return;
      }
    }

    _writeHeaders(response, media, range);

    final start = range?.start ?? 0;
    final end = range?.end ?? media.size - 1;

    try {
      var offset = start;
      while (offset <= end) {
        final remaining = end - offset + 1;
        final toRead = remaining < _chunkSize ? remaining : _chunkSize;

        final chunk = await media.read(offset, toRead);
        if (chunk.isEmpty) break;

        response.add(chunk);
        // Back-pressure: without this a fast share outruns the socket and the
        // whole file buffers in memory.
        await response.flush();

        offset += chunk.length;
      }
    } on SocketException {
      // The player seeked or closed. Expected, and the reason the loop has to
      // stop promptly — a read left running holds a share connection open.
    } catch (e) {
      debugPrint('Media proxy read failed: $e');
    } finally {
      // Closing an already-closed response throws; the client is gone either
      // way and there is nothing to report.
      try {
        await response.close();
      } catch (_) {}
    }
  }

  void _writeHeaders(
    HttpResponse response,
    ProxiedMedia media,
    _ByteRange? range,
  ) {
    response.headers
      ..set(HttpHeaders.acceptRangesHeader, 'bytes')
      ..set(HttpHeaders.contentTypeHeader, 'application/octet-stream');

    if (range == null) {
      response
        ..statusCode = HttpStatus.ok
        ..headers.set(HttpHeaders.contentLengthHeader, '${media.size}');
      return;
    }

    response
      ..statusCode = HttpStatus.partialContent
      ..headers.set(HttpHeaders.contentLengthHeader, '${range.length}')
      ..headers.set(
        HttpHeaders.contentRangeHeader,
        'bytes ${range.start}-${range.end}/${media.size}',
      );
  }

  /// 1 MiB: large enough that per-request overhead disappears, small enough
  /// that a seek cancels quickly.
  static const _chunkSize = 1024 * 1024;
}

/// An inclusive byte range, as HTTP defines it.
@immutable
class _ByteRange {
  const _ByteRange(this.start, this.end);

  /// Parses `bytes=start-end`, `bytes=start-` and `bytes=-suffix`.
  ///
  /// Returns null for anything unsatisfiable, which the caller answers with
  /// 416 rather than guessing at what was meant.
  static _ByteRange? parse(String header, int size) {
    if (size <= 0) return null;
    if (!header.startsWith('bytes=')) return null;

    final spec = header.substring(6).split(',').first.trim();
    final dash = spec.indexOf('-');
    if (dash < 0) return null;

    final startText = spec.substring(0, dash).trim();
    final endText = spec.substring(dash + 1).trim();

    if (startText.isEmpty) {
      // Suffix form: the last N bytes.
      final suffix = int.tryParse(endText);
      if (suffix == null || suffix <= 0) return null;
      final start = suffix >= size ? 0 : size - suffix;
      return _ByteRange(start, size - 1);
    }

    final start = int.tryParse(startText);
    if (start == null || start >= size) return null;

    final end = endText.isEmpty ? size - 1 : int.tryParse(endText);
    if (end == null || end < start) return null;

    return _ByteRange(start, end >= size ? size - 1 : end);
  }

  final int start;
  final int end;

  int get length => end - start + 1;
}

/// One proxy for the whole app; every remote source publishes into it.
final mediaProxyServerProvider = Provider<MediaProxyServer>((ref) {
  final server = MediaProxyServer();
  ref.onDispose(server.shutdown);
  return server;
});
