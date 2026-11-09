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
  const _Server(this.pictures);

  final List<ServerImage> pictures;

  @override
  Future<ServerItem> item(String itemId) async =>
      const ServerItem(id: 'm1', title: 'Dune', kind: ServerItemKind.movie);

  @override
  Future<List<ServerImage>> images(String itemId) async => pictures;

  @override
  Uri? itemImageUrl(String itemId, ServerImage image, {int? maxWidth}) =>
      Uri.parse('https://media.home.lan/${image.type}/${image.index}');
}

const _gallery = <ServerImage>[
  ServerImage(type: 'Primary', tag: 'p', width: 1000, height: 1500),
  ServerImage(type: 'Backdrop', tag: 'b0', width: 1920, height: 1080),
  ServerImage(type: 'Backdrop', tag: 'b1', index: 1),
  ServerImage(type: 'Logo', tag: 'l', width: 800, height: 310),
];

Future<void> _open(WidgetTester tester, List<ServerImage> pictures) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(1400, 2000);
  addTearDown(tester.view.reset);

  final router = buildRouter();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [activeServerProvider.overrideWithValue(_Server(pictures))],
      child: MPlayerApp(router: router),
    ),
  );
  await tester.pumpAndSettle();
  router.push('/library/movie', extra: 'm1');
  await tester.pumpAndSettle();
}

void main() {
  group('/Items/{id}/Images', () {
    test('sorted poster first, backdrops in order, no chapters', () {
      final images = serverImagesFromJson(<Object?>[
        <String, Object?>{'ImageType': 'Logo', 'ImageTag': 'l'},
        <String, Object?>{
          'ImageType': 'Backdrop',
          'ImageTag': 'b1',
          'ImageIndex': 1,
        },
        <String, Object?>{
          'ImageType': 'Chapter',
          'ImageTag': 'c',
          'ImageIndex': 0,
        },
        <String, Object?>{
          'ImageType': 'Backdrop',
          'ImageTag': 'b0',
          'ImageIndex': 0,
          'Width': 1920,
          'Height': 1080,
        },
        <String, Object?>{'ImageType': 'Primary', 'ImageTag': 'p'},
        'junk',
      ]);

      expect(images.map((i) => '${i.type}${i.index}'), <String>[
        'Primary0',
        'Backdrop0',
        'Backdrop1',
        'Logo0',
      ]);
      expect(images[1].aspectRatio, closeTo(16 / 9, 0.001));
      expect(images.first.aspectRatio, isNull);
    });

    test('a picture is addressed by type, index and tag', () {
      final url = itemImageUrlFor(
        'm1',
        const ServerImage(type: 'Backdrop', tag: 'abc', index: 2),
        base: Uri.parse('https://media.home.lan/jf'),
        maxWidth: 400,
      );
      expect(
        url.toString(),
        'https://media.home.lan/jf/Items/m1/Images/Backdrop/2'
        '?tag=abc&maxWidth=400',
      );
    });
  });

  testWidgets('the movie screen shows each picture, labelled', (tester) async {
    await _open(tester, _gallery);

    expect(find.text('Images'), findsOneWidget);
    expect(find.text('Poster'), findsOneWidget);
    expect(find.text('Backdrop'), findsNWidgets(2));
    expect(find.text('Logo'), findsOneWidget);
  });

  testWidgets('a tap opens it full screen, and the arrows move on', (
    tester,
  ) async {
    await _open(tester, _gallery);

    await tester.tap(find.text('Poster'));
    await tester.pumpAndSettle();

    expect(find.text('Poster · 1 of 4'), findsOneWidget);
    await tester.tap(find.byTooltip('Next page'));
    await tester.pumpAndSettle();
    expect(find.text('Backdrop · 2 of 4'), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.textContaining('of 4'), findsNothing);
  });

  testWidgets('one picture or none draws no section', (tester) async {
    await _open(tester, const <ServerImage>[
      ServerImage(type: 'Primary', tag: 'p'),
    ]);
    expect(find.text('Images'), findsNothing);
  });
}
