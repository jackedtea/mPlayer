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

/// A film library with two films and one box set, and a record of what was
/// put into which collection.
class _Server extends FakeLibrarySource {
  final added = <String, List<String>>{};

  @override
  Future<List<LibraryView>> views() async => const <LibraryView>[
    LibraryView(id: 'v1', name: 'Films', kind: 'movies'),
  ];

  @override
  Future<int> itemCount(String viewId, {bool groupCollections = false}) async =>
      3;

  @override
  Future<List<ServerItem>> items(
    String viewId, {
    int startIndex = 0,
    int limit = 100,
    ServerSort sort = ServerSort.name,
    SortOrder? order,
    LibraryFilter filter = LibraryFilter.none,
    bool groupCollections = false,
  }) async => const <ServerItem>[
    ServerItem(id: 'm1', title: 'Part One', kind: ServerItemKind.movie),
    ServerItem(id: 'm2', title: 'Part Two', kind: ServerItemKind.movie),
    ServerItem(id: 's1', title: 'The Saga', kind: ServerItemKind.collection),
  ];

  @override
  Future<List<ServerItem>> allCollections() async => const <ServerItem>[
    ServerItem(
      id: 'c1',
      title: 'Favourites Box',
      kind: ServerItemKind.collection,
    ),
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
  router.push('/library', extra: 'v1');
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a long press on a film offers play, select and both lists', (
    tester,
  ) async {
    await _pump(tester, _Server());

    await tester.longPress(find.text('Part One'));
    await tester.pumpAndSettle();

    expect(find.text('Play'), findsOneWidget);
    // Nothing to shuffle in one film.
    expect(find.text('Shuffle'), findsNothing);
    expect(find.text('Select'), findsOneWidget);
    expect(find.text('Add to collection'), findsOneWidget);
    expect(find.text('Add to playlist'), findsOneWidget);
  });

  testWidgets('a collection shuffles, and is not put into another one', (
    tester,
  ) async {
    await _pump(tester, _Server());

    await tester.longPress(find.text('The Saga'));
    await tester.pumpAndSettle();

    expect(find.text('Play'), findsOneWidget);
    expect(find.text('Shuffle'), findsOneWidget);
    expect(find.text('Add to collection'), findsNothing);
  });

  testWidgets('Select starts multi-select; taps toggle; back leaves it', (
    tester,
  ) async {
    await _pump(tester, _Server());

    await tester.longPress(find.text('Part One'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);

    // A tap now picks rather than opens.
    await tester.tap(find.text('Part Two'));
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsOneWidget);

    await tester.tap(find.text('Part Two'));
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);

    // Back clears the selection rather than leaving the library.
    final handled = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(handled, isTrue);
    expect(find.textContaining('selected'), findsNothing);
    expect(find.text('Part One'), findsOneWidget);
  });

  testWidgets('the selection goes into a collection together', (tester) async {
    final server = _Server();
    await _pump(tester, server);

    await tester.longPress(find.text('Part One'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Part Two'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Add to collection'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Favourites Box'));
    await tester.pumpAndSettle();

    expect(server.added['c1'], <String>['m1', 'm2']);
    expect(find.text('Added to Favourites Box'), findsOneWidget);
  });
}
