// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_library_source.dart';

import 'package:mplayer/app/app.dart';
import 'package:mplayer/app/router.dart';
import 'package:mplayer/features/music/music_widgets.dart';
import 'package:mplayer/features/servers/library_filter_sheet.dart';
import 'package:mplayer/features/servers/server_library.dart';
import 'package:mplayer/servers/media_library_source.dart';

/// A music library with more songs than one page, one two-disc album, and an
/// artist who has something in every section.
class _Music extends FakeLibrarySource {
  static const songs = 250;

  /// Every listing asked for, as (listing, startIndex, sort, genres).
  final List<(MusicListing, int, ServerSort, Set<String>)> asked =
      <(MusicListing, int, ServerSort, Set<String>)>[];

  int filmGridAsks = 0;

  @override
  Future<List<LibraryView>> views() async => const <LibraryView>[
    LibraryView(id: 'm', name: 'Music', kind: 'music'),
  ];

  @override
  Future<List<LibraryGenre>> genres(String viewId) async =>
      const <LibraryGenre>[LibraryGenre(id: 'g1', name: 'Disco')];

  @override
  Future<List<ServerItem>> items(
    String viewId, {
    int startIndex = 0,
    int limit = 100,
    ServerSort sort = ServerSort.name,
    SortOrder? order,
    LibraryFilter filter = LibraryFilter.none,
  }) async {
    filmGridAsks++;
    return const <ServerItem>[];
  }

  @override
  Future<int> musicItemCount(String viewId, MusicListing listing) async =>
      switch (listing) {
        MusicListing.albums => 12,
        MusicListing.artists => 3,
        MusicListing.tracks => songs,
      };

  @override
  Future<List<ServerItem>> musicItems(
    String viewId,
    MusicListing listing, {
    int startIndex = 0,
    int limit = 100,
    ServerSort sort = ServerSort.name,
    SortOrder? order,
    LibraryFilter filter = LibraryFilter.none,
  }) async {
    asked.add((listing, startIndex, sort, filter.genres));
    return switch (listing) {
      MusicListing.albums => const <ServerItem>[_album],
      MusicListing.artists => const <ServerItem>[_artist],
      MusicListing.tracks => <ServerItem>[
        for (var i = startIndex; i < startIndex + limit && i < songs; i++)
          ServerItem(
            id: 't$i',
            title: 'Song $i',
            kind: ServerItemKind.audio,
            artists: const <ServerArtistRef>[ServerArtistRef(name: 'Someone')],
          ),
      ],
    };
  }

  @override
  Future<ServerItem> item(String itemId) async =>
      itemId == _artist.id ? _artist : _album;

  @override
  Future<List<ServerItem>> albumTracks(String albumId) async =>
      const <ServerItem>[
        ServerItem(
          id: 'a',
          title: 'First Side',
          kind: ServerItemKind.audio,
          seasonNumber: 1,
          episodeNumber: 1,
          runtime: Duration(minutes: 3, seconds: 7),
          artists: <ServerArtistRef>[_daft],
        ),
        ServerItem(
          id: 'b',
          title: 'Guest Spot',
          kind: ServerItemKind.audio,
          seasonNumber: 1,
          episodeNumber: 2,
          runtime: Duration(minutes: 4),
          artists: <ServerArtistRef>[
            _daft,
            ServerArtistRef(name: 'Pharrell Williams'),
          ],
        ),
        ServerItem(
          id: 'c',
          title: 'Second Side',
          kind: ServerItemKind.audio,
          seasonNumber: 2,
          episodeNumber: 1,
          artists: <ServerArtistRef>[_daft],
        ),
      ];

  @override
  Future<List<ServerItem>> artistTopTracks(
    String artistId, {
    int limit = 10,
  }) async => <ServerItem>[
    for (var i = 0; i < 7; i++)
      ServerItem(id: 'p$i', title: 'Hit $i', kind: ServerItemKind.audio),
  ];

  @override
  Future<List<ServerItem>> artistAlbums(String artistId) async =>
      const <ServerItem>[_album];

  @override
  Future<List<ServerItem>> artistAppearsOn(String artistId) async =>
      const <ServerItem>[
        ServerItem(
          id: 'guest',
          title: 'Their Guest Spot',
          kind: ServerItemKind.musicAlbum,
        ),
      ];
}

