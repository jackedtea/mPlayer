// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mplayer/app/app.dart';
import 'package:mplayer/app/router.dart';
import 'package:mplayer/core/models/media_models.dart';
import 'package:mplayer/features/music/audio_session.dart';
import 'package:mplayer/features/music/mini_player.dart';
import 'package:mplayer/features/music/now_playing_page.dart';
import 'package:mplayer/features/player/playback_controller.dart';
import 'package:mplayer/features/player/playback_state.dart';
import 'package:mplayer/features/player/player_page.dart';
import 'package:mplayer/sources/media_source.dart';

/// The controller with no decoder behind it: it keeps the state a real one
/// would, and writes down what it was asked.
class _FakePlayback extends PlaybackController {
  final List<String> calls = <String>[];

  @override
  PlaybackState build() => const PlaybackState();

  void emit(PlaybackState next) => state = next;

  @override
  Future<void> openInstead(PlayableMedia media, {PlaybackQueue? queue}) async {
    calls.add('openInstead');
    state = state.copyWith(media: media, queue: queue, playing: true);
  }

  @override
  Future<void> openResolved(PlayableMedia media, {PlaybackQueue? queue}) async {
    calls.add('openResolved');
    state = state.copyWith(media: media, queue: queue, playing: true);
  }

  @override
  Future<void> loadSiblingQueue(MediaRef mediaRef) async {}

  @override
  Future<void> stop() async {
    calls.add('stop');
    state = const PlaybackState();
  }

  @override
  Future<void> playOrPause() async => calls.add('playOrPause');

  @override
  Future<void> restartCurrent() async => calls.add('restartCurrent');

  @override
  Future<void> playPrevious() async => calls.add('playPrevious');

  @override
  Future<void> playNext() async => calls.add('playNext');

  @override
  Future<void> seek(Duration to) async => calls.add('seek ${to.inSeconds}');
}

PlayableMedia _media({bool audio = true, String title = 'Song'}) =>
    PlayableMedia(
      ref: MediaRef(sourceId: 'p1', itemId: title, title: title),
      uri: Uri.parse('https://media.home.lan/stream'),
      kind: SourceKind.jellyfin,
      capabilities: const SourceCapabilities(),
      sourceLine: 'Jellyfin',
      isAudio: audio,
      artist: audio ? 'Daft Punk' : null,
    );

const _twoSongs = PlaybackQueue(
  items: <MediaRef>[
    MediaRef(sourceId: 'p1', itemId: 'Song', title: 'Song'),
    MediaRef(sourceId: 'p1', itemId: 'Other', title: 'Other'),
  ],
  kind: PlaybackQueueKind.music,
);

/// The app at [size], with a fake controller and a container to reach it by.
Future<(GoRouter, _FakePlayback, ProviderContainer)> _pump(
  WidgetTester tester, {
  Size size = const Size(400, 900),
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);

  final fake = _FakePlayback();
  final container = ProviderContainer(
    overrides: [playbackControllerProvider.overrideWith(() => fake)],
  );
  addTearDown(container.dispose);

  final router = buildRouter();
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MPlayerApp(router: router),
    ),
  );
  await tester.pumpAndSettle();
  return (router, fake, container);
}

Future<void> _play(
  WidgetTester tester,
  GoRouter router,
  ProviderContainer container, {
  PlaybackQueue? queue = _twoSongs,
}) async {
  await container
      .read(audioSessionProvider.notifier)
      .present(router, _media(), queue: queue);
  await tester.pumpAndSettle();
}

