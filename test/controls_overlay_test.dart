// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mplayer/app/theme.dart';
import 'package:mplayer/core/models/media_models.dart';
import 'package:mplayer/features/player/controls_overlay.dart';
import 'package:mplayer/features/player/playback_state.dart';
import 'package:mplayer/features/player/player_ui_state.dart';
import 'package:mplayer/sources/media_source.dart';

PlayableMedia media({bool transcoding = false}) {
  return PlayableMedia(
    ref: const MediaRef(sourceId: 'device', itemId: '/a.mkv', title: 'Clip'),
    uri: Uri.parse('file:///a.mkv'),
    kind: SourceKind.device,
    capabilities: SourceCapabilities(transcoding: transcoding),
    sourceLine: 'Device',
  );
}

/// Pumps the chrome at a given size, as the player would.
Future<void> pumpControls(
  WidgetTester tester,
  Size size, {
  PlaybackState state = const PlaybackState(),
  bool transcoding = false,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(Brightness.dark),
      home: Scaffold(
        body: ControlsOverlay(
          media: media(transcoding: transcoding),
          state: state,
          ui: const PlayerUiState(),
          dragProgress: null,
          onInteraction: () {},
          onPlayPause: () {},
          onSkip: (_) {},
          onPrevious: () {},
          onNext: () {},
          onScrubStart: (_) {},
          onScrubUpdate: (_) {},
          onScrubEnd: (_) {},
          onSubtitles: () {},
          onAudio: () {},
          onQuality: () {},
          onSpeed: () {},
          onLock: () {},
          onRotate: () {},
          onChapters: () {},
          onFullscreen: () {},
          onMore: () {},
          onSkipIntro: (_) {},
          notImplemented: (_) {},
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('control row layout', () {
    testWidgets('portrait fits every control on one row without overflowing', (
      tester,
    ) async {
      await pumpControls(tester, const Size(400, 900));

      // The whole point of dropping the labels: one row, no overlap.
      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.subtitles_off_rounded), findsOneWidget);
      expect(find.byIcon(Icons.graphic_eq_rounded), findsOneWidget);
      expect(find.byIcon(Icons.speed_rounded), findsOneWidget);
      expect(find.byIcon(Icons.lock_open_rounded), findsOneWidget);
      expect(find.byIcon(Icons.fullscreen_rounded), findsOneWidget);
    });

    testWidgets('a narrow phone still does not overflow', (tester) async {
      await pumpControls(tester, const Size(320, 700));
      expect(tester.takeException(), isNull);
    });

    testWidgets('landscape keeps the labelled pills', (tester) async {
      await pumpControls(tester, const Size(900, 500));

      expect(tester.takeException(), isNull);
      // Labels are readable at this width, so they stay.
      expect(find.text('Off'), findsOneWidget);
      expect(find.text('1.0×'), findsOneWidget);
    });
  });

  group('state the icons have to carry', () {
    testWidgets('an active subtitle track changes the glyph', (tester) async {
      await pumpControls(
        tester,
        const Size(400, 900),
        state: const PlaybackState(
          activeSubtitle: MediaTrack(
            id: '2',
            kind: TrackKind.subtitle,
            label: 'English',
          ),
        ),
      );

      expect(find.byIcon(Icons.subtitles_rounded), findsOneWidget);
      expect(find.byIcon(Icons.subtitles_off_rounded), findsNothing);
    });

    testWidgets('a non-default speed is visible without a label', (
      tester,
    ) async {
      await pumpControls(
        tester,
        const Size(400, 900),
        state: const PlaybackState(speed: 1.5),
      );

      // Playing at 1.5x is easy to forget; the tint is the only cue left.
      final icon = tester.widget<Icon>(
        find.descendant(
          of: find.byTooltip('Speed: 1.50×'),
          matching: find.byIcon(Icons.speed_rounded),
        ),
      );
      expect(icon.color, isNot(Colors.white));
    });
  });

  group('quality', () {
    testWidgets('is hidden for a source that cannot transcode', (tester) async {
      await pumpControls(tester, const Size(400, 900));
      expect(find.byIcon(Icons.hd_rounded), findsNothing);
    });

    testWidgets('appears when the source can transcode', (tester) async {
      await pumpControls(tester, const Size(400, 900), transcoding: true);
      expect(find.byIcon(Icons.hd_rounded), findsOneWidget);
    });
  });
}
