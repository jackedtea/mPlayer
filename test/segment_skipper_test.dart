// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter_test/flutter_test.dart';

import 'package:mplayer/features/player/segment_skipper.dart';
import 'package:mplayer/features/settings/player_settings.dart';
import 'package:mplayer/servers/media_library_source.dart';

const _intro = MediaSegment(
  kind: MediaSegmentKind.intro,
  start: Duration(seconds: 60),
  end: Duration(seconds: 150),
);

const _outro = MediaSegment(
  kind: MediaSegmentKind.outro,
  start: Duration(minutes: 22),
  end: Duration(minutes: 24),
);

/// Everything set to skip itself, which is the setting under test.
SegmentAction _skipEverything(MediaSegmentKind _) => SegmentAction.skip;

MediaSegment? decide({
  List<MediaSegment> segments = const <MediaSegment>[_intro, _outro],
  Duration? previous,
  required Duration now,
  SegmentAction Function(MediaSegmentKind) actionFor = _skipEverything,
  Set<MediaSegment> alreadySkipped = const <MediaSegment>{},
}) {
  return segmentToSkip(
    segments: segments,
    previous: previous,
    now: now,
    actionFor: actionFor,
    alreadySkipped: alreadySkipped,
  );
}

void main() {
  group('playing into a segment', () {
    test('the tick that crosses the start is the one that skips', () {
      expect(
        decide(
          previous: const Duration(seconds: 59, milliseconds: 800),
          now: const Duration(seconds: 60, milliseconds: 100),
        ),
        _intro,
      );
    });

    test('a later tick inside the same segment does nothing', () {
      // The crossing already happened; acting again would seek a viewer who
      // rewound a few seconds on purpose.
      expect(
        decide(
          previous: const Duration(seconds: 70),
          now: const Duration(seconds: 70, milliseconds: 300),
        ),
        isNull,
      );
    });

    test('a segment starting at zero is crossed on the first real tick', () {
      // The commonest intro there is, and the one an "is the start greater
      // than zero" guard would silently drop.
      const opening = MediaSegment(
        kind: MediaSegmentKind.intro,
        start: Duration.zero,
        end: Duration(seconds: 90),
      );

      expect(
        decide(
          segments: const <MediaSegment>[opening],
          previous: const Duration(milliseconds: -1),
          now: Duration.zero,
        ),
        opening,
      );
    });
  });

  group('seeking into a segment', () {
    test('a jump into the middle of one is left alone', () {
      // Someone who dragged the scrubber into the opening titles meant to be
      // there.
      expect(
        decide(previous: Duration.zero, now: const Duration(seconds: 90)),
        isNull,
      );
    });

    test('a jump that lands exactly on the start is still a jump', () {
      expect(
        decide(previous: Duration.zero, now: const Duration(seconds: 60)),
        isNull,
      );
    });

    test('seeking backwards never skips', () {
      expect(
        decide(
          previous: const Duration(minutes: 5),
          now: const Duration(seconds: 61),
        ),
        isNull,
      );
    });

    test('the first tick of a file has nothing to compare against', () {
      // A film resuming at 22 minutes would otherwise look like it had just
      // played into the closing credits.
      expect(decide(previous: null, now: const Duration(minutes: 22)), isNull);
    });
  });

  group('what the user asked for', () {
    test('a kind set to be offered is left for the pill', () {
      expect(
        decide(
          previous: const Duration(seconds: 59),
          now: const Duration(seconds: 61),
          actionFor: (_) => SegmentAction.askToSkip,
        ),
        isNull,
      );
    });

    test('a kind set to nothing is watched', () {
      expect(
        decide(
          previous: const Duration(seconds: 59),
          now: const Duration(seconds: 61),
          actionFor: (_) => SegmentAction.nothing,
        ),
        isNull,
      );
    });

    test('only the kind that was set to skip is skipped', () {
      SegmentAction outroOnly(MediaSegmentKind kind) =>
          kind == MediaSegmentKind.outro
              ? SegmentAction.skip
              : SegmentAction.nothing;

      expect(
        decide(
          previous: const Duration(seconds: 59),
          now: const Duration(seconds: 61),
          actionFor: outroOnly,
        ),
        isNull,
      );
      expect(
        decide(
          previous: const Duration(minutes: 21, seconds: 59),
          now: const Duration(minutes: 22, seconds: 1),
          actionFor: outroOnly,
        ),
        _outro,
      );
    });
  });

  group('guards', () {
    test('a segment already skipped is not skipped again', () {
      // An auto-skip lands a millisecond from still being inside the segment.
      expect(
        decide(
          previous: const Duration(seconds: 59),
          now: const Duration(seconds: 61),
          alreadySkipped: <MediaSegment>{_intro},
        ),
        isNull,
      );
    });

    test('a stretch too short to be worth the stall is left alone', () {
      const blink = MediaSegment(
        kind: MediaSegmentKind.intro,
        start: Duration(seconds: 60),
        end: Duration(seconds: 60, milliseconds: 400),
      );

      expect(
        decide(
          segments: const <MediaSegment>[blink],
          previous: const Duration(seconds: 59),
          now: const Duration(seconds: 61),
        ),
        isNull,
      );
    });

    test('a file with no segments decides nothing', () {
      expect(
        decide(
          segments: const <MediaSegment>[],
          previous: const Duration(seconds: 59),
          now: const Duration(seconds: 61),
        ),
        isNull,
      );
    });
  });
}