void main() {
  group('present', () {
    testWidgets('a song plays where the user is', (tester) async {
      final (router, fake, container) = await _pump(tester);
      router.go('/settings');
      await tester.pumpAndSettle();

      await _play(tester, router, container);

      expect(router.state.uri.path, '/settings');
      expect(fake.calls, <String>['openInstead']);
      expect(container.read(audioSessionProvider), isTrue);
    });

    testWidgets('a video goes to the player, and stops the music first', (
      tester,
    ) async {
      // One decoder. The stop has to land before the open, or the music's
      // teardown would take the film's decoder with it.
      final (router, fake, container) = await _pump(tester);
      await _play(tester, router, container);
      fake.calls.clear();

      await container
          .read(audioSessionProvider.notifier)
          .present(router, _media(audio: false, title: 'Dune'));
      // Not settled: the player's chrome runs a timer of its own.
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.byType(PlayerPage), findsOneWidget);
      expect(fake.calls, <String>['stop', 'openResolved']);
      expect(container.read(audioSessionProvider), isFalse);

      // Past the chrome's auto-hide, so no timer outlives the test.
      await tester.pump(const Duration(seconds: 4));
    });
  });

  group('ending', () {
    testWidgets('leaves nothing behind', (tester) async {
      final (router, fake, container) = await _pump(tester);
      await _play(tester, router, container);

      await container.read(audioSessionProvider.notifier).end();

      expect(fake.calls.last, 'stop');
      expect(container.read(audioSessionProvider), isFalse);
    });

    testWidgets('with no music is free', (tester) async {
      final (_, fake, container) = await _pump(tester);

      await container.read(audioSessionProvider.notifier).end();

      expect(fake.calls, isEmpty);
    });

    testWidgets('notices the controller stopped by something else', (
      tester,
    ) async {
      final (router, fake, container) = await _pump(tester);
      await _play(tester, router, container);

      await fake.stop();
      await tester.pump();

      expect(container.read(audioSessionProvider), isFalse);
      expect(find.byType(MiniPlayer), findsWidgets);
      expect(find.text('Song'), findsNothing);
    });
  });

  group('the transport', () {
    testWidgets('Previous restarts a song under way', (tester) async {
      final (router, fake, container) = await _pump(tester);
      await _play(tester, router, container);
      fake.calls.clear();

      fake.emit(
        fake.state.copyWith(
          queue: _twoSongs.stepTo(1),
          position: const Duration(seconds: 30),
        ),
      );
      await container.read(audioSessionProvider.notifier).previous();
      expect(fake.calls, <String>['seek 0']);
    });

    testWidgets('Previous goes back from a song only just begun', (
      tester,
    ) async {
      final (router, fake, container) = await _pump(tester);
      await _play(tester, router, container);
      fake.calls.clear();

      fake.emit(
        fake.state.copyWith(
          queue: _twoSongs.stepTo(1),
          position: const Duration(seconds: 1),
        ),
      );
      await container.read(audioSessionProvider.notifier).previous();
      expect(fake.calls, <String>['playPrevious']);
    });

    testWidgets('Play on a finished queue starts the last song again', (
      tester,
    ) async {
      final (router, fake, container) = await _pump(tester);
      await _play(tester, router, container);
      fake.calls.clear();

      fake.emit(fake.state.copyWith(completed: true, playing: false));
      await container.read(audioSessionProvider.notifier).togglePlaying();
      expect(fake.calls, <String>['restartCurrent']);
    });
  });

  group('the mini player', () {
    testWidgets('is absent with nothing playing', (tester) async {
      await _pump(tester);
      expect(find.byIcon(Icons.close_rounded), findsNothing);
    });

    testWidgets('sits above the navigation bar on a phone', (tester) async {
      final (router, _, container) = await _pump(tester);
      router.go('/settings');
      await tester.pumpAndSettle();
      await _play(tester, router, container);

      // Once, or the shell and the host would each be drawing one.
      expect(find.text('Song'), findsOneWidget);
      expect(
        tester.getBottomLeft(find.text('Song')).dy,
        lessThan(tester.getTopLeft(find.byType(NavigationBar)).dy),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('follows a song onto a screen above the shell', (tester) async {
      // Album and artist pages are reached over the shell, and they are where
      // a song is most often started from.
      final (router, _, container) = await _pump(tester);
      router.go('/settings');
      await tester.pumpAndSettle();
      router.push('/library/album');
      await tester.pumpAndSettle();

      await _play(tester, router, container);

      expect(find.text('Song'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    for (final Size size in const <Size>[Size(900, 1000), Size(1400, 900)]) {
      testWidgets('is drawn once at ${size.width.toInt()}', (tester) async {
        final (router, _, container) = await _pump(tester, size: size);
        router.go('/settings');
        await tester.pumpAndSettle();
        await _play(tester, router, container);

        expect(find.text('Song'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('opens Now playing, and steps aside for it', (tester) async {
      final (router, fake, container) = await _pump(tester);
      router.go('/settings');
      await tester.pumpAndSettle();
      await _play(tester, router, container);

      await tester.tap(find.text('Song'));
      await tester.pumpAndSettle();

      expect(find.byType(NowPlayingPage), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsNothing);

      // Leaving does not stop it.
      router.pop();
      await tester.pumpAndSettle();
      expect(fake.calls, isNot(contains('stop')));
      expect(find.text('Song'), findsOneWidget);
    });

    testWidgets('its close button ends the session', (tester) async {
      final (router, fake, container) = await _pump(tester);
      router.go('/settings');
      await tester.pumpAndSettle();
      await _play(tester, router, container);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(fake.calls.last, 'stop');
      expect(find.text('Song'), findsNothing);
    });
  });

  group('Now playing', () {
    for (final Size size in const <Size>[
      Size(400, 800),
      Size(320, 480),
      Size(800, 360),
      Size(900, 1000),
      Size(1400, 900),
    ]) {
      testWidgets('lays out at ${size.width.toInt()}x${size.height.toInt()}', (
        tester,
      ) async {
        final (router, _, container) = await _pump(tester, size: size);
        await _play(tester, router, container);
        router.push('/now-playing');
        await tester.pumpAndSettle();

        expect(find.text('Daft Punk'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('the queue is a sheet on a phone, and stands beside on a wide '
        'window', (tester) async {
      final (router, _, container) = await _pump(tester);
      await _play(tester, router, container);
      router.push('/now-playing');
      await tester.pumpAndSettle();

      expect(find.text('Other'), findsNothing);
      await tester.tap(find.byTooltip('Queue'));
      await tester.pumpAndSettle();
      expect(find.text('Other'), findsOneWidget);
    });

    testWidgets('keeps the queue beside the art on a wide window', (
      tester,
    ) async {
      final (router, _, container) = await _pump(
        tester,
        size: const Size(1400, 900),
      );
      await _play(tester, router, container);
      router.push('/now-playing');
      await tester.pumpAndSettle();

      expect(find.text('Other'), findsOneWidget);
      expect(find.byTooltip('Queue'), findsNothing);
    });
  });
}
