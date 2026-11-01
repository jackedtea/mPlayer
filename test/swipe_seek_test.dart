// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mplayer/app/theme.dart';
import 'package:mplayer/features/player/gesture_layer.dart';
import 'package:mplayer/features/player/playback_state.dart';

void main() {
  group('how far a swipe seeks', () {
    const film = Duration(hours: 2);

    test('a fixed span per width, whatever the length of the file', () {
      // Tied to the file, this was an hour on a two-hour film.
      expect(
        swipeSeekTarget(
          start: const Duration(minutes: 30),
          dx: 400,
          width: 800,
          duration: film,
        ),
        const Duration(minutes: 30, seconds: 45),
      );
      expect(
        swipeSeekTarget(
          start: const Duration(minutes: 30),
          dx: -800,
          width: 800,
          duration: film,
        ),
        const Duration(minutes: 28, seconds: 30),
      );
    });

    test('stops at either end of the file', () {
      expect(
        swipeSeekTarget(
          start: const Duration(seconds: 20),
          dx: -800,
          width: 800,
          duration: film,
        ),
        Duration.zero,
      );
      expect(
        swipeSeekTarget(
          start: film - const Duration(seconds: 5),
          dx: 800,
          width: 800,
          duration: film,
        ),
        film,
      );
    });
  });

  testWidgets('the seek is made once, on release', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(900, 400);
    addTearDown(tester.view.reset);

    final seeks = <Duration>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.dark),
        home: GestureLayer(
          enabled: true,
          state: const PlaybackState(
            position: Duration(minutes: 10),
            duration: Duration(hours: 2),
          ),
          onTap: () {},
          onSeekBy: (_) {},
          onSeekTo: seeks.add,
          onVolume: (_) {},
        ),
      ),
    );

    final gesture = await tester.startGesture(const Offset(300, 200));
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(30, 0));
      await tester.pump();
    }
    // The pill says where it would land; nothing has moved yet.
    expect(seeks, isEmpty);
    expect(find.textContaining('+'), findsOneWidget);

    await gesture.up();
    await tester.pump(const Duration(seconds: 1));

    // 300 of 900 points is a third of the span, less the slop the drag
    // recogniser swallows before it claims the gesture.
    expect(seeks, hasLength(1));
    expect(seeks.single, greaterThan(const Duration(minutes: 10, seconds: 25)));
    expect(
      seeks.single,
      lessThanOrEqualTo(const Duration(minutes: 10, seconds: 30)),
    );
  });
}
