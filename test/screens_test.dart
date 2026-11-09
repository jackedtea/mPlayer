// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
///
/// `/files` and `/browse` are gone with the device library.
const _routes = <String>[
  '/home',
  '/libraries',
  '/downloads',
  '/search',
  '/settings',
  '/settings/appearance',
  '/settings/general',
  '/settings/player',
  '/settings/audio',
  '/settings/subtitle',
  '/settings/downloads',
  '/settings/about',
  '/settings/diagnostics',
  '/settings/privacy',
  '/library',
  '/library/movie',
  '/library/series',
  '/library/episode',
  '/library/person',
  '/library/album',
  '/library/artist',
  // Nothing playing, which it has to say rather than draw empty controls.
  '/now-playing',
  // With nothing signed in these draw their guard rather than a dashboard,
  // which is exactly the state worth pumping: an administration screen opened
  // by someone who is not one must still lay out.
  '/admin',
  '/admin/tasks',
  '/admin/users',
  '/admin/users/u1',
  '/admin/libraries',
  '/admin/item/i1',
  '/admin/activity',
  '/admin/plugins',
  // Nothing found, which is the face a phone shows first.
  '/remote',
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
  // Recent searches are kept in preferences now.
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

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

      await tester.enterText(find.byType(SearchBar), 'harbour');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // With no server signed in this says where to open one, rather than
      // claiming the server had nothing — there is no server to have asked.
      expect(find.text('Open a server from the Home tab first.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('clearing the query returns to the idle state',
        (tester) async {
      final router = await pumpRouterAt(tester, const Size(400, 900));
      router.go('/search');
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(SearchBar), 'harbour');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      // The query ran, so it is in the recents list the idle state shows.
      expect(find.text('Recent searches'), findsOneWidget);
      expect(find.text('Nothing matched that'), findsNothing);
    });

    testWidgets('the scope picker is gone with the sources it scoped',
        (tester) async {
      final router = await pumpRouterAt(tester, const Size(400, 900));
      router.go('/search');
      await tester.pumpAndSettle();

      expect(find.text('Where to look'), findsNothing);
      expect(find.byType(Checkbox), findsNothing);
    });
  });

  group('library grid', () {
    testWidgets('opens showing everything, with the filter off', (tester) async {
      final router = await pumpRouterAt(tester, const Size(400, 900));
      router.go('/library');
      await tester.pumpAndSettle();

      // A library opens showing its whole contents: nothing narrowed, so no
      // chip saying what is.
      expect(find.byType(InputChip), findsNothing);

      // Nothing is signed in here, so the grid is empty and says so rather
      // than rendering sample titles.
      expect(find.text('0 items'), findsOneWidget);

      await tester.tap(find.byTooltip('Sort & filter'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'Unwatched'));
      await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
      await tester.pumpAndSettle();

      expect(find.text('0 unwatched'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
