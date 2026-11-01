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
import 'package:mplayer/features/servers/library_filter_sheet.dart';
import 'package:mplayer/features/servers/server_library.dart';
import 'package:mplayer/servers/jellyfin_dto.dart';
import 'package:mplayer/servers/media_library_source.dart';

/// Records what the grid asked for, so a chip or a checkbox can be shown to
/// have changed the *request* rather than the page that came back.
class _RecordingServer extends FakeLibrarySource {
  _RecordingServer({this.collectionKind = 'movies', this.options});

  final String collectionKind;
  final LibraryFilterOptions? options;

  final List<({ServerSort sort, SortOrder? order, LibraryFilter filter})> asked =
      <({ServerSort sort, SortOrder? order, LibraryFilter filter})>[];

  @override
  Future<List<LibraryView>> views() async => <LibraryView>[
        LibraryView(id: 'v1', name: 'Films', kind: collectionKind),
      ];

  @override
  Future<List<ServerItem>> items(
    String viewId, {
    int startIndex = 0,
    int limit = 100,
    ServerSort sort = ServerSort.name,
    SortOrder? order,
    LibraryFilter filter = LibraryFilter.none,
  }) async {
    asked.add((sort: sort, order: order, filter: filter));
    return const <ServerItem>[
      ServerItem(id: 'm1', title: 'Arrival', kind: ServerItemKind.movie),
    ];
  }

  @override
  Future<LibraryFilterOptions> filterOptions(String viewId) async =>
      options ?? LibraryFilterOptions.empty;
}

