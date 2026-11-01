// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_library_source.dart';

import 'package:mplayer/app/app.dart';
import 'package:mplayer/features/home/favorites_page.dart';
import 'package:mplayer/features/servers/server_library.dart';
import 'package:mplayer/servers/media_library_source.dart';

/// A starred film, show and episode, a starred actor, one library.
class _Server extends FakeLibrarySource {
  const _Server({this.none = false});

  final bool none;

  @override
  Future<List<LibraryView>> views() async => const <LibraryView>[
        LibraryView(id: 'films', name: 'Films', kind: 'movies'),
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
      const <ServerItem>[
        ServerItem(id: 'new1', title: 'Just added', kind: ServerItemKind.movie),
      ];

  @override
  Future<List<ServerItem>> nextUp({int limit = 12, String? viewId}) async =>
      const <ServerItem>[
        ServerItem(id: 'n1', title: 'Next one', kind: ServerItemKind.episode),
      ];

  @override
  Future<List<ServerItem>> favouriteItems({
    Set<ServerItemKind> kinds = const <ServerItemKind>{
      ServerItemKind.movie,
      ServerItemKind.series,
      ServerItemKind.episode,
    },
    int limit = 60,
  }) async {
    if (none) return const <ServerItem>[];
    return <ServerItem>[
      if (kinds.contains(ServerItemKind.movie))
        const ServerItem(id: 'm1', title: 'Starred film', kind: ServerItemKind.movie),
      if (kinds.contains(ServerItemKind.series))
        const ServerItem(id: 's1', title: 'Starred show', kind: ServerItemKind.series),
      if (kinds.contains(ServerItemKind.episode))
        const ServerItem(
          id: 'e1',
          title: 'Starred episode',
          kind: ServerItemKind.episode,
          seriesTitle: 'Some show',
          seasonNumber: 1,
          episodeNumber: 4,
        ),
    ];
  }

  @override
  Future<List<ServerPerson>> favouritePeople({int limit = 60}) async => none
      ? const <ServerPerson>[]
      : const <ServerPerson>[ServerPerson(name: 'Jane Actor', role: '', id: 'p1')];
}

Future<void> _launch(WidgetTester tester, _Server server) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(400, 1400);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [activeServerProvider.overrideWithValue(server)],
      child: const MPlayerApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('Home has a Favorites row between Next up and what is new',
      (tester) async {
    await _launch(tester, const _Server());

    expect(find.text('Favorites'), findsOneWidget);
    expect(find.text('Starred film'), findsOneWidget);
    expect(find.text('Starred show'), findsOneWidget);
    // Films and shows only: an episode would be a poster of the wrong shape.
    expect(find.text('Starred episode'), findsNothing);

    double y(String t) => tester.getTopLeft(find.text(t)).dy;
    expect(y('Next up'), lessThan(y('Favorites')));
    expect(y('Favorites'), lessThan(y('Recently added in Films')));
  });

  testWidgets('See all opens every kind, the bar still under it',
      (tester) async {
    await _launch(tester, const _Server());

    await tester.tap(find.text('See all'));
    await tester.pumpAndSettle();

    expect(find.byType(FavoritesPage), findsOneWidget);
    for (final String heading in <String>['Movies', 'Shows', 'Episodes', 'People']) {
      expect(find.text(heading), findsOneWidget, reason: heading);
    }
    expect(find.text('Jane Actor'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('the row can be turned off in Customize home', (tester) async {
    await _launch(tester, const _Server());

    await tester.tap(find.byTooltip('Customize home'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(SwitchListTile, 'Favorites'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(200, 40));
    await tester.pumpAndSettle();

    expect(find.text('Starred film'), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('home_show_favourites'), isFalse);
  });

  testWidgets('with nothing starred, Home has no row and the page says why',
      (tester) async {
    await _launch(tester, const _Server(none: true));
    expect(find.text('Favorites'), findsNothing);

    final router = tester
        .widget<MaterialApp>(find.byType(MaterialApp))
        .routerConfig!;
    (router as dynamic).go('/home/favorites');
    await tester.pumpAndSettle();

    expect(find.textContaining('Nothing starred yet'), findsOneWidget);
  });
}
