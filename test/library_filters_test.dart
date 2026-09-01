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

    test('a nameless facet row is dropped rather than shown blank', () {
      expect(
        facetNamesFromJson(<String, dynamic>{
          'Items': <dynamic>[
            <String, dynamic>{'Name': 'Drama'},
            <String, dynamic>{'Id': 'no-name'},
            <String, dynamic>{'Name': ''},
          ],
        }),
        <String>['Drama'],
      );
    });
  });

  group('the library screen', () {
    testWidgets('the Unwatched chip narrows the request, not the page',
        (tester) async {
      final server = _RecordingServer();
      await pumpLibrary(tester, server: server);

      expect(server.asked.single.filter, LibraryFilter.none);

      await tester.tap(find.widgetWithText(FilterChip, 'Unwatched'));
      await tester.pumpAndSettle();

      // The page holds a hundred of however many the library has; filtering
      // those would hide nothing past the hundredth.
      expect(
        server.asked.last.filter.flags,
        <ItemFilter>{ItemFilter.unplayed},
      );
    });

    testWidgets('a genre chosen in the sheet reaches the server',
        (tester) async {
      final server = _RecordingServer(
        options: const LibraryFilterOptions(
          genres: <String>['Drama', 'Science Fiction'],
        ),
      );
      await pumpLibrary(tester, server: server);

      await tester.tap(find.widgetWithText(ActionChip, 'Filters'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Genres'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Drama'));
      await tester.pumpAndSettle();

      // Nothing is applied while the sheet is open: a request per checkbox
      // would rearrange the grid under a sheet the user is still reading.
      expect(server.asked.length, 1);

      await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
      await tester.pumpAndSettle();

      expect(server.asked.last.filter.genres, <String>{'Drama'});
      // The chip counts what is on, which is the only thing on screen saying
      // why the library looks emptier than the user remembers.
      expect(find.widgetWithText(ActionChip, '1'), findsOneWidget);
    });

    testWidgets('the sort sheet keeps the direction across a change of field',
        (tester) async {
      final server = _RecordingServer();
      await pumpLibrary(tester, server: server);

      await tester.tap(find.widgetWithText(ActionChip, 'A–Z'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(RadioListTile<SortOrder>, 'Descending'));
      await tester.pumpAndSettle();

      expect(server.asked.last.sort, ServerSort.name);
      expect(server.asked.last.order, SortOrder.descending);

      await tester.tap(find.widgetWithText(ActionChip, 'A–Z'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(RadioListTile<ServerSort>, 'Release date'),
      );
      await tester.pumpAndSettle();

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

      await tester.tap(find.widgetWithText(ActionChip, 'A–Z'));
      await tester.pumpAndSettle();

      expect(find.text('Latest episode added'), findsOneWidget);
      // A film is neither continuing nor ended, so the section is absent
      // rather than disabled outside a shows library.
      expect(find.text('Community rating'), findsOneWidget);
    });

    testWidgets('a film is neither continuing nor ended, so it is not asked',
        (tester) async {
      await pumpLibrary(tester, server: _RecordingServer());

      await tester.tap(find.widgetWithText(ActionChip, 'Filters'));
      await tester.pumpAndSettle();

      expect(find.text('Status'), findsNothing);
      expect(find.text('Features'), findsOneWidget);
      // Nothing came back to filter by, and the sheet says so rather than
      // drawing four empty headings.
      expect(find.text('Genres'), findsNothing);
      expect(
        find.text('This library holds nothing else to filter by.'),
        findsOneWidget,
      );
    });
  });
}
