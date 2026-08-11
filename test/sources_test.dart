// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:mplayer/core/models/library_models.dart';
import 'package:mplayer/core/models/media_models.dart';
import 'package:mplayer/sources/local_source.dart';
import 'package:mplayer/sources/media_source.dart';
import 'package:mplayer/sources/source_config.dart';

void main() {
  group('SourceConfig', () {
    const config = SourceConfig(
      id: 'nc_1',
      kind: SourceKind.webdav,
      name: 'Nextcloud',
      uri: 'https://dav.home.lan/dav',
      username: 'minh',
    );

    test('never serialises a password', () {
      final json = jsonEncode(config.toJson());

      // The whole point of splitting the stores: preferences are not a safe
      // place for credentials.
      expect(json.toLowerCase(), isNot(contains('password')));
      expect(json, isNot(contains('hunter2')));
      expect(config.toJson().keys, isNot(contains('password')));
    });

    test('round-trips through JSON', () {
      final restored = SourceConfig.fromJson(config.toJson());

      expect(restored.id, config.id);
      expect(restored.kind, SourceKind.webdav);
      expect(restored.name, 'Nextcloud');
      expect(restored.uri, config.uri);
      expect(restored.username, 'minh');
    });

    test('an unknown kind degrades instead of crashing startup', () {
      final restored = SourceConfig.fromJson(<String, dynamic>{
        'id': 'x',
        'kind': 'quantum_share',
        'name': 'Future',
        'uri': 'q://host',
      });

      expect(restored.kind, SourceKind.webdav);
      expect(restored.name, 'Future');
    });

    test('the credential key is derived from the stable id', () {
      expect(config.credentialKey, 'source_password_nc_1');
      // Renaming a share must not orphan its stored password.
      expect(
        config.copyWith(name: 'Renamed').credentialKey,
        config.credentialKey,
      );
    });

    test('a share without a username needs no auth', () {
      expect(config.needsAuth, isTrue);
      expect(config.copyWith(username: '').needsAuth, isFalse);
    });
  });

  group('classifyFile', () {
    test('recognises video, subtitle and everything else', () {
      expect(classifyFile('a.mkv'), BrowseEntryKind.video);
      expect(classifyFile('a.MP4'), BrowseEntryKind.video);
      expect(classifyFile('a.en.srt'), BrowseEntryKind.subtitle);
      expect(classifyFile('a.txt'), BrowseEntryKind.other);
      expect(classifyFile('README'), BrowseEntryKind.other);
      // A trailing dot has no extension to read.
      expect(classifyFile('weird.'), BrowseEntryKind.other);
    });
  });

  group('LocalSource.listDirectory', () {
    late Directory temp;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('mplayer_browse');
      await Directory('${temp.path}/Zebra folder').create();
      await Directory('${temp.path}/apple folder').create();
      await File('${temp.path}/clip.mkv').writeAsBytes(List<int>.filled(2048, 0));
      await File('${temp.path}/clip.en.srt').writeAsString('1');
      await File('${temp.path}/.hidden').writeAsString('x');
    });

    tearDown(() async {
      if (temp.existsSync()) await temp.delete(recursive: true);
    });

    test('lists folders first, then names case-insensitively', () async {
      final listing = await const LocalSource().listDirectory(temp.path);

      expect(
        listing.entries.map((e) => e.name),
        <String>['apple folder', 'Zebra folder', 'clip.en.srt', 'clip.mkv'],
      );
    });

    test('skips dot-files', () async {
      final listing = await const LocalSource().listDirectory(temp.path);
      expect(listing.entries.any((e) => e.name == '.hidden'), isFalse);
    });

    test('reports counts and sizes for the meta strip', () async {
      final listing = await const LocalSource().listDirectory(temp.path);

      expect(listing.folderCount, 2);
      expect(listing.fileCount, 2);
      expect(listing.totalBytes, greaterThanOrEqualTo(2048));
    });

    test('carries a usable path and kind on each row', () async {
      final listing = await const LocalSource().listDirectory(temp.path);
      final video = listing.entries.firstWhere((e) => e.name == 'clip.mkv');

      expect(video.kind, BrowseEntryKind.video);
      expect(video.path, contains('clip.mkv'));
      expect(video.sizeBytes, 2048);
      expect(File(video.path).existsSync(), isTrue);
    });

    test('a folder has no size, rather than zero', () async {
      final listing = await const LocalSource().listDirectory(temp.path);
      final folder = listing.entries.firstWhere((e) => e.isFolder);

      expect(folder.sizeBytes, isNull);
      expect(folder.detail, 'Folder');
    });

    test('a missing directory reports inline instead of crashing', () async {
      expect(
        () => const LocalSource().listDirectory('${temp.path}/nope'),
        throwsA(isA<MediaSourceException>()),
      );
    });
  });
}