const _daft = ServerArtistRef(name: 'Daft Punk', id: 'ar1');

const _artist = ServerItem(
  id: 'ar1',
  title: 'Daft Punk',
  kind: ServerItemKind.musicArtist,
);

const _album = ServerItem(
  id: 'al1',
  title: 'Random Access Memories',
  kind: ServerItemKind.musicAlbum,
  year: 2013,
  artists: <ServerArtistRef>[_daft],
  albumArtists: <ServerArtistRef>[_daft],
);

Future<GoRouter> _pump(
  WidgetTester tester,
  MediaLibrarySource source, {
  Size size = const Size(400, 900),
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);

  final router = buildRouter();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [activeServerProvider.overrideWithValue(source)],
      child: MPlayerApp(router: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

const _sizes = <Size>[Size(400, 900), Size(900, 1000), Size(1400, 900)];

void main() {
  group('a music library', () {
    testWidgets('has tabs of its own, and never asks for the film grid', (
      tester,
    ) async {
      final source = _Music();
      final router = await _pump(tester, source);

      router.go('/library', extra: 'm');
      await tester.pumpAndSettle();

      for (final String tab in <String>[
        'Albums',
        'Artists',
        'Songs',
        'Playlists',
        'Genres',
      ]) {
        expect(find.widgetWithText(Tab, tab), findsOneWidget);
      }
      expect(find.widgetWithText(Tab, 'Suggestions'), findsNothing);
      expect(find.text('Random Access Memories'), findsOneWidget);
      expect(find.text('Daft Punk'), findsOneWidget);
      // The title counts the tab on screen, not whatever the film count says.
      expect(find.text('12 items'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the count follows the tab', (tester) async {
      final router = await _pump(tester, _Music());
      router.go('/library', extra: 'm');
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(Tab, 'Songs'));
      await tester.pumpAndSettle();

      expect(find.text('250 items'), findsOneWidget);
    });

    testWidgets('Songs fetches the next page as it is scrolled to', (
      tester,
    ) async {
      // The film grid stops at a hundred. A song past the hundredth has to be
      // reachable, or most of a music library simply is not there.
      final source = _Music();
      final router = await _pump(tester, source);
      router.go('/library', extra: 'm');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(Tab, 'Songs'));
      await tester.pumpAndSettle();

      List<int> pages() => <int>[
        for (final a in source.asked)
          if (a.$1 == MusicListing.tracks) a.$2,
      ];
      expect(pages(), <int>[0]);

      await tester.dragUntilVisible(
        find.text('Song 120'),
        // The last: Albums stays alive behind this tab.
        find.byType(CustomScrollView).last,
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();

      expect(pages(), containsAllInOrder(<int>[0, 100]));
      expect(find.text('Song 120'), findsOneWidget);
    });

    testWidgets('a genre tile opens albums, not the film grid', (tester) async {
      final source = _Music();
      final router = await _pump(tester, source);
      router.go('/library', extra: 'm');
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.widgetWithText(Tab, 'Genres'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(Tab, 'Genres'));
      await tester.pumpAndSettle();
      source.filmGridAsks = 0;
      // The tile's ink lies over the name.
      await tester.tap(find.text('Disco'), warnIfMissed: false);
      await tester.pumpAndSettle();

      final (listing, _, _, genres) = source.asked.last;
      expect(listing, MusicListing.albums);
      expect(genres, <String>{'Disco'});
      expect(source.filmGridAsks, 0);
      // Removable like any other filter.
      expect(find.widgetWithText(InputChip, 'Disco'), findsOneWidget);
    });

    testWidgets('Sort & filter offers only what means something for music', (
      tester,
    ) async {
      final router = await _pump(tester, _Music());
      router.go('/library', extra: 'm');
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Sort & filter'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ChoiceChip, 'Artist'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Parental rating'), findsNothing);
      expect(find.widgetWithText(FilterChip, 'Unwatched'), findsNothing);
    });

    test('the artist sort stays out of film libraries', () {
      expect(sortsFor('music'), contains(ServerSort.artist));
      expect(sortsFor('music'), isNot(contains(ServerSort.parentalRating)));
      expect(sortsFor('movies'), isNot(contains(ServerSort.artist)));
      expect(sortsFor('tvshows'), isNot(contains(ServerSort.artist)));
    });
  });

  group('an album', () {
    testWidgets('groups its tracks by disc and credits only the guest', (
      tester,
    ) async {
      final router = await _pump(tester, _Music());
      router.push('/library/album', extra: 'al1');
      await tester.pumpAndSettle();

      expect(find.text('Disc 1'), findsOneWidget);
      expect(find.text('Disc 2'), findsOneWidget);
      expect(find.text('3:07'), findsOneWidget);
      expect(find.text('2013 · 3 songs · 7m'), findsOneWidget);

      // Thirteen rows of the album's own artist would say nothing.
      final guest = find.widgetWithText(TrackRow, 'Guest Spot');
      expect(
        find.descendant(
          of: guest,
          matching: find.text('Daft Punk, Pharrell Williams'),
        ),
        findsOneWidget,
      );
      final plain = tester.widget<TrackRow>(
        find.widgetWithText(TrackRow, 'First Side'),
      );
      expect(plain.subtitle, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('its artist opens their page', (tester) async {
      final router = await _pump(tester, _Music());
      router.push('/library/album', extra: 'al1');
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Daft Punk'));
      await tester.pumpAndSettle();

      expect(find.text('Popular'), findsOneWidget);
    });

    testWidgets('offers no watched toggle on its tracks', (tester) async {
      final router = await _pump(tester, _Music());
      router.push('/library/album', extra: 'al1');
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.widgetWithText(TrackRow, 'First Side'),
          matching: find.byIcon(Icons.more_vert_rounded),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add to playlist'), findsOneWidget);
      expect(find.text('Mark as watched'), findsNothing);
    });

    for (final Size size in _sizes) {
      testWidgets('lays out at ${size.width.toInt()}', (tester) async {
        final router = await _pump(tester, _Music(), size: size);
        router.push('/library/album', extra: 'al1');
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('an artist', () {
    testWidgets('shows five popular tracks until asked for the rest', (
      tester,
    ) async {
      final router = await _pump(tester, _Music());
      router.push('/library/artist?name=Daft%20Punk', extra: 'ar1');
      await tester.pumpAndSettle();

      expect(find.text('Hit 4'), findsOneWidget);
      expect(find.text('Hit 5'), findsNothing);

      await tester.ensureVisible(find.text('See all'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('See all'));
      await tester.pumpAndSettle();

      expect(find.text('Hit 5'), findsOneWidget);
    });

    testWidgets('has its albums and what it guests on, and no empty heading', (
      tester,
    ) async {
      final router = await _pump(tester, _Music(), size: const Size(400, 1600));
      router.push('/library/artist', extra: 'ar1');
      await tester.pumpAndSettle();

      expect(find.text('Albums'), findsOneWidget);
      expect(find.text('Appears on'), findsOneWidget);
      expect(find.text('Their Guest Spot'), findsOneWidget);
      // The fake has no similar artists, so the section is absent.
      expect(find.text('Similar artists'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    for (final Size size in _sizes) {
      testWidgets('lays out at ${size.width.toInt()}', (tester) async {
        final router = await _pump(tester, _Music(), size: size);
        router.push('/library/artist', extra: 'ar1');
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });

  test('a track length reads like a player', () {
    expect(trackDuration(const Duration(minutes: 3, seconds: 7)), '3:07');
    expect(trackDuration(const Duration(seconds: 42)), '0:42');
    expect(
      trackDuration(const Duration(hours: 1, minutes: 2, seconds: 45)),
      '1:02:45',
    );
  });

  test('played albums carry no tick, played films still do', () {
    expect(
      libraryItemFrom(
        const ServerItem(
          id: 'a',
          title: 'a',
          kind: ServerItemKind.musicAlbum,
          played: true,
        ),
      ).watched,
      isFalse,
    );
    expect(
      libraryItemFrom(
        const ServerItem(
          id: 'm',
          title: 'm',
          kind: ServerItemKind.movie,
          played: true,
        ),
      ).watched,
      isTrue,
    );
  });
}
