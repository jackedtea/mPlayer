// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:mplayer/core/models/library_models.dart';
import 'package:mplayer/core/models/media_models.dart';
import 'package:mplayer/sources/media_source.dart';
import 'package:mplayer/sources/source_config.dart';
import 'package:mplayer/sources/webdav_source.dart';

/// Shaped like Nextcloud: `d:` prefix, percent-encoded hrefs, the requested
/// directory returned as the first response.
const _nextcloudBody = '''
<?xml version="1.0"?>
<d:multistatus xmlns:d="DAV:" xmlns:s="http://sabredav.org/ns">
  <d:response>
    <d:href>/remote.php/dav/files/minh/Media/</d:href>
    <d:propstat>
      <d:prop>
        <d:resourcetype><d:collection/></d:resourcetype>
        <d:displayname>Media</d:displayname>
      </d:prop>
      <d:status>HTTP/1.1 200 OK</d:status>
    </d:propstat>
  </d:response>
  <d:response>
    <d:href>/remote.php/dav/files/minh/Media/Short%20films/</d:href>
    <d:propstat>
      <d:prop>
        <d:resourcetype><d:collection/></d:resourcetype>
        <d:displayname>Short films</d:displayname>
        <d:getlastmodified>Tue, 10 Feb 2026 09:41:00 GMT</d:getlastmodified>
      </d:prop>
      <d:status>HTTP/1.1 200 OK</d:status>
    </d:propstat>
  </d:response>
  <d:response>
    <d:href>/remote.php/dav/files/minh/Media/The%20Harbour%20Line.mkv</d:href>
    <d:propstat>
      <d:prop>
        <d:resourcetype/>
        <d:displayname>The Harbour Line.mkv</d:displayname>
        <d:getcontentlength>19783286784</d:getcontentlength>
        <d:getlastmodified>Mon, 09 Feb 2026 22:15:00 GMT</d:getlastmodified>
      </d:prop>
      <d:status>HTTP/1.1 200 OK</d:status>
    </d:propstat>
  </d:response>
  <d:response>
    <d:href>/remote.php/dav/files/minh/Media/The%20Harbour%20Line.en.srt</d:href>
    <d:propstat>
      <d:prop>
        <d:resourcetype/>
        <d:displayname>The Harbour Line.en.srt</d:displayname>
        <d:getcontentlength>86016</d:getcontentlength>
      </d:prop>
      <d:status>HTTP/1.1 200 OK</d:status>
    </d:propstat>
  </d:response>
  <d:response>
    <d:href>/remote.php/dav/files/minh/Media/notes.txt</d:href>
    <d:propstat>
      <d:prop>
        <d:resourcetype/>
        <d:displayname>notes.txt</d:displayname>
        <d:getcontentlength>1024</d:getcontentlength>
      </d:prop>
      <d:status>HTTP/1.1 200 OK</d:status>
    </d:propstat>
  </d:response>
</d:multistatus>
''';

/// Shaped like Apache mod_dav: uppercase `D:` prefix, no displayname, absolute
/// URLs in href. Both variants have to parse.
const _apacheBody = '''
<?xml version="1.0" encoding="utf-8"?>
<D:multistatus xmlns:D="DAV:">
  <D:response>
    <D:href>http://dav.home.lan/media/</D:href>
    <D:propstat><D:prop><D:resourcetype><D:collection/></D:resourcetype></D:prop></D:propstat>
  </D:response>
  <D:response>
    <D:href>http://dav.home.lan/media/Coastline.mp4</D:href>
    <D:propstat>
      <D:prop>
        <D:resourcetype/>
        <D:getcontentlength>4404019200</D:getcontentlength>
      </D:prop>
    </D:propstat>
  </D:response>
</D:multistatus>
''';

