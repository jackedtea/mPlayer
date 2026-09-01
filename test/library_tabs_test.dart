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

/// A server with something in every tab, so each one can be told apart by the
/// title it draws rather than by its position.
class _FakeServer extends FakeLibrarySource {
  const _FakeServer({this.collectionKind = 'movies', this.empty = false});

  /// What `/UserViews` calls the library, which is what names the first tab.
  final String collectionKind;

  /// Every list comes back empty, so the tabs have to explain themselves.
  final bool empty;

  static const _view = LibraryView(id: 'v1', name: 'Films', kind: 'movies');

  @override
  Future<List<LibraryView>> views() async => <LibraryView>[
        LibraryView(id: _view.id, name: _view.name, kind: collectionKind),
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
      empty
          ? const <ServerItem>[]
          : const <ServerItem>[
              ServerItem(id: 'm1', title: 'Arrival', kind: ServerItemKind.movie),
            ];

  @override
  Future<List<ServerItem>> favourites(String viewId) async => empty
      ? const <ServerItem>[]
      : const <ServerItem>[
          ServerItem(id: 'm2', title: 'Starred film', kind: ServerItemKind.movie),
        ];

  @override
  Future<List<ServerItem>> collections(String viewId) async => empty
      ? const <ServerItem>[]
      : const <ServerItem>[
          ServerItem(
            id: 'c1',
            title: 'The Villeneuve set',
            kind: ServerItemKind.collection,
          ),
        ];

  @override
  Future<List<ServerItem>> playlists() async => empty
      ? const <ServerItem>[]
      : const <ServerItem>[
          ServerItem(id: 'p1', title: 'Saturday night', kind: ServerItemKind.folder),
        ];

  @override
  Future<List<ServerShelf>> suggestions(String viewId) async => empty
      ? const <ServerShelf>[]
      : const <ServerShelf>[
          ServerShelf(
            kind: SuggestionKind.similarToRecentlyPlayed,
            subject: 'Dune',
            items: <ServerItem>[
              ServerItem(id: 'm3', title: 'Sicario', kind: ServerItemKind.movie),
            ],
          ),
        ];

  @override
  Future<List<ServerItem>> playlistItems(String playlistId) async =>
      const <ServerItem>[
        ServerItem(id: 'm4', title: 'In the playlist', kind: ServerItemKind.movie),
      ];
}

/// Records which library each scoped shelf was asked for.
class _RecordingServer extends _FakeServer {
  _RecordingServer();

  final List<String?> resumeScopes = <String?>[];
  final List<String?> nextUpScopes = <String?>[];

  @override
  Future<List<ServerItem>> resumable({int limit = 12, String? viewId}) async {
    resumeScopes.add(viewId);
    return const <ServerItem>[];
  }

  @override
  Future<List<ServerItem>> nextUp({int limit = 12, String? viewId}) async {
    nextUpScopes.add(viewId);
    return const <ServerItem>[];
  }
}

/// Stands the library screen up against [server] and opens [viewId].
Future<void> pumpLibrary(
  WidgetTester tester, {
  required MediaLibrarySource server,
  String? viewId = 'v1',
  String? browse,
  Size size = const Size(900, 900),
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);

  final router = buildRouter();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [activeServerProvider.overrideWithValue(server)],
      child: MPlayerApp(router: router),
    ),
  );
  await tester.pumpAndSettle();

  router.push(
    Uri(
      path: '/library',
      queryParameters: <String, String>{
        'title': 'Films',
        'browse': ?browse,
      },
    ).toString(),
    extra: viewId,
  );
  await tester.pumpAndSettle();

}

