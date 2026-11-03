// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

/// A loopback stand-in for a server's download route, shared by the
/// download tests.
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

/// 300 KB of bytes that differ from one position to the next, so a resume
/// stitched at the wrong offset cannot compare equal by accident.
final testFile = Uint8List.fromList(
  List<int>.generate(300 * 1024, (i) => (i * 31 + (i >> 8)) & 0xff),
);

/// A loopback server standing in for `/Items/{id}/Download`.
class FileServer {
  late final HttpServer _server;
  bool honourRange = true;
  int? status;

  /// When set, the response stops after the first 64 KB until it completes.
  Completer<void>? hold;

  final List<String?> ranges = <String?>[];

  Uri get base => Uri.parse('http://127.0.0.1:${_server.port}');

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen(_handle);
  }

  Future<void> stop() => _server.close(force: true);

  Future<void> _handle(HttpRequest request) async {
    final res = request.response;
    final range = request.headers.value(HttpHeaders.rangeHeader);
    ranges.add(range);

    if (status != null) {
      res.statusCode = status!;
      await res.close();
      return;
    }

    res.headers.set(
      'content-disposition',
      'attachment; filename="The Film (2024).MKV"',
    );

    var start = 0;
    if (range != null && honourRange) {
      start = int.parse(RegExp(r'bytes=(\d+)-').firstMatch(range)!.group(1)!);
      if (start >= testFile.length) {
        res.statusCode = 416;
        res.headers.set('content-range', 'bytes */${testFile.length}');
        await res.close();
        return;
      }
      res.statusCode = 206;
      res.headers.set(
        'content-range',
        'bytes $start-${testFile.length - 1}/${testFile.length}',
      );
    }
    final body = testFile.sublist(start);
    res.contentLength = body.length;

    final gate = hold;
    if (gate != null) {
      res.add(body.sublist(0, 64 * 1024));
      await res.flush();
      await gate.future;
      try {
        res.add(body.sublist(64 * 1024));
        await res.close();
      } catch (_) {
        // The client hung up, which is the point of the test.
      }
      return;
    }
    res.add(body);
    await res.close();
  }
}
