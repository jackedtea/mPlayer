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

/// Two libraries with something new in each, and a film left half-watched.
class _HomeServer extends FakeLibrarySource {
  _HomeServer({Set<String> excludes = const <String>{}})
      : excludes = <String>{...excludes};

  final Set<String> excludes;
  final List<Set<String>> saved = <Set<String>>[];

  @override
  Future<List<LibraryView>> views() async => const <LibraryView>[
        LibraryView(id: 'films', name: 'Films', kind: 'movies'),
        LibraryView(id: 'tv', name: 'Television', kind: 'tvshows'),
        // Assembled by the user, not added by the server: no row.
        LibraryView(id: 'sets', name: 'Collections', kind: 'boxsets'),
      ];

  @override
  Future<List<ServerItem>> resumable({int limit = 12, String? viewId}) async =>
      const <ServerItem>[
        ServerItem(
          id: 'r1',
          title: 'Half watched',
          kind: ServerItemKind.movie,
          runtime: Duration(minutes: 100),
          position: Duration(minutes: 40),
        ),
      ];

  @override
  Future<List<ServerItem>> items(
    String viewId, {
    int startIndex = 0,
    int limit = 100,
    ServerSort sort = ServerSort.name,
    SortOrder? order,
    LibraryFilter filter = LibraryFilter.none,
  }) async =>
      <ServerItem>[
        ServerItem(id: 'new-$viewId', title: 'New in $viewId'),
      ];

  @override
  Future<Set<String>> homeExcludes() async => excludes;

  @override
  Future<void> setHomeExcludes(Set<String> viewIds) async {
    saved.add(viewIds);
  }
}

Future<void> _pump(WidgetTester tester, Size size, _HomeServer server) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [activeServerProvider.overrideWithValue(server)],
      child: MPlayerApp(router: buildRouter()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final Size size in const <Size>[
    Size(400, 900),
    Size(900, 1000),
    Size(1400, 900),
  ]) {
    testWidgets('lays out at ${size.width.toInt()}px', (tester) async {
      await _pump(tester, size, _HomeServer());

      expect(tester.takeException(), isNull);
      expect(find.byType(CarouselView), findsOneWidget);
      expect(find.text('Half watched'), findsOneWidget);
      expect(find.text('Recently added in Films'), findsOneWidget);
      expect(find.text('Recently added in Television'), findsOneWidget);
      expect(find.text('Recently added in Collections'), findsNothing);
    });
  }

  testWidgets('a library hidden on the server has no row', (tester) async {
    await _pump(tester, const Size(400, 900), _HomeServer(excludes: {'tv'}));

    expect(find.text('Recently added in Films'), findsOneWidget);
    expect(find.text('Recently added in Television'), findsNothing);
  });

  testWidgets('hiding a library saves the list to the server', (tester) async {
    final server = _HomeServer();
    await _pump(tester, const Size(400, 900), server);

    await tester.tap(find.byTooltip('Customize home'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(SwitchListTile, 'Television'));
    await tester.pumpAndSettle();

    expect(server.saved.single, <String>{'tv'});
    expect(find.text('Recently added in Television'), findsNothing);
  });
}
