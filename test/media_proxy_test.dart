// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:mplayer/sources/media_proxy_server.dart';

/// A file that exists only in memory, so the proxy can be exercised without a
/// share, a network, or a real SMB server.
ProxiedMedia fakeMedia({int size = 10000, List<int>? reads}) {
  return ProxiedMedia(
    id: 'test',
    name: 'clip.mkv',
    size: size,
    read: (offset, length) async {
      reads?.add(length);
      // Byte i is i % 251, so any slice is verifiable from its offset alone.
      return Uint8List.fromList(
        List<int>.generate(length, (i) => (offset + i) % 251),
      );
    },
    close: () async {},
  );
}

void main() {
  late MediaProxyServer server;

  setUp(() async {
    server = MediaProxyServer();
    await server.start();
  });

  tearDown(() => server.shutdown());

  group('serving', () {
    test('a whole file comes back with its length', () async {
      final url = await server.publish(fakeMedia(size: 5000));

      final response = await http.get(url);

      expect(response.statusCode, HttpStatus.ok);
      expect(response.bodyBytes, hasLength(5000));
      expect(response.headers['accept-ranges'], 'bytes');
    });

    test('an unknown id is a 404, not a hang', () async {
      final url = await server.publish(fakeMedia());
      final missing = url.replace(path: '/media/nope');

      expect((await http.get(missing)).statusCode, HttpStatus.notFound);
    });

    test('HEAD advertises the size without sending the body', () async {
      final url = await server.publish(fakeMedia(size: 1234));

      final response = await http.head(url);

      // libmpv probes with HEAD before deciding a file is seekable.
      expect(response.statusCode, HttpStatus.ok);
      expect(response.headers['content-length'], '1234');
      expect(response.headers['accept-ranges'], 'bytes');
      expect(response.bodyBytes, isEmpty);
    });
  });

  group('range requests', () {
    test('a middle slice returns 206 with the right bytes', () async {
      final url = await server.publish(fakeMedia(size: 10000));

      final response = await http.get(
        url,
        headers: <String, String>{'Range': 'bytes=100-199'},
      );

      expect(response.statusCode, HttpStatus.partialContent);
      expect(response.headers['content-range'], 'bytes 100-199/10000');
      expect(response.bodyBytes, hasLength(100));
      // Content is derived from the absolute offset, so this proves the read
      // started where it was asked to.
      expect(response.bodyBytes.first, 100 % 251);
      expect(response.bodyBytes.last, 199 % 251);
    });

    test('an open-ended range runs to the end of the file', () async {
      final url = await server.publish(fakeMedia(size: 500));

      final response = await http.get(
        url,
        headers: <String, String>{'Range': 'bytes=400-'},
      );

      expect(response.statusCode, HttpStatus.partialContent);
      expect(response.headers['content-range'], 'bytes 400-499/500');
      expect(response.bodyBytes, hasLength(100));
    });

    test('a suffix range returns the last bytes', () async {
      final url = await server.publish(fakeMedia(size: 500));

      final response = await http.get(
        url,
        headers: <String, String>{'Range': 'bytes=-50'},
      );

      expect(response.headers['content-range'], 'bytes 450-499/500');
      expect(response.bodyBytes, hasLength(50));
    });

    test('an end past the file is clamped rather than refused', () async {
      final url = await server.publish(fakeMedia(size: 500));

      final response = await http.get(
        url,
        headers: <String, String>{'Range': 'bytes=490-9999'},
      );

      expect(response.statusCode, HttpStatus.partialContent);
      expect(response.headers['content-range'], 'bytes 490-499/500');
    });

    test('a start past the file is 416 and reports the real size', () async {
      final url = await server.publish(fakeMedia(size: 500));

      final response = await http.get(
        url,
        headers: <String, String>{'Range': 'bytes=900-'},
      );

      // The size matters: without it libmpv cannot correct its next request.
      expect(response.statusCode, HttpStatus.requestedRangeNotSatisfiable);
      expect(response.headers['content-range'], 'bytes */500');
    });

    test('a malformed range is 416, not a crash', () async {
      final url = await server.publish(fakeMedia(size: 500));

      for (final String bad in <String>['bytes=abc-def', 'lines=0-10', 'bytes=']) {
        final response = await http.get(
          url,
          headers: <String, String>{'Range': bad},
        );
        expect(
          response.statusCode,
          HttpStatus.requestedRangeNotSatisfiable,
          reason: bad,
        );
      }
    });
  });

  group('reads', () {
    test('a large range is chunked rather than read in one go', () async {
      final reads = <int>[];
      final url = await server.publish(
        fakeMedia(size: 3 * 1024 * 1024, reads: reads),
      );

      await http.get(url);

      // Reading a 3 MiB file in one call would buffer the lot in memory.
      expect(reads.length, greaterThan(1));
      expect(reads.every((n) => n <= 1024 * 1024), isTrue);
    });

    test('withdrawing releases the backend handle', () async {
      var closed = false;
      await server.publish(
        ProxiedMedia(
          id: 'x',
          name: 'x',
          size: 10,
          read: (_, l) async => Uint8List(l),
          close: () async => closed = true,
        ),
      );

      await server.withdraw('x');

      // A handle left open holds a share connection for the rest of the
      // session.
      expect(closed, isTrue);
    });
  });
}