void main() {
  group('parsePropfind', () {
    late List<BrowseEntry> entries;

    setUp(() {
      entries = parsePropfind(
        _nextcloudBody,
        requestPath: '/remote.php/dav/files/minh/Media',
      );
    });

    test('drops the requested directory itself', () {
      // Depth 1 returns the directory as its own first entry; listing it as a
      // row would give every folder a phantom child.
      expect(entries.any((e) => e.name == 'Media'), isFalse);
      expect(entries, hasLength(4));
    });

    test('sorts folders first, then case-insensitively by name', () {
      expect(entries.first.name, 'Short films');
      expect(entries.first.isFolder, isTrue);
      expect(
        entries.skip(1).map((e) => e.name),
        <String>[
          'notes.txt',
          'The Harbour Line.en.srt',
          'The Harbour Line.mkv',
        ],
      );
    });

    test('classifies video, subtitle and other files', () {
      BrowseEntry byName(String n) => entries.firstWhere((e) => e.name == n);

      expect(byName('The Harbour Line.mkv').kind, BrowseEntryKind.video);
      expect(byName('The Harbour Line.en.srt').kind, BrowseEntryKind.subtitle);
      expect(byName('notes.txt').kind, BrowseEntryKind.other);
      expect(byName('Short films').kind, BrowseEntryKind.folder);
    });

    test('decodes percent-encoded paths so navigation works', () {
      final folder = entries.firstWhere((e) => e.isFolder);
      expect(folder.path, '/remote.php/dav/files/minh/Media/Short films');
    });

    test('reads size and last-modified', () {
      final video = entries.firstWhere((e) => e.name.endsWith('.mkv'));

      expect(video.sizeBytes, 19783286784);
      expect(video.detail, contains('18.4 GB'));
      expect(video.modified?.year, 2026);
      expect(video.detail, contains('2026-02-09'));
    });

    test('a folder reports no size rather than zero bytes', () {
      final folder = entries.firstWhere((e) => e.isFolder);
      expect(folder.sizeBytes, isNull);
      expect(folder.detail, 'Folder');
    });
  });

  group('parsePropfind — server variations', () {
    test('handles uppercase prefixes, absolute hrefs and no displayname', () {
      final entries = parsePropfind(_apacheBody, requestPath: '/media');

      expect(entries, hasLength(1));
      expect(entries.single.name, 'Coastline.mp4');
      expect(entries.single.kind, BrowseEntryKind.video);
      expect(entries.single.sizeBytes, 4404019200);
    });

    test('malformed XML surfaces as a MediaSourceException', () {
      expect(
        () => parsePropfind('<not xml', requestPath: '/'),
        throwsA(isA<MediaSourceException>()),
      );
    });

    test('an empty multistatus is a valid empty directory', () {
      const empty = '<?xml version="1.0"?><d:multistatus xmlns:d="DAV:"/>';
      expect(parsePropfind(empty, requestPath: '/media'), isEmpty);
    });
  });

  group('safeDecodePath', () {
    test('decodes ordinary percent escapes', () {
      expect(safeDecodePath('/dav/Short%20films'), '/dav/Short films');
      expect(safeDecodePath('/dav/%E4%B8%AD%E6%96%87'), '/dav/中文');
    });

    test('survives a name containing a literal percent sign', () {
      // Regression: this is what "Illegal percent encoding in URI" was.
      // %25 decodes to '%', and the result still holds non-ASCII, which
      // Uri.decodeFull refuses to look at.
      expect(safeDecodePath('/dav/%E4%B8%AD%2050%25.mkv'), '/dav/中 50%.mkv');
    });

    test('survives a partially encoded href', () {
      // Some servers leave non-ASCII raw but still encode spaces.
      expect(safeDecodePath('/dav/中文%20film.mkv'), '/dav/中文 film.mkv');
    });

    test('passes invalid or truncated escapes through untouched', () {
      expect(safeDecodePath('/dav/100% raw.mkv'), '/dav/100% raw.mkv');
      expect(safeDecodePath('/dav/a%zz.mkv'), '/dav/a%zz.mkv');
      expect(safeDecodePath('/dav/trailing%'), '/dav/trailing%');
      expect(safeDecodePath('/dav/cut%2'), '/dav/cut%2');
    });

    test('never throws, whatever the server sends', () {
      const nasty = <String>[
        '%',
        '%%%',
        '/a%C3%28b',
        '中%',
        '%E4%B8%AD%',
      ];
      for (final String input in nasty) {
        expect(() => safeDecodePath(input), returnsNormally, reason: input);
      }
    });
  });

  group('parsePropfind — awkward names', () {
    test('lists CJK names and names containing a percent sign', () {
      const body = '''
<?xml version="1.0"?>
<d:multistatus xmlns:d="DAV:">
  <d:response>
    <d:href>/dav/media/</d:href>
    <d:propstat><d:prop><d:resourcetype><d:collection/></d:resourcetype></d:prop></d:propstat>
  </d:response>
  <d:response>
    <d:href>/dav/media/%E4%B8%AD%2050%25.mkv</d:href>
    <d:propstat>
      <d:prop><d:resourcetype/><d:getcontentlength>1024</d:getcontentlength></d:prop>
    </d:propstat>
  </d:response>
  <d:response>
    <d:href>/dav/media/中文%20film.mkv</d:href>
    <d:propstat>
      <d:prop><d:resourcetype/><d:getcontentlength>2048</d:getcontentlength></d:prop>
    </d:propstat>
  </d:response>
</d:multistatus>
''';

      final entries = parsePropfind(body, requestPath: '/dav/media');

      expect(entries, hasLength(2));
      expect(
        entries.map((e) => e.name),
        containsAll(<String>['中 50%.mkv', '中文 film.mkv']),
      );
      // The decoded path is what a later resolve() re-encodes for playback.
      expect(
        entries.map((e) => e.path),
        containsAll(<String>[
          '/dav/media/中 50%.mkv',
          '/dav/media/中文 film.mkv',
        ]),
      );
    });
  });

  group('WebDavSource', () {
    const config = SourceConfig(
      id: 'nc',
      kind: SourceKind.webdav,
      name: 'Nextcloud',
      uri: 'https://dav.home.lan/remote.php/dav/files/minh',
      username: 'minh',
    );

    test('sends basic auth that libmpv can reuse for the stream', () {
      final source = WebDavSource(config: config, password: 'hunter2');
      final header = source.authHeaders['Authorization'];

      expect(header, isNotNull);
      expect(
        utf8.decode(base64Decode(header!.substring('Basic '.length))),
        'minh:hunter2',
      );
    });

    test('sends no auth header when the share is anonymous', () {
      const anon = SourceConfig(
        id: 'pub',
        kind: SourceKind.webdav,
        name: 'Public',
        uri: 'https://dav.home.lan/public',
      );
      expect(
        WebDavSource(config: anon, password: null).authHeaders,
        isEmpty,
      );
    });

    test('a relative path is appended to the configured base', () {
      final source = WebDavSource(config: config, password: 'x');
      final url = source.urlFor('Media/Short films/Clip 1.mkv');

      expect(url.host, 'dav.home.lan');
      expect(
        url.path,
        '/remote.php/dav/files/minh/Media/Short%20films/Clip%201.mkv',
      );
    });

    test('an href path is used as-is, not appended to the base again', () {
      // Regression: entry.path comes from an href and already contains the
      // base's own prefix. Appending produced /remote.php/dav/files/minh
      // twice, so every subfolder 404'd.
      final source = WebDavSource(config: config, password: 'x');
      final url = source.urlFor(
        '/remote.php/dav/files/minh/Media/Clip 1.mkv',
      );

      expect(url.path, '/remote.php/dav/files/minh/Media/Clip%201.mkv');
    });

    test('re-encodes awkward names on the way back out', () {
      final source = WebDavSource(config: config, password: 'x');
      final url = source.urlFor('/remote.php/dav/files/minh/中 50%.mkv');

      // The listing decoded these; playback has to encode them again.
      expect(url.path, endsWith('/%E4%B8%AD%2050%25.mkv'));
      // And the round trip must land back on the original name.
      expect(safeDecodePath(url.path), endsWith('/中 50%.mkv'));
    });

    test('resolve hands libmpv the URL plus the auth header', () async {
      final source = WebDavSource(config: config, password: 'hunter2');
      final media = await source.resolve(
        const MediaRef(sourceId: 'nc', itemId: '/Media/a.mkv', title: 'a.mkv'),
      );

      expect(media.uri.scheme, 'https');
      expect(media.headers['Authorization'], isNotNull);
      expect(media.kind, SourceKind.webdav);
      // Streaming straight from the server, with no local proxy in between.
      expect(media.sourceLine, contains('direct play'));
    });
  });
}
