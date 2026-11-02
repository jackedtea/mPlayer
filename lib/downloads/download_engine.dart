// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'download_models.dart';
import 'download_store.dart';

/// Moves one file's bytes from the server onto the disk.
///
/// Knows nothing of queues or of which server is signed in: it is handed an
/// entry and a URL and gives back the entry as it stands afterwards. It
/// never throws — a dead connection, a full disk and a refusal all come back
/// as [DownloadStatus.failed] with a sentence, and a cancel as
/// [DownloadStatus.paused], with the partial file kept for a resume.
///
/// Written over a response stream rather than `Dio.download`, because a
/// resume has to know which of two answers it got: a 206 continues the
/// partial file, and a 200 means the server ignored the range and is
/// sending it all again, which must overwrite rather than append.
class DownloadEngine {
  DownloadEngine({required this.store, Dio? client})
      : _dio = client ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 10),
                // Between chunks, not for the whole file: a two-hour film
                // takes as long as it takes.
                receiveTimeout: const Duration(seconds: 30),
              ),
            );

  final DownloadStore store;
  final Dio _dio;

  /// Fetches [entry]'s file from [url], continuing whatever is on disk.
  ///
  /// [onProgress] is called per chunk with the bytes on disk and the total
  /// where it is known; throttling it is the caller's business.
  Future<DownloadEntry> fetch(
    DownloadEntry entry,
    Uri url, {
    required void Function(int received, int? total) onProgress,
    CancelToken? cancel,
  }) async {
    final part = store.partFile(entry);
    var received = 0;
    int? total = entry.totalBytes;

    try {
      await part.parent.create(recursive: true);
      final start = await part.exists() ? await part.length() : 0;
      received = start;

      final response = await _dio.getUri<ResponseBody>(
        url,
        cancelToken: cancel,
        options: Options(
          responseType: ResponseType.stream,
          validateStatus: (_) => true,
          headers: <String, String>{
            if (start > 0) HttpHeaders.rangeHeader: 'bytes=$start-',
          },
        ),
      );

      final status = response.statusCode ?? 0;
      final body = response.data;

      if (status == 416 && start > 0) {
        // The range starts at or past the end. If the server's size is what
        // is already here, the file was finished and only the rename lost.
        await body?.stream.drain<void>();
        final size = _rangeTotal(response.headers.value(HttpHeaders.contentRangeHeader));
        if (size == start) {
          return _finish(entry, part, response.headers, received: start);
        }
        // Otherwise what is on disk is not a prefix of this file.
        await part.delete();
        return fetch(
          entry.copyWith(receivedBytes: 0),
          url,
          onProgress: onProgress,
          cancel: cancel,
        );
      }

      if (status != 200 && status != 206) {
        await body?.stream.drain<void>();
        return _failed(entry, received, total, _refusal(status));
      }
      if (body == null) {
        return _failed(entry, received, total, 'The server sent no file.');
      }

      final resuming = status == 206 && start > 0;
      if (!resuming) received = 0;

      final length = int.tryParse(
        response.headers.value(HttpHeaders.contentLengthHeader) ?? '',
      );
      total = resuming
          ? (_rangeTotal(response.headers.value(HttpHeaders.contentRangeHeader)) ??
              (length == null ? null : start + length))
          : length;
      onProgress(received, total);

      final sink = part.openWrite(
        mode: resuming ? FileMode.append : FileMode.write,
      );
      try {
        await for (final Uint8List chunk in body.stream) {
          sink.add(chunk);
          received += chunk.length;
          onProgress(received, total);
        }
      } finally {
        await sink.close();
      }

      if (total != null && received < total) {
        // The stream ended cleanly but short — a proxy giving up, say.
        return _failed(
          entry,
          received,
          total,
          'The connection closed before the file was complete.',
        );
      }

      return _finish(entry, part, response.headers, received: received);
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        return entry.copyWith(
          status: DownloadStatus.paused,
          receivedBytes: received,
          totalBytes: total,
          clearError: true,
        );
      }
      debugPrint('Download of ${entry.itemId} failed: $e');
      return _failed(entry, received, total, 'Could not reach the server.');
    } on FileSystemException catch (e) {
      debugPrint('Download of ${entry.itemId} could not be written: $e');
      return _failed(
        entry,
        received,
        total,
        _isDiskFull(e)
            ? 'There is no room left on this device.'
            : 'Could not write the file to this device.',
      );
    } on SocketException catch (e) {
      debugPrint('Download of ${entry.itemId} dropped: $e');
      return _failed(entry, received, total, 'The connection dropped.');
    }
  }

  /// Saves the artwork beside the file. Best effort: a copy without a
  /// poster still plays, so a failure here is logged and nothing more.
  Future<void> fetchPoster(DownloadEntry entry, Uri url) async {
    await fetchFile(url, store.posterFile(entry));
  }

  /// Fetches a small file whole into [file] — a poster, a subtitle. False
  /// when it could not, which every caller treats as "do without".
  Future<bool> fetchFile(Uri url, File file) async {
    try {
      await file.parent.create(recursive: true);
      final response = await _dio.getUri<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          validateStatus: (s) => s == 200,
        ),
      );
      final bytes = response.data;
      if (bytes == null) return false;
      await file.writeAsBytes(bytes, flush: true);
      return true;
    } catch (e) {
      debugPrint('Could not fetch ${url.path}: $e');
      return false;
    }
  }

  Future<DownloadEntry> _finish(
    DownloadEntry entry,
    File part,
    Headers headers, {
    required int received,
  }) async {
    final name = 'media${_extensionOf(headers)}';
    await part.rename(p.join(part.parent.path, name));
    return entry.copyWith(
      status: DownloadStatus.completed,
      receivedBytes: received,
      totalBytes: received,
      fileName: name,
      clearError: true,
    );
  }

  DownloadEntry _failed(
    DownloadEntry entry,
    int received,
    int? total,
    String message,
  ) =>
      entry.copyWith(
        status: DownloadStatus.failed,
        receivedBytes: received,
        totalBytes: total,
        error: message,
      );

  static String _refusal(int status) => switch (status) {
        401 => 'Sign in to the server again to download.',
        403 => 'This account is not allowed to download from the server.',
        404 => 'The server no longer has this item.',
        _ => 'The server refused the download (HTTP $status).',
      };

  /// ENOSPC on Linux and Android, ERROR_DISK_FULL / ERROR_HANDLE_DISK_FULL
  /// on Windows.
  static bool _isDiskFull(FileSystemException e) =>
      const <int>{28, 39, 112}.contains(e.osError?.errorCode);
}