void main() {
  group('the tab bar', () {
    testWidgets('a movie library names its first tab after what it holds',
        (tester) async {
      await pumpLibrary(tester, server: const _FakeServer());

      // "Movies" rather than "All": the label says what is under it, which
      // over a shelf of films is the more useful of the two.
      expect(find.widgetWithText(Tab, 'Movies'), findsOneWidget);
      expect(find.widgetWithText(Tab, 'Suggestions'), findsOneWidget);
      expect(find.widgetWithText(Tab, 'Favourites'), findsOneWidget);
      expect(find.widgetWithText(Tab, 'Collections'), findsOneWidget);
      expect(find.widgetWithText(Tab, 'Playlists'), findsOneWidget);
    });

    testWidgets('a shows library says Shows', (tester) async {
      await pumpLibrary(
        tester,
        server: const _FakeServer(collectionKind: 'tvshows'),
      );

      expect(find.widgetWithText(Tab, 'Shows'), findsOneWidget);
      expect(find.widgetWithText(Tab, 'Movies'), findsNothing);
    });

    testWidgets('a library whose type the app has never heard of says All',
        (tester) async {
      await pumpLibrary(
        tester,
        server: const _FakeServer(collectionKind: 'homevideos'),
      );

      expect(find.widgetWithText(Tab, 'All'), findsOneWidget);
    });

    testWidgets('a collection drill-down carries no tabs at all',
        (tester) async {
      // A box set holds a fixed set of films. It has no suggestions,
      // favourites or collections of its own, so four of the five tabs could
      // never fill.
      await pumpLibrary(
        tester,
        server: const _FakeServer(),
        browse: 'collection',
      );

      expect(find.byType(TabBar), findsNothing);
      expect(find.text('Arrival'), findsOneWidget);
    });

    testWidgets('a playlist drill-down lists what is in it', (tester) async {
      await pumpLibrary(
        tester,
        server: const _FakeServer(),
        browse: 'playlist',
      );

      expect(find.byType(TabBar), findsNothing);
      // Through `/Playlists/{id}/Items`, not `parentId`: only that route
      // keeps the order the playlist was put in.
      expect(find.text('In the playlist'), findsOneWidget);
      expect(find.text('Arrival'), findsNothing);
    });
  });

  group('what each tab draws', () {
    testWidgets('favourites, collections and playlists each show their own',
        (tester) async {
      await pumpLibrary(tester, server: const _FakeServer());

      expect(find.text('Arrival'), findsOneWidget);

      await tester.tap(find.widgetWithText(Tab, 'Favourites'));
      await tester.pumpAndSettle();
      expect(find.text('Starred film'), findsOneWidget);

      await tester.tap(find.widgetWithText(Tab, 'Collections'));
      await tester.pumpAndSettle();
      expect(find.text('The Villeneuve set'), findsOneWidget);

      await tester.tap(find.widgetWithText(Tab, 'Playlists'));
      await tester.pumpAndSettle();
      expect(find.text('Saturday night'), findsOneWidget);
    });

    testWidgets('a suggestion shelf is titled with the server\'s reason',
        (tester) async {
      await pumpLibrary(tester, server: const _FakeServer());

      await tester.tap(find.widgetWithText(Tab, 'Suggestions'));
      await tester.pumpAndSettle();

      // The reason and its subject arrive apart — "SimilarToRecentlyPlayed"
      // and "Dune" — precisely so the sentence is built where there is a
      // locale to build it in.
      expect(find.text('Because you watched Dune'), findsOneWidget);
      expect(find.text('Sicario'), findsOneWidget);
    });

    testWidgets('the suggestions tab asks only about this library',
        (tester) async {
      final server = _RecordingServer();
      await pumpLibrary(tester, server: server);

      await tester.tap(find.widgetWithText(Tab, 'Suggestions'));
      await tester.pumpAndSettle();

      // A film left half-watched has no place on a shelf inside the shows
      // library, so the scoped shelves carry the parent.
      expect(server.resumeScopes, contains('v1'));
      expect(server.nextUpScopes, contains('v1'));
    });
  });

  group('empty tabs', () {
    testWidgets('each says what is missing rather than showing blank space',
        (tester) async {
      await pumpLibrary(tester, server: const _FakeServer(empty: true));

      await tester.tap(find.widgetWithText(Tab, 'Favourites'));
      await tester.pumpAndSettle();
      expect(find.text('Nothing starred in this library yet.'), findsOneWidget);

      await tester.tap(find.widgetWithText(Tab, 'Collections'));
      await tester.pumpAndSettle();
      expect(
        find.text('No collections draw on this library.'),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(Tab, 'Playlists'));
      await tester.pumpAndSettle();
      expect(find.text('No playlists on this server yet.'), findsOneWidget);

      await tester.tap(find.widgetWithText(Tab, 'Suggestions'));
      await tester.pumpAndSettle();
      expect(
        find.text('Nothing to suggest yet — watch something and come back.'),
        findsOneWidget,
      );
    });
  });

  group('layout', () {
    for (final Size size in <Size>[
      Size(400, 900),
      Size(800, 900),
      Size(1400, 900),
    ]) {
      testWidgets('every tab fits at ${size.width.toInt()}px', (tester) async {
        await pumpLibrary(tester, server: const _FakeServer(), size: size);

        for (final String label in <String>[
          'Suggestions',
          'Favourites',
          'Collections',
          'Playlists',
        ]) {
          await tester.tap(find.widgetWithText(Tab, label));
          await tester.pumpAndSettle();
          // The same rule `screens_test` enforces everywhere else: an
          // overflow is a failure, not a yellow stripe nobody looks at.
          expect(
            tester.takeException(),
            isNull,
            reason: '$label overflowed at ${size.width}px',
          );
        }
      });
    }
  });
}
