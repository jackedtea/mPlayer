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
import 'package:mplayer/features/servers/server_library.dart';
import 'package:mplayer/servers/media_library_source.dart';

class _Server extends FakeLibrarySource {
  const _Server({this.full = true});

  /// False: a series the server says almost nothing about.
  final bool full;

  @override
  Future<ServerItem> item(String itemId) async => full
      ? ServerItem(
          id: 's1',
          title: 'High School DxD',
          kind: ServerItemKind.series,
          year: 2012,
          endYear: 2018,
          runtime: const Duration(minutes: 24),
          status: 'Ended',
          premiereDate: DateTime(2012, 1, 6),
          studios: const <String>['TNK'],
        )
      : const ServerItem(
          id: 's1',
          title: 'High School DxD',
          kind: ServerItemKind.series,
        );

  @override
  Future<List<ServerItem>> episodes(
    String seriesId, {
    String? seasonId,
  }) async => const <ServerItem>[
    ServerItem(
      id: 'e1',
      title: 'Pilot',
      kind: ServerItemKind.episode,
      seasonNumber: 1,
      episodeNumber: 1,
    ),
  ];
}

Future<void> _open(WidgetTester tester, MediaLibrarySource server) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(400, 900);
  addTearDown(tester.view.reset);

  final router = buildRouter();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [activeServerProvider.overrideWithValue(server)],
      child: MPlayerApp(router: router),
    ),
  );
  await tester.pumpAndSettle();
  router.push('/library/series', extra: 's1');
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the header says how long an episode is and whether it ended', (
    tester,
  ) async {
    await _open(tester, const _Server());

    expect(find.text('2012 - 2018'), findsOneWidget);
    expect(find.text('24m'), findsOneWidget);
    expect(find.text('Ended'), findsOneWidget);
  });

  testWidgets('About adds when it first aired and the episode length', (
    tester,
  ) async {
    await _open(tester, const _Server());

    await tester.tap(find.text('About'));
    await tester.pumpAndSettle();

    expect(find.text('First aired'), findsOneWidget);
    expect(find.text('Jan 6, 2012'), findsOneWidget);
    expect(find.text('Episode length'), findsOneWidget);
    expect(find.text('TNK'), findsOneWidget);
  });

  testWidgets('nothing the server left out is drawn', (tester) async {
    await _open(tester, const _Server(full: false));

    expect(find.text('Ended'), findsNothing);
    expect(find.text('24m'), findsNothing);
    await tester.tap(find.text('About'));
    await tester.pumpAndSettle();
    expect(find.text('First aired'), findsNothing);
    expect(find.text('Episode length'), findsNothing);
  });
}
