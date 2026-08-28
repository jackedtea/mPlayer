// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mplayer/app/theme.dart';
import 'package:mplayer/l10n/app_localizations.dart';
import 'package:mplayer/core/models/media_models.dart';
import 'package:mplayer/features/player/controls_overlay.dart';
import 'package:mplayer/features/player/stable_insets.dart';
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
  double bottomInset = 0,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  tester.view.padding = FakeViewPadding(bottom: bottomInset);
  tester.view.viewPadding = FakeViewPadding(bottom: bottomInset);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(Brightness.dark),
      // The chrome reads its labels from AppLocalizations now, so the
      // harness has to supply them the way the real app does.
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: StableInsets(
        child: Scaffold(
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
    ),
  );
  await tester.pump();
}

void main() {
  group('skip intro', () {
    testWidgets('is a pill against the right edge, not a bar', (tester) async {
      const width = 900.0;
      await pumpControls(
        tester,
        const Size(width, 500),
        state: PlaybackState(
          media: media(),
          duration: const Duration(minutes: 24),
          position: const Duration(seconds: 30),
          containerChapters: const <MediaChapter>[
            MediaChapter(
              title: 'Intro',
              start: Duration.zero,
              end: Duration(seconds: 90),
              isIntro: true,
            ),
          ],
        ),
      );

      final pill = find.text('Skip intro');
      expect(pill, findsOneWidget);

      // A Container with an alignment expands to whatever it is given, which
      // once stretched this across the whole screen.
      final box = tester.getRect(
        find.ancestor(of: pill, matching: find.byType(Material)).first,
      );
      expect(box.width, lessThan(width / 3));
      // And it sits at the right, where the design puts it.
      expect(box.right, greaterThan(width * 0.6));
    });
  });

  group('buffered range', () {
    testWidgets('a partly buffered stream draws the read-ahead track',
        (tester) async {
      await pumpControls(
        tester,
        const Size(900, 500),
        state: const PlaybackState(
          duration: Duration(minutes: 10),
          position: Duration(minutes: 1),
          buffered: Duration(minutes: 3),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter.runtimeType.toString()
              .contains('_BufferedTrack'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a local file with nothing buffered draws none',
        (tester) async {
      // Zero is the honest answer for a file already on disk, and an empty
      // bar reads as a stream that has stalled.
      await pumpControls(
        tester,
        const Size(900, 500),
        state: const PlaybackState(duration: Duration(minutes: 10)),
      );

      expect(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter.runtimeType.toString()
              .contains('_BufferedTrack'),
        ),
        findsNothing,
      );
    });
  });

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

  group('loading', () {
    testWidgets('the play button becomes a spinner while buffering', (
      tester,
    ) async {
      await pumpControls(
        tester,
        const Size(400, 900),
        state: const PlaybackState(buffering: true, playing: true),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.pause_rounded), findsNothing);
      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);

      // The rest of the transport stays usable — only the centre slot swaps.
      expect(find.byIcon(Icons.replay_10_rounded), findsOneWidget);
      expect(find.byIcon(Icons.forward_30_rounded), findsOneWidget);
    });

    testWidgets('the spinner keeps the play button footprint', (tester) async {
      await pumpControls(tester, const Size(400, 900));
      final playing = tester.getRect(find.byIcon(Icons.play_arrow_rounded));

      await pumpControls(
        tester,
        const Size(400, 900),
        state: const PlaybackState(buffering: true),
      );

      // Same centre: the row must not shuffle sideways when loading ends.
      expect(
        tester.getRect(find.byType(CircularProgressIndicator)).center,
        playing.center,
      );
    });

    testWidgets('a failed file shows its error, not a spinner', (tester) async {
      await pumpControls(
        tester,
        const Size(400, 900),
        state: const PlaybackState(buffering: true, error: 'nope'),
      );

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
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

  group('a navigation bar that comes and goes', () {
    testWidgets('does not move the controls', (tester) async {
      // Sticky immersion slides the bar in on a swipe and out again by
      // itself, and Android reports the bottom inset going to full height and
      // back each time. The control row is laid out against that inset and
      // the Skip intro pill sits on top of the row, so both used to jump up
      // the screen and drop back while the film played.
      final intro = PlaybackState(
        media: media(),
        position: const Duration(seconds: 20),
        duration: const Duration(minutes: 24),
        containerChapters: const <MediaChapter>[
          MediaChapter(
            title: 'Opening',
            start: Duration.zero,
            end: Duration(seconds: 90),
            isIntro: true,
          ),
        ],
      );

      // Opened with the bar showing, which is how the player is reached.
      await pumpControls(
        tester,
        const Size(900, 500),
        state: intro,
        bottomInset: 56,
      );
      final shown = tester.getRect(find.text('Skip intro'));

      // Immersion takes it away.
      await pumpControls(
        tester,
        const Size(900, 500),
        state: intro,
        bottomInset: 0,
      );
      final hidden = tester.getRect(find.text('Skip intro'));

      expect(
        hidden,
        shown,
        reason: 'the pill moved when the navigation bar did',
      );
    });
  });
}
