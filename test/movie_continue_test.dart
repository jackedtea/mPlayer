// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_library_source.dart';

import 'package:mplayer/app/app.dart';
import 'package:mplayer/app/router.dart';
import 'package:mplayer/features/player/playback_state.dart';
import 'package:mplayer/features/servers/server_library.dart';
import 'package:mplayer/servers/media_library_source.dart';

class _Server extends FakeLibrarySource {
  _Server(this.position);

  Duration? position;

  @override
  Future<ServerItem> item(String itemId) async => ServerItem(
    id: itemId,
    title: 'Arrival',
    kind: ServerItemKind.movie,
    runtime: const Duration(hours: 2),
    position: position,
  );
}

Future<ProviderContainer> _pump(
  WidgetTester tester,
  MediaLibrarySource server,
  Size size,
) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);

  final router = buildRouter();
  final container = ProviderContainer(
    overrides: [activeServerProvider.overrideWithValue(server)],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MPlayerApp(router: router),
    ),
  );
  await tester.pumpAndSettle();
  router.push('/library/movie', extra: 'm1');
  await tester.pumpAndSettle();
  return container;
}

void main() {
  const position = Duration(hours: 1, minutes: 2, seconds: 45);

  for (final (String name, Size size) in const <(String, Size)>[
    ('phone', Size(400, 800)),
    ('wide window', Size(1300, 900)),
  ]) {
    group(name, () {
      testWidgets('a started film offers to continue, and from where', (
        tester,
      ) async {
        await _pump(tester, _Server(position), size);

        expect(
          find.widgetWithText(FilledButton, 'Continue · 1:02:45'),
          findsOneWidget,
        );
        expect(find.widgetWithText(FilledButton, 'Play'), findsNothing);
        // Said once, on the button.
        expect(find.text('Continue · 1:02:45'), findsOneWidget);
      });

      testWidgets('an unstarted film offers to play', (tester) async {
        await _pump(tester, _Server(null), size);

        expect(find.widgetWithText(FilledButton, 'Play'), findsOneWidget);
        expect(find.textContaining('Continue'), findsNothing);
      });

      testWidgets('coming back from the player shows where it stopped', (
        tester,
      ) async {
        final server = _Server(null);
        final container = await _pump(tester, server, size);
        expect(find.widgetWithText(FilledButton, 'Play'), findsOneWidget);

        server.position = position;
        container.read(playbackStopsProvider.notifier).record('m1');
        await tester.pumpAndSettle();

        expect(
          find.widgetWithText(FilledButton, 'Continue · 1:02:45'),
          findsOneWidget,
        );
      });
    });
  }
}