/// Stands the library screen up against [server] and opens it.
Future<void> pumpLibrary(
  WidgetTester tester, {
  required MediaLibrarySource server,
  Size size = const Size(900, 1400),
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

  // The app opens on Home, whose "Recently added" rows ask the same route
  // for the newest items. Only what the grid asks is under test here.
  if (server is _RecordingServer) server.asked.clear();

  router.push('/library?title=Films', extra: 'v1');
  await tester.pumpAndSettle();
}

void main() {
  group('the filter on the wire', () {
    test('nothing chosen sends nothing', () {
      // An empty `filters=` is not the same as no filter: some versions read
      // it as a constraint nothing satisfies.
      expect(filterParams(LibraryFilter.none), isEmpty);
    });

    test('the delimiters are not interchangeable', () {
      final params = filterParams(
        const LibraryFilter(
          genres: <String>{'Science Fiction', 'Drama'},
          tags: <String>{'based on a book'},
          years: <int>{2024, 1999},
          flags: <ItemFilter>{ItemFilter.favourite, ItemFilter.unplayed},
        ),
      );

      // Pipes for the free-text lists, because a comma occurs inside one of
      // those values; commas for the closed vocabularies, where it cannot.
      expect(params['genres'], 'Drama|Science Fiction');
      expect(params['tags'], 'based on a book');
      expect(params['years'], '1999,2024');
      expect(params['filters'], 'IsFavorite,IsUnplayed');
    });

    test('a feature is its own parameter, not a member of a set', () {
      final params = filterParams(
        const LibraryFilter(
          features: <ItemFeature>{
            ItemFeature.specialFeature,
            ItemFeature.themeVideo,
          },
        ),
      );

      expect(params['hasSpecialFeature'], 'true');
      expect(params['hasThemeVideo'], 'true');
      // Absent rather than false: `hasTrailer=false` asks for items that
      // have none, which is not what an unticked box means.
      expect(params.containsKey('hasTrailer'), isFalse);
    });

    test('the same filter always produces the same query', () {
      // Two identical filters built in different orders have to be one
      // request, not two — the URL is what the HTTP cache is keyed on.
      final a = filterParams(
        const LibraryFilter(genres: <String>{'Drama', 'Comedy'}),
      );
      final b = filterParams(
        const LibraryFilter(genres: <String>{'Comedy', 'Drama'}),
      );

      expect(a, b);
    });
  });

  group('sorting', () {
    test('every sort names a field the server has', () {
      expect(sortByFor(ServerSort.communityRating), 'CommunityRating');
      expect(sortByFor(ServerSort.parentalRating), 'OfficialRating');
      // The newest episode under a series, not the series' own arrival —
      // years apart on a show that is still running.
      expect(sortByFor(ServerSort.dateEpisodeAdded), 'DateLastContentAdded');
    });

    test('a sort read backwards is a choice, not a default', () {
      expect(sortOrderFor(ServerSort.name), 'Ascending');
      expect(sortOrderFor(ServerSort.name, SortOrder.descending), 'Descending');
      // "Recently added, oldest first" is not what anyone picking it meant.
      expect(sortOrderFor(ServerSort.dateAdded), 'Descending');
      expect(
        sortOrderFor(ServerSort.dateAdded, SortOrder.ascending),
        'Ascending',
      );
    });

    test('a film has no latest episode, so a movie library is not offered one',
        () {
      expect(sortsFor('tvshows'), contains(ServerSort.dateEpisodeAdded));
      expect(sortsFor('movies'), isNot(contains(ServerSort.dateEpisodeAdded)));
      expect(sortsFor('movies'), contains(ServerSort.dateAdded));
    });
  });

  group('the filter as a request key', () {
    test('two filters that say the same thing are one request', () {
      // This is half of a provider family key. Without value equality the
      // same filter rebuilt on every frame would refetch the library on
      // every frame.
      const a = LibraryFilter(
        genres: <String>{'Drama', 'Comedy'},
        years: <int>{2024},
      );
      const b = LibraryFilter(
        genres: <String>{'Comedy', 'Drama'},
        years: <int>{2024},
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(
        LibraryQuery('v1', ServerSort.name, filter: a),
        LibraryQuery('v1', ServerSort.name, filter: b),
      );
    });

    test('an unset direction is not the same as the one it stands in for', () {
      // Storing the natural direction would freeze it: the next sort chosen
      // would inherit ascending and turn Recently added into oldest-first.
      const untouched = LibraryOrdering(ServerSort.name);
      const chosen = LibraryOrdering(ServerSort.name, SortOrder.ascending);

      expect(untouched.effectiveOrder, chosen.effectiveOrder);
      expect(untouched, isNot(chosen));
    });

    test('the count is what the chip shows', () {
      const filter = LibraryFilter(
        flags: <ItemFilter>{ItemFilter.unplayed},
        genres: <String>{'Drama', 'Comedy'},
        years: <int>{2024},
      );

      expect(filter.count, 4);
      expect(filter.isEmpty, isFalse);
      expect(LibraryFilter.none.isEmpty, isTrue);
    });
  });

  group('the filter values', () {
    test('years stay numbers, whichever way the server sent them', () {
      // Sorted as strings, 999 would file after 2024.
      final options = filterOptionsFromJson(<String, dynamic>{
        'Genres': <Object?>['Drama', 42, ''],
        'Years': <Object?>[2024, '1999', 'not a year'],
      });

      expect(options.genres, <String>['Drama']);
      expect(options.years, <int>[2024, 1999]);
      expect(options.parentalRatings, isEmpty);
    });

  });

  group('the library screen', () {
    Future<void> openOptions(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Sort & filter'));
      await tester.pumpAndSettle();
    }

    Future<void> apply(WidgetTester tester) async {
      await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
      await tester.pumpAndSettle();
    }

    testWidgets('a filter narrows the request, not the page', (tester) async {
      final server = _RecordingServer();
      await pumpLibrary(tester, server: server);

      expect(server.asked.single.filter, LibraryFilter.none);

      await openOptions(tester);
      await tester.tap(find.widgetWithText(FilterChip, 'Unwatched'));
      await tester.pumpAndSettle();
      await apply(tester);

      // The page holds a hundred of however many the library has; filtering
      // those would hide nothing past the hundredth.
      expect(
        server.asked.last.filter.flags,
        <ItemFilter>{ItemFilter.unplayed},
      );
    });

    testWidgets('a genre chosen in the dialog reaches the server',
        (tester) async {
      final server = _RecordingServer(
        options: const LibraryFilterOptions(
          genres: <String>['Drama', 'Science Fiction'],
        ),
      );
      await pumpLibrary(tester, server: server);

      await openOptions(tester);
      await tester.tap(find.widgetWithText(ExpansionTile, 'Genres'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'Drama'));
      await tester.pumpAndSettle();

      // Nothing is applied while the dialog is open: a request per chip
      // would rearrange the grid under a dialog the user is still reading.
      expect(server.asked.length, 1);

      await apply(tester);

      expect(server.asked.last.filter.genres, <String>{'Drama'});
      // The button counts what is on, and the chip over the grid says what.
      expect(
        find.descendant(of: find.byType(Badge), matching: find.text('1')),
        findsOneWidget,
      );
      expect(find.widgetWithText(InputChip, 'Drama'), findsOneWidget);
    });

    testWidgets('a filter chip over the grid removes just that filter',
        (tester) async {
      final server = _RecordingServer(
        options: const LibraryFilterOptions(genres: <String>['Drama']),
      );
      await pumpLibrary(tester, server: server);

      await openOptions(tester);
      await tester.tap(find.widgetWithText(FilterChip, 'Favourites'));
      await tester.tap(find.widgetWithText(ExpansionTile, 'Genres'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'Drama'));
      await apply(tester);

      final drama = find.widgetWithText(InputChip, 'Drama');
      // The delete glyph, whichever icon the theme draws for it.
      await tester.tap(
        find.descendant(of: drama, matching: find.byType(Icon)).last,
      );
      await tester.pumpAndSettle();

      expect(server.asked.last.filter.genres, isEmpty);
      expect(server.asked.last.filter.flags, <ItemFilter>{ItemFilter.favourite});
    });

    testWidgets('the direction carries across a change of field',
        (tester) async {
      final server = _RecordingServer();
      await pumpLibrary(tester, server: server);

      await openOptions(tester);
      await tester.tap(find.text('Descending'));
      await tester.pumpAndSettle();
      await apply(tester);

      expect(server.asked.last.sort, ServerSort.name);
      expect(server.asked.last.order, SortOrder.descending);

      await openOptions(tester);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Release date'));
      await tester.pumpAndSettle();
      await apply(tester);

      // A user who chose Descending meant it; flipping back to the new
      // sort's natural direction reads as the app forgetting.
      expect(server.asked.last.sort, ServerSort.releaseDate);
      expect(server.asked.last.order, SortOrder.descending);
    });

    testWidgets('a shows library is the only one offered the episode sort',
        (tester) async {
      await pumpLibrary(
        tester,
        server: _RecordingServer(collectionKind: 'tvshows'),
      );

      await openOptions(tester);

      expect(find.text('Latest episode added'), findsOneWidget);
      expect(find.text('Community rating'), findsOneWidget);
      // And the series status, which a film library has no use for.
      expect(find.text('Status'), findsOneWidget);
    });

    testWidgets('a film is neither continuing nor ended, so it is not asked',
        (tester) async {
      await pumpLibrary(tester, server: _RecordingServer());

      await openOptions(tester);

      expect(find.text('Status'), findsNothing);
      expect(find.text('Features'), findsOneWidget);
      // Nothing came back to filter by, and the dialog says so rather than
      // drawing four empty headings.
      expect(find.widgetWithText(ExpansionTile, 'Genres'), findsNothing);
      expect(
        find.text('This library holds nothing else to filter by.'),
        findsOneWidget,
      );
    });

    testWidgets('the filter button is on Browse alone', (tester) async {
      await pumpLibrary(tester, server: _RecordingServer());
      expect(find.byTooltip('Sort & filter'), findsOneWidget);

      await tester.tap(find.widgetWithText(Tab, 'Collections'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Sort & filter'), findsNothing);
    });
  });
}
