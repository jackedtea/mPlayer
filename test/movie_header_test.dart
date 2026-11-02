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
import 'package:mplayer/widgets/backdrop_header.dart';
import 'package:mplayer/widgets/detail_header.dart';
import 'package:mplayer/widgets/gradient_art.dart';

class _Movie extends FakeLibrarySource {
  const _Movie({this.certificate = 'PG-13'});

  final String? certificate;

  @override
  Future<ServerItem> item(String itemId) async => ServerItem(
    id: 'm1',
    title: 'Royal Tramp II',
    kind: ServerItemKind.movie,
    year: 1992,
    rating: 7.1,
    certificate: certificate,
    runtime: const Duration(minutes: 97),
    overview: 'Wai Siu Bo meets an old enemy and talks his way out again.',
    genres: const <String>['Action', 'Comedy'],
  );
}

Future<void> _open(
  WidgetTester tester,
  Size size, {
  MediaLibrarySource source = const _Movie(),
}) async {
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
  router.push('/library/movie', extra: 'm1');
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a wide window gets the poster header with the overview '
      'beside the titles', (tester) async {
    await _open(tester, const Size(1400, 900));

    expect(find.byType(DetailHeader), findsOneWidget);
    expect(find.byType(BackdropHeader), findsNothing);

    final header = find.byType(DetailHeader);
    final poster = tester.getRect(
      find.descendant(of: header, matching: find.byType(GradientArt)).at(1),
    );
    final title = tester.getRect(find.text('Royal Tramp II'));
    final overview = tester.getRect(find.textContaining('Wai Siu Bo'));

    expect(title.left - poster.right, lessThan(64));
    expect(overview.left, greaterThan(title.right));
    expect((overview.top - title.top).abs(), lessThan(12));
    // Drawn once, in the header, not again under it.
    expect(find.textContaining('Wai Siu Bo'), findsOneWidget);
    expect(find.text('Comedy'), findsOneWidget);
    expect(find.byType(CertificateBox), findsOneWidget);
  });

  testWidgets('a phone keeps the backdrop header', (tester) async {
    await _open(tester, const Size(400, 800));

    expect(find.byType(BackdropHeader), findsOneWidget);
    expect(find.byType(DetailHeader), findsNothing);
  });

  testWidgets('a missing certificate draws no empty box and no stray dots', (
    tester,
  ) async {
    await _open(
      tester,
      const Size(400, 800),
      source: const _Movie(certificate: null),
    );

    // Rating · year · runtime: two dots, and no outlined box.
    expect(find.text('·'), findsNWidgets(2));
    expect(
      find.descendant(
        of: find.byType(BackdropHeader),
        matching: find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration! as BoxDecoration).border != null,
        ),
      ),
      findsNothing,
    );
  });
}
