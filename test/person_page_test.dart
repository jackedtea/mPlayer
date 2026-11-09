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
import 'package:mplayer/features/servers/person_page.dart';
import 'package:mplayer/features/servers/server_library.dart';
import 'package:mplayer/servers/jellyfin_dto.dart';
import 'package:mplayer/servers/media_library_source.dart';

/// The person from the report, credited in one film and two shows.
class _Server extends FakeLibrarySource {
  const _Server({this.known = true});

  /// False: a person the server holds no record for beyond the name.
  final bool known;

  @override
  Future<ServerItem> item(String itemId) async => known
      ? ServerItem(
          id: 'p1',
          title: 'Jun Fukuyama',
          kind: ServerItemKind.unknown,
          overview: 'A Japanese voice actor from Hiroshima.',
          premiereDate: DateTime(1978, 11, 26),
          productionLocations: const <String>[
            'Fukuyama, Hiroshima Prefecture, Japan',
          ],
          links: <ServerLink>[
            ServerLink(name: 'IMDb', url: Uri.parse('https://imdb.com/n')),
            ServerLink(
              name: 'TheMovieDb',
              url: Uri.parse('https://tmdb.org/p'),
            ),
          ],
        )
      : throw const ServerException('Not found.');

  @override
  Future<List<ServerItem>> personItems(
    String personId, {
    int limit = 100,
  }) async => const <ServerItem>[
    ServerItem(id: 'm1', title: 'A Film', kind: ServerItemKind.movie),
    ServerItem(id: 's1', title: 'Grand Blue', kind: ServerItemKind.series),
    ServerItem(id: 's2', title: 'Spice and Wolf', kind: ServerItemKind.series),
  ];
}

Future<void> _open(WidgetTester tester, Size size, {bool known = true}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);

  final router = buildRouter();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        activeServerProvider.overrideWithValue(_Server(known: known)),
      ],
      child: MPlayerApp(router: router),
    ),
  );
  await tester.pumpAndSettle();
  router.push('/library/person?name=Jun%20Fukuyama', extra: 'p1');
  await tester.pumpAndSettle();
}

void main() {
  for (final (String label, Size size) in <(String, Size)>[
    ('a phone', const Size(400, 1600)),
    ('a desktop', const Size(1400, 1600)),
  ]) {
    testWidgets('$label shows the photo, the facts and the credits', (
      tester,
    ) async {
      await _open(tester, size);

      expect(find.textContaining('Born: Nov 26, 1978'), findsOneWidget);
      expect(find.textContaining('years old'), findsOneWidget);
      expect(
        find.text('Birth place: Fukuyama, Hiroshima Prefecture, Japan'),
        findsOneWidget,
      );
      expect(find.textContaining('voice actor'), findsOneWidget);
      expect(find.widgetWithText(ActionChip, 'IMDb'), findsOneWidget);

      // Films and shows apart, each with its count.
      expect(find.text('Movies'), findsOneWidget);
      expect(find.text('Shows'), findsOneWidget);
      expect(find.text('A Film'), findsOneWidget);
      expect(find.text('Spice and Wolf'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a person the server has no record of still lists credits', (
    tester,
  ) async {
    await _open(tester, const Size(400, 1600), known: false);

    // The name from the cast strip stands in.
    expect(find.text('Jun Fukuyama'), findsWidgets);
    expect(find.textContaining('Born'), findsNothing);
    expect(find.text('Grand Blue'), findsOneWidget);
  });

  group('ageOn', () {
    test('counts a birthday not yet reached this year as not yet', () {
      final born = DateTime(1978, 11, 26);
      expect(ageOn(born, DateTime(2026, 11, 25)), 47);
      expect(ageOn(born, DateTime(2026, 11, 26)), 48);
    });
  });

  test('ProductionLocations and EndDate are parsed', () {
    final item = serverItemFromJson(<String, dynamic>{
      'Id': 'p1',
      'Name': 'Someone',
      'Type': 'Person',
      'PremiereDate': '1930-05-31T00:00:00.0000000Z',
      'EndDate': '2020-01-02T00:00:00.0000000Z',
      'ProductionLocations': <Object?>['Tokyo, Japan', ''],
    });
    expect(item.productionLocations, <String>['Tokyo, Japan']);
    expect(item.endDate, DateTime.utc(2020, 1, 2));
  });
}