/// The total from `Content-Range: bytes 0-99/1234` or `bytes */1234`.
@visibleForTesting
int? rangeTotalOf(String? header) => _rangeTotal(header);

int? _rangeTotal(String? header) {
  if (header == null) return null;
  final slash = header.lastIndexOf('/');
  if (slash < 0) return null;
  return int.tryParse(header.substring(slash + 1).trim());
}

/// The extension of the name the server gave the file, dot included, or
/// empty when it gave none.
///
/// The file is saved under a name of this app's choosing — `media.mkv` —
/// rather than the server's, which can hold anything a filesystem refuses.
/// The extension is kept because it is the one part a player looks at.
@visibleForTesting
String extensionOfDisposition(String? header) {
  if (header == null) return '';

  String? name;
  final star = RegExp(r"filename\*\s*=\s*[^']*'[^']*'([^;]+)", caseSensitive: false)
      .firstMatch(header);
  if (star != null) {
    name = Uri.decodeComponent(star.group(1)!.trim());
  } else {
    final plain = RegExp(r'filename\s*=\s*"?([^";]+)"?', caseSensitive: false)
        .firstMatch(header);
    name = plain?.group(1)?.trim();
  }
  if (name == null) return '';

  final ext = p.extension(name).toLowerCase();
  return RegExp(r'^\.[a-z0-9]{1,5}$').hasMatch(ext) ? ext : '';
}

String _extensionOf(Headers headers) =>
    extensionOfDisposition(headers.value('content-disposition'));
