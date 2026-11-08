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

/// A series of two seasons, three episodes each, and a record of what went
/// into which collection.
class _Server extends FakeLibrarySource {
  final added = <String, List<String>>{};

  @override
  Future<ServerItem> item(String itemId) async => const ServerItem(
    id: 's1',
    title: 'The Show',
    kind: ServerItemKind.series,
  );

  @override
  Future<List<ServerItem>> episodes(
    String seriesId, {
    String? seasonId,
  }) async => <ServerItem>[
    for (var s = 1; s <= 2; s++)
      for (var e = 1; e <= 3; e++)
        ServerItem(
          id: 's${s}e$e',
          title: 'Episode $e',
          kind: ServerItemKind.episode,
          seriesId: 's1',
          seasonId: 'season$s',
          seasonNumber: s,
          episodeNumber: e,
        ),
  ];

  @override
  Future<List<ServerItem>> allCollections() async => const <ServerItem>[
    ServerItem(id: 'c1', title: 'Box', kind: ServerItemKind.collection),
  ];

  @override
  Future<void> addToCollection(
    String collectionId,
    List<String> itemIds,
  ) async {
    added[collectionId] = itemIds;
  }
}

Future<void> _pump(WidgetTester tester, MediaLibrarySource server) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(600, 1000);
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
  testWidgets('a long press on a season tab opens its menu', (tester) async {
    await _pump(tester, _Server());

    await tester.longPress(find.text('Season 1'));
    await tester.pumpAndSettle();

    expect(find.text('Play'), findsWidgets);
    expect(find.text('Play all from here'), findsOneWidget);
    expect(find.text('Shuffle'), findsOneWidget);
    expect(find.text('Add to collection'), findsOneWidget);
    expect(find.text('Add to playlist'), findsOneWidget);
    expect(find.text('Download all'), findsOneWidget);
  });

  testWidgets('the last season has nothing after it to play on into', (
    tester,
  ) async {
    await _pump(tester, _Server());

    await tester.longPress(find.text('Season 2'));
    await tester.pumpAndSettle();

    expect(find.text('Shuffle'), findsOneWidget);
    expect(find.text('Play all from here'), findsNothing);
  });

  testWidgets('a season goes into a collection as the season', (tester) async {
    final server = _Server();
    await _pump(tester, server);

    await tester.longPress(find.text('Season 2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add to collection'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Box'));
    await tester.pumpAndSettle();

    expect(server.added['c1'], <String>['season2']);
  });

  testWidgets('About has no menu, and a tap still switches tabs', (
    tester,
  ) async {
    await _pump(tester, _Server());

    await tester.longPress(find.text('About'));
    await tester.pumpAndSettle();
    expect(find.text('Shuffle'), findsNothing);

    await tester.tap(find.text('Season 2'));
    await tester.pumpAndSettle();
    final bar = tester.widget<TabBar>(find.byType(TabBar));
    expect(bar.controller!.index, 1);
  });

  group('selecting episodes', () {
    testWidgets('Select on a season picks all of it', (tester) async {
      await _pump(tester, _Server());

      await tester.longPress(find.text('Season 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select'));
      await tester.pumpAndSettle();

      expect(find.text('3 selected'), findsOneWidget);
      expect(find.byType(Checkbox), findsNWidgets(3));
    });

    testWidgets('Select on an episode starts with it; taps pick; back clears', (
      tester,
    ) async {
      await _pump(tester, _Server());

      await tester.longPress(find.text('1. Episode 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select'));
      await tester.pumpAndSettle();
      expect(find.text('1 selected'), findsOneWidget);

      // A tap picks rather than opening the episode.
      await tester.tap(find.text('2. Episode 2'));
      await tester.pumpAndSettle();
      expect(find.text('2 selected'), findsOneWidget);

      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();
      expect(find.text('1 selected'), findsOneWidget);

      final handled = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(handled, isTrue);
      expect(find.textContaining('selected'), findsNothing);
      expect(find.byType(Checkbox), findsNothing);
      // Still on the series.
      expect(find.text('Season 1'), findsOneWidget);
    });

    testWidgets('the picked episodes go into a collection together', (
      tester,
    ) async {
      final server = _Server();
      await _pump(tester, server);

      await tester.longPress(find.text('1. Episode 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('3. Episode 3'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Add to collection'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Box'));
      await tester.pumpAndSettle();

      expect(server.added['c1'], <String>['s1e1', 's1e3']);
    });

    testWidgets('the bar fits a narrow phone', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(320, 700);
      addTearDown(tester.view.reset);

      final router = buildRouter();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [activeServerProvider.overrideWithValue(_Server())],
          child: MPlayerApp(router: router),
        ),
      );
      await tester.pumpAndSettle();
      router.push('/library/series', extra: 's1');
      await tester.pumpAndSettle();

      await tester.longPress(find.text('Season 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select'));
      await tester.pumpAndSettle();

      expect(find.text('3 selected'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
