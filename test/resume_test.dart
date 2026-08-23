// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mplayer/core/models/media_models.dart';
import 'package:mplayer/core/resume_repository.dart';
import 'package:mplayer/core/thumbnail_store.dart';

ResumePoint point({
  String itemId = '/media/a.mkv',
  Duration position = const Duration(minutes: 10),
  Duration duration = const Duration(minutes: 100),
  DateTime? updatedAt,
}) {
  return ResumePoint(
    sourceId: 'device',
    itemId: itemId,
    title: itemId.split('/').last,
    kind: SourceKind.device,
    position: position,
    duration: duration,
    updatedAt: updatedAt ?? DateTime(2026, 2, 10),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ResumeRepository repo;
  late Directory thumbDir;
  late ThumbnailStore thumbnails;

  // A real directory under the system temp: the store writes files, and
  // asserting on what actually lands on disk is the point of these tests.
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    thumbDir = Directory.systemTemp.createTempSync('mplayer_thumbs');
    thumbnails = ThumbnailStore(directory: () async => thumbDir);
    repo = ResumeRepository(thumbnails: thumbnails);
  });

  tearDown(() {
    if (thumbDir.existsSync()) thumbDir.deleteSync(recursive: true);
  });

  final frame = Uint8List.fromList(<int>[0xFF, 0xD8, 0xFF, 0xD9]);

  List<String> thumbFiles() => thumbDir
      .listSync()
      .whereType<File>()
      .map((f) => f.uri.pathSegments.last)
      .toList();

  group('what gets kept', () {
    test('a normal position round-trips', () async {
      await repo.save(point());

      final saved = await repo.find('device', '/media/a.mkv');
      expect(saved, isNotNull);
      expect(saved!.position, const Duration(minutes: 10));
      expect(saved.progress, closeTo(0.1, 0.001));
    });

    test('a barely-started file is not shelved', () async {
      // A mis-tap should not fill the shelf with things nobody watched.
      await repo.save(point(position: const Duration(seconds: 30)));

      expect(await repo.load(), isEmpty);
    });

    test('a finished file is dropped rather than left at "1m left"', () async {
      await repo.save(point());
      expect(await repo.load(), hasLength(1));

      await repo.save(point(position: const Duration(minutes: 99)));

      expect(await repo.load(), isEmpty);
    });

    test('a file with no known duration is ignored', () async {
      // Duration arrives a moment after opening; writing before then would
      // store a meaningless 0% entry.
      await repo.save(point(duration: Duration.zero));

      expect(await repo.load(), isEmpty);
    });
  });

  group('the shelf', () {
    test('is newest first', () async {
      await repo.save(point(itemId: '/a.mkv', updatedAt: DateTime(2026, 1, 1)));
      await repo.save(point(itemId: '/b.mkv', updatedAt: DateTime(2026, 3, 1)));
      await repo.save(point(itemId: '/c.mkv', updatedAt: DateTime(2026, 2, 1)));

      expect(
        (await repo.load()).map((p) => p.itemId),
        <String>['/b.mkv', '/c.mkv', '/a.mkv'],
      );
    });

    test('re-watching moves an entry rather than duplicating it', () async {
      await repo.save(point(itemId: '/a.mkv', updatedAt: DateTime(2026, 1, 1)));
      await repo.save(point(itemId: '/b.mkv', updatedAt: DateTime(2026, 2, 1)));

      await repo.save(
        point(
          itemId: '/a.mkv',
          position: const Duration(minutes: 40),
          updatedAt: DateTime(2026, 3, 1),
        ),
      );

      final points = await repo.load();
      expect(points, hasLength(2));
      expect(points.first.itemId, '/a.mkv');
      expect(points.first.position, const Duration(minutes: 40));
    });

    test('is capped so it cannot grow without bound', () async {
      for (var i = 0; i < ResumeRepository.maxEntries + 10; i++) {
        await repo.save(
          point(
            itemId: '/clip$i.mkv',
            updatedAt: DateTime(2026, 1, 1).add(Duration(minutes: i)),
          ),
        );
      }

      final points = await repo.load();
      expect(points, hasLength(ResumeRepository.maxEntries));
      // The oldest fall off, not the newest.
      expect(points.first.itemId, '/clip59.mkv');
    });
  });

  group('thumbnails', () {
    test('a captured frame is written and pointed at by the entry', () async {
      await repo.save(point(), thumbnail: frame);

      final saved = await repo.find('device', '/media/a.mkv');
      expect(saved!.thumbnailPath, isNotNull);
      expect(File(saved.thumbnailPath!).readAsBytesSync(), frame);
    });

    test('a later write with no frame keeps the one already captured',
        () async {
      // The position is saved every few seconds and a frame only every so
      // often; the shelf must not flicker back to a gradient in between.
      await repo.save(point(), thumbnail: frame);
      final first = (await repo.find('device', '/media/a.mkv'))!.thumbnailPath;

      await repo.save(point(position: const Duration(minutes: 20)));

      final saved = await repo.find('device', '/media/a.mkv');
      expect(saved!.position, const Duration(minutes: 20));
      expect(saved.thumbnailPath, first);
    });

    test('removing an entry takes its frame with it', () async {
      await repo.save(point(), thumbnail: frame);
      expect(thumbFiles(), hasLength(1));

      await repo.remove('device', '/media/a.mkv');

      expect(thumbFiles(), isEmpty);
    });

    test('finishing a file drops its frame too', () async {
      await repo.save(point(), thumbnail: frame);

      await repo.save(point(position: const Duration(minutes: 99)));

      expect(await repo.load(), isEmpty);
      expect(thumbFiles(), isEmpty);
    });

    test('clear leaves nothing on disk', () async {
      await repo.save(point(itemId: '/a.mkv'), thumbnail: frame);
      await repo.save(point(itemId: '/b.mkv'), thumbnail: frame);

      await repo.clear();

      expect(thumbFiles(), isEmpty);
    });

    test('frames of entries pushed past the cap are swept', () async {
      for (var i = 0; i < ResumeRepository.maxEntries + 5; i++) {
        await repo.save(
          point(
            itemId: '/clip$i.mkv',
            updatedAt: DateTime(2026, 1, 1).add(Duration(minutes: i)),
          ),
          thumbnail: frame,
        );
      }

      expect(thumbFiles(), hasLength(ResumeRepository.maxEntries));
    });

    test('a missing directory costs the still, not the entry', () async {
      final broken = ResumeRepository(
        thumbnails: ThumbnailStore(
          directory: () async => throw const FileSystemException('nope'),
        ),
      );

      await broken.save(point(), thumbnail: frame);

      final saved = await broken.find('device', '/media/a.mkv');
      expect(saved, isNotNull);
      expect(saved!.thumbnailPath, isNull);
    });

    test('a stored path survives a reload', () async {
      await repo.save(point(), thumbnail: frame);
      final path = (await repo.find('device', '/media/a.mkv'))!.thumbnailPath;

      // A fresh repository over the same preferences — what a restart sees.
      final reloaded = await ResumeRepository(thumbnails: thumbnails).load();

      expect(reloaded.single.thumbnailPath, path);
    });
  });

  group('removal', () {
    test('remove takes one entry and leaves the rest', () async {
      await repo.save(point(itemId: '/a.mkv'));
      await repo.save(point(itemId: '/b.mkv'));

      await repo.remove('device', '/a.mkv');

      expect((await repo.load()).map((p) => p.itemId), <String>['/b.mkv']);
    });

    test('an unreadable entry does not hide the rest of the shelf', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'resume_points_v1': <String>['not json at all'],
      });

      expect(await ResumeRepository().load(), isEmpty);
    });
  });

  group('ResumePoint arithmetic', () {
    test('remaining never goes negative', () {
      final p = point(
        position: const Duration(minutes: 120),
        duration: const Duration(minutes: 100),
      );
      expect(p.remaining, Duration.zero);
      expect(p.progress, 1.0);
    });

    test('progress is zero when the duration is unknown', () {
      expect(point(duration: Duration.zero).progress, 0);
    });
  });
}
