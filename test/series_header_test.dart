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
import 'package:mplayer/widgets/detail_header.dart';
import 'package:mplayer/widgets/gradient_art.dart';

/// The screens_test routes are all rendered with nothing signed in, so the
/// series header they reach is the empty state. This one stands a real series
/// up — the long title, the second title, all three facts — at every width the
/// design fixes behaviour at, which is where a header built out of a poster
/// beside wrapping text goes wrong.
const _sizes = <String, Size>{
  'phone': Size(400, 800),
  'tablet': Size(900, 1000),
  'desktop': Size(1400, 900),
};

void main() {
  for (final MapEntry<String, Size> entry in _sizes.entries) {
    testWidgets('the series header holds together on ${entry.key}', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = entry.value;
      addTearDown(tester.view.reset);

      final router = buildRouter();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeServerProvider.overrideWithValue(const _FakeSeriesServer()),
          ],
          child: MPlayerApp(router: router),
        ),
      );
      await tester.pumpAndSettle();

      router.push('/library/series', extra: 's1');
      await tester.pumpAndSettle();

      expect(find.byType(DetailHeader), findsOneWidget);
      expect(find.text(_FakeSeriesServer.series.title), findsOneWidget);
      expect(
        find.text(_FakeSeriesServer.series.originalTitle!),
        findsOneWidget,
      );

      // The three facts, in the shapes the design draws them in: a range
      // rather than one year, the certificate in its own box, the rating to
      // one decimal beside the star.
      expect(find.text('2023 - 2026'), findsOneWidget);
      expect(find.byType(CertificateBox), findsOneWidget);
      expect(find.text('7.7'), findsOneWidget);

      // The action row, which replaced the filled button and the chip strip.
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(find.byIcon(Icons.more_vert_rounded), findsWidgets);
    });
  }

  testWidgets('the backdrop grows with a wide window', (tester) async {
    Future<double> backdropAt(Size size) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = size;
      final router = buildRouter();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeServerProvider.overrideWithValue(const _FakeSeriesServer()),
          ],
          child: MPlayerApp(router: router),
        ),
      );
      await tester.pumpAndSettle();
      router.push('/library/series', extra: 's1');
      await tester.pumpAndSettle();
      // The first picture in the header is the backdrop; the poster follows.
      return tester
          .getSize(
            find
                .descendant(
                  of: find.byType(DetailHeader),
                  matching: find.byType(GradientArt),
                )
                .first,
          )
          .height;
    }

    addTearDown(tester.view.reset);

    expect(await backdropAt(const Size(400, 800)), lessThanOrEqualTo(280));
    // A fixed 280 across a desktop window kept a third of the picture's
    // height and cut the faces off it.
    expect(await backdropAt(const Size(1400, 900)), greaterThan(400));
  });

  testWidgets('on a wide window the titles and actions sit beside the poster', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(tester.view.reset);

    final router = buildRouter();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeServerProvider.overrideWithValue(const _FakeSeriesServer()),
        ],
        child: MPlayerApp(router: router),
      ),
    );
    await tester.pumpAndSettle();
    router.push('/library/series', extra: 's1');
    await tester.pumpAndSettle();

    final header = find.byType(DetailHeader);
    final poster = tester.getRect(
      find.descendant(of: header, matching: find.byType(GradientArt)).at(1),
    );
    final title = tester.getRect(find.text(_FakeSeriesServer.series.title));
    final play = tester.getRect(
      find.descendant(
        of: header,
        matching: find.byIcon(Icons.play_arrow_rounded),
      ),
    );

    // Flush with the poster's edge, not centred half a screen away from it.
    expect(title.left - poster.right, lessThan(64));
    expect(play.left - poster.right, lessThan(64));
    // And the actions beside the poster rather than in a row beneath it.
    expect(play.top, lessThan(poster.bottom));

    // The overview is the column to the right of the titles, level with them.
    final overview = tester.getRect(find.textContaining('Amane lives alone'));
    expect(overview.left, greaterThan(title.right));
    // Both columns start at the same height.
    expect((overview.top - title.top).abs(), lessThan(12));
    expect(overview.top, lessThan(poster.bottom));
    expect(find.text('Comedy'), findsOneWidget);
  });

  testWidgets('a second title that only repeats the first is not drawn', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.reset);

    final router = buildRouter();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeServerProvider.overrideWithValue(const _EchoedTitleServer()),
        ],
        child: MPlayerApp(router: router),
      ),
    );
    await tester.pumpAndSettle();

    router.push('/library/series', extra: 's1');
    await tester.pumpAndSettle();

    expect(find.text('A Series'), findsOneWidget);
  });
}

class _FakeSeriesServer extends FakeLibrarySource {
  const _FakeSeriesServer();

  static const series = ServerItem(
    id: 's1',
    title: 'The Angel Next Door Spoils Me Rotten',
    originalTitle: 'お隣の天使様にいつの間にか駄目人間にされていた件',
    kind: ServerItemKind.series,
    year: 2023,
    endYear: 2026,
    certificate: 'TV-14',
    rating: 7.7,
    status: 'Ended',
    overview:
        'Amane lives alone in an apartment, and the most beautiful girl '
        'in school, Mahiru, lives just next door.',
    genres: <String>['Animation', 'Comedy', 'Romance'],
  );

  @override
  Future<ServerItem> item(String itemId) async => series;

  @override
  Future<List<ServerItem>> episodes(String seriesId, {String? seasonId}) async {
    return <ServerItem>[
      for (var i = 1; i <= 3; i++)
        ServerItem(
          id: 'e$i',
          title: 'Episode $i',
          kind: ServerItemKind.episode,
          seriesId: 's1',
          seriesTitle: series.title,
          seasonNumber: 1,
          episodeNumber: i,
          runtime: const Duration(minutes: 23),
        ),
    ];
  }
}

/// A server that names the original title the same as the title, which is
/// what one does for anything made in English.
class _EchoedTitleServer extends FakeLibrarySource {
  const _EchoedTitleServer();

  @override
  Future<ServerItem> item(String itemId) async => const ServerItem(
    id: 's1',
    title: 'A Series',
    originalTitle: 'A Series',
    kind: ServerItemKind.series,
  );
}
