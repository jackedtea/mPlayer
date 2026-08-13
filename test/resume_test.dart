// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mplayer/core/models/media_models.dart';
import 'package:mplayer/core/resume_repository.dart';

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

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    repo = ResumeRepository();
  });

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
