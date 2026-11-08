// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter_test/flutter_test.dart';
import 'package:mplayer/features/player/playback_state.dart';
import 'package:mplayer/sources/media_source.dart';

const _chapters = <MediaChapter>[
  // Out of order on purpose: a container need not list them by start.
  MediaChapter(
    title: 'Part B',
    start: Duration(minutes: 12),
    end: Duration(minutes: 24),
  ),
  MediaChapter(title: 'Opening', start: Duration.zero, end: Duration(minutes: 2)),
  MediaChapter(
    title: 'Part A',
    start: Duration(minutes: 2),
    end: Duration(minutes: 12),
  ),
];

PlaybackState _at(Duration position, {List<MediaChapter> chapters = _chapters}) =>
    PlaybackState(position: position, containerChapters: chapters);

void main() {
  group('next chapter', () {
    test('is where the following one begins', () {
      expect(
        _at(const Duration(minutes: 5)).nextChapterStart(),
        const Duration(minutes: 12),
      );
      expect(
        _at(Duration.zero).nextChapterStart(),
        const Duration(minutes: 2),
      );
    });

    test('from the very start of a chapter is the one after it', () {
      expect(
        _at(const Duration(minutes: 2)).nextChapterStart(),
        const Duration(minutes: 12),
      );
    });

    test('is nothing in the last chapter', () {
      expect(_at(const Duration(minutes: 20)).nextChapterStart(), isNull);
    });
  });

  group('previous chapter', () {
    test('well into a chapter, starts it again', () {
      expect(
        _at(const Duration(minutes: 5)).previousChapterStart(),
        const Duration(minutes: 2),
      );
    });

    test('just after a chapter began, goes back one', () {
      expect(
        _at(const Duration(minutes: 12, seconds: 2)).previousChapterStart(),
        const Duration(minutes: 2),
      );
    });

    test('in the first chapter, goes to the start', () {
      expect(
        _at(const Duration(seconds: 1)).previousChapterStart(),
        Duration.zero,
      );
      expect(
        _at(const Duration(minutes: 1)).previousChapterStart(),
        Duration.zero,
      );
    });
  });

  test('one chapter or none has nothing to step between', () {
    final one = _at(
      const Duration(minutes: 5),
      chapters: const <MediaChapter>[
        MediaChapter(
          title: 'All',
          start: Duration.zero,
          end: Duration(minutes: 24),
        ),
      ],
    );
    expect(one.nextChapterStart(), isNull);
    expect(one.previousChapterStart(), isNull);
    expect(_at(Duration.zero, chapters: const []).nextChapterStart(), isNull);
  });
}
