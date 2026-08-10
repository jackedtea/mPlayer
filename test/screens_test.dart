// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:mplayer/app/app.dart';
import 'package:mplayer/app/router.dart';

/// The three widths the design fixes behaviour at. Every screen is checked at
/// all three, because a layout that only works on a phone is not done.
const _sizes = <String, Size>{
  'phone': Size(400, 800),
  'tablet': Size(900, 1000),
  'desktop': Size(1400, 900),
};

/// Every reachable destination. `/player` is excluded — it needs a resolved
/// handle passed as `extra`, and its no-handle fallback is covered separately.
const _routes = <String>[
  '/storage',
  '/server',
  '/search',
  '/settings',
  '/settings/appearance',
  '/settings/player',
  '/settings/subtitle',
  '/settings/about',
  '/server/home',
  '/library',
  '/library/movie',
  '/library/series',
  '/browse?name=NAS',
  '/downloads',
];

Future<GoRouter> pumpRouterAt(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);

  final router = buildRouter();
  await tester.pumpWidget(ProviderScope(child: MPlayerApp(router: router)));
  await tester.pumpAndSettle();
  return router;
}

void main() {
  group('every screen renders without layout errors', () {
    for (final MapEntry<String, Size> entry in _sizes.entries) {
      for (final String route in _routes) {
        testWidgets('$route on ${entry.key}', (tester) async {
          final router = await pumpRouterAt(tester, entry.value);

          router.go(route);
          await tester.pumpAndSettle();

          // A RenderFlex overflow, a failed assertion or an unbounded
          // constraint would all land here.
          expect(
            tester.takeException(),
            isNull,
            reason: '$route overflowed or threw at ${entry.key}',
          );
          expect(find.byType(Scaffold), findsWidgets);
        });
      }
    }
  });

  testWidgets('/player without a handle explains itself instead of going black',
      (tester) async {
    final router = await pumpRouterAt(tester, const Size(400, 800));

    router.go('/player');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Nothing to play'), findsOneWidget);
  });

  group('search', () {
    testWidgets('submitting a query swaps the idle list for grouped results',
        (tester) async {
      final router = await pumpRouterAt(tester, const Size(400, 900));
      router.go('/search');
      await tester.pumpAndSettle();

      expect(find.text('Where to look'), findsOneWidget);

      await tester.enterText(find.byType(SearchBar), 'harbour');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Results are grouped per source, never merged into one ranked list.
      expect(find.text('Where to look'), findsNothing);
      expect(find.textContaining('Jellyfin · media.home.lan'), findsWidgets);
      expect(find.textContaining('NAS · SMB'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('clearing the query returns to the scope picker',
        (tester) async {
      final router = await pumpRouterAt(tester, const Size(400, 900));
      router.go('/search');
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(SearchBar), 'harbour');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Where to look'), findsOneWidget);
    });
  });

  group('library grid', () {
    testWidgets('the Unwatched chip actually filters', (tester) async {
      final router = await pumpRouterAt(tester, const Size(400, 900));
      router.go('/library');
      await tester.pumpAndSettle();

      // Sample data has two watched titles, hidden while the chip is on.
      expect(find.text('Low Tide'), findsNothing);

      await tester.tap(find.widgetWithText(FilterChip, 'Unwatched'));
      await tester.pumpAndSettle();

      expect(find.text('Low Tide'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
