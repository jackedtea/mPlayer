// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter_test/flutter_test.dart';
import 'package:mplayer/features/player/silent_end.dart';

void main() {
  const duration = Duration(minutes: 24);

  bool ended(Duration position, {bool paused = false, Duration? of}) =>
      endedSilently(
        position: position,
        duration: of ?? duration,
        pausedByUser: paused,
      );

  test('standing still on the last frame is the end', () {
    expect(ended(duration), isTrue);
    expect(ended(duration - const Duration(milliseconds: 300)), isTrue);
  });

  test('a runtime a few seconds longer than the picture still ends', () {
    expect(ended(duration - const Duration(seconds: 6)), isTrue);
    expect(ended(duration - silentEndWindow), isTrue);
  });

  test('a stall anywhere earlier is buffering, not the end', () {
    expect(ended(duration - const Duration(seconds: 11)), isFalse);
    expect(ended(const Duration(minutes: 12)), isFalse);
  });

  test('a pause by hand on the last frame stays there', () {
    expect(ended(duration, paused: true), isFalse);
  });

  test('a file whose length is not known yet has not ended', () {
    expect(ended(Duration.zero, of: Duration.zero), isFalse);
  });

  test('the decoder gets the first chance to report the end itself', () {
    expect(silentEndStall, greaterThanOrEqualTo(const Duration(seconds: 3)));
  });
}
