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
import 'package:mplayer/servers/jellyfin_dto.dart';
import 'package:mplayer/servers/media_library_source.dart';

class _Server extends FakeLibrarySource {
  _Server(this.links);

  final List<ServerLink> links;

  @override
  Future<ServerItem> item(String itemId) async => ServerItem(
    id: 'm1',
    title: 'Dune',
    kind: ServerItemKind.movie,
    links: links,
  );
}

Future<void> _open(WidgetTester tester, List<ServerLink> links) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(400, 2400);
  addTearDown(tester.view.reset);

  final router = buildRouter();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [activeServerProvider.overrideWithValue(_Server(links))],
      child: MPlayerApp(router: router),
    ),
  );
  await tester.pumpAndSettle();
  router.push('/library/movie', extra: 'm1');
  await tester.pumpAndSettle();
}

void main() {
  group('ExternalUrls', () {
    test('become links, web addresses only', () {
      final item = serverItemFromJson(<String, dynamic>{
        'Id': 'm1',
        'Name': 'Dune',
        'Type': 'Movie',
        'ExternalUrls': <Object?>[
          <String, Object?>{
            'Name': 'IMDb',
            'Url': 'https://www.imdb.com/title/tt1160419',
          },
          <String, Object?>{
            'Name': 'TheMovieDb',
            'Url': 'https://www.themoviedb.org/movie/438631',
          },
          // Not something a browser should be handed.
          <String, Object?>{'Name': 'Local', 'Url': 'file:///etc/passwd'},
          <String, Object?>{'Name': '', 'Url': 'https://example.com'},
          'junk',
        ],
      });

      expect(item.links.map((l) => l.name), <String>['IMDb', 'TheMovieDb']);
      expect(
        item.links.first.url,
        Uri.parse('https://www.imdb.com/title/tt1160419'),
      );
    });

    test('absent is no links, not an error', () {
      final item = serverItemFromJson(<String, dynamic>{
        'Id': 'm1',
        'Name': 'Dune',
        'Type': 'Movie',
      });
      expect(item.links, isEmpty);
    });
  });

  testWidgets('the movie screen shows a chip per link', (tester) async {
    await _open(tester, <ServerLink>[
      ServerLink(name: 'IMDb', url: Uri.parse('https://www.imdb.com/t')),
      ServerLink(name: 'TheMovieDb', url: Uri.parse('https://tmdb.org/m')),
    ]);

    expect(find.text('Links'), findsOneWidget);
    expect(find.widgetWithText(ActionChip, 'IMDb'), findsOneWidget);
    expect(find.widgetWithText(ActionChip, 'TheMovieDb'), findsOneWidget);
  });

  testWidgets('no links, no heading', (tester) async {
    await _open(tester, const <ServerLink>[]);
    expect(find.text('Links'), findsNothing);
  });
}
