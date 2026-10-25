// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

/// The server UI has to be driveable with one thumb on a tall phone.
///
/// These tests assert **where things land**, not merely that they exist. A
/// button is reachable or it is not, and "a Play button is somewhere on this
/// screen" is exactly the assertion that let the old layout put it in the
/// middle of a 6.7-inch display. So the checks here measure rectangles
/// against the bottom of the window.
///
/// The threshold is the bottom **40%** of the screen. That is deliberately
/// generous rather than a precise thumb arc: the point is to catch a control
/// drifting back up into the top half, not to pin it to a pixel.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'fake_library_source.dart';

import 'package:mplayer/app/app.dart';
import 'package:mplayer/app/router.dart';
import 'package:mplayer/features/servers/item_action_row.dart';
import 'package:mplayer/features/servers/server_library.dart';
import 'package:mplayer/servers/media_library_source.dart';

const _phone = Size(400, 900);
const _tablet = Size(900, 1000);

Future<GoRouter> _pump(
  WidgetTester tester,
  Size size, {
  MediaLibrarySource? server,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);

  final router = buildRouter();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (server != null) activeServerProvider.overrideWithValue(server),
      ],
      child: MPlayerApp(router: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

/// How far down the window [finder]'s centre sits, as a fraction.
double _verticalPosition(WidgetTester tester, Finder finder) {
  final height = tester.view.physicalSize.height / tester.view.devicePixelRatio;
  return tester.getCenter(finder).dy / height;
}

void main() {
  group('settings is a destination, not a corner', () {
    testWidgets('it is in the bottom navigation bar', (tester) async {
      await _pump(tester, _phone);

      final bar = find.byType(NavigationBar);
      expect(bar, findsOneWidget);

      // Three destinations again, as the design asked for — Storage left a
      // gap when the device library went, and Settings fills it.
      expect(
        find.descendant(of: bar, matching: find.byType(NavigationDestination)),
        findsNWidgets(3),
      );
      expect(
        find.descendant(of: bar, matching: find.text('Settings')),
        findsOneWidget,
      );

      // And it is where a thumb is, which is the whole reason it moved.
      expect(
        _verticalPosition(tester, find.text('Settings')),
        greaterThan(0.6),
      );
    });

    testWidgets('no server screen carries a settings button up top',
        (tester) async {
      await _pump(tester, _phone);

      // The empty state is what `/servers` shows with nothing signed in, and
      // it used to put Settings in the top-right corner. So did the list
      // behind it.
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byIcon(Icons.settings_rounded),
        ),
        findsNothing,
      );
    });

    testWidgets('opening it keeps the navigation bar in reach', (tester) async {
      await _pump(tester, _phone);

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'Settings'), findsOneWidget);

      // The point of nesting the settings pages inside the branch: leaving
      // is another thumb-press on the bar, not a reach for a back arrow.
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byIcon(Icons.arrow_back_rounded),
        ),
        findsNothing,
      );
    });
  });

  group('the primary action on a detail screen', () {
    testWidgets('sits at the foot of a phone', (tester) async {
      final router = await _pump(tester, _phone, server: const _FakeServer());
      router.push('/library/movie', extra: 'm1');
      await tester.pumpAndSettle();

      expect(find.byType(ItemPrimaryActionBar), findsOneWidget);

      final play = find.widgetWithText(FilledButton, 'Play');
      expect(play, findsOneWidget);
      expect(_verticalPosition(tester, play), greaterThan(0.6));
    });

    testWidgets('stays put when the page is scrolled', (tester) async {
      // The failure this guards: the button used to live under a 268dp
      // backdrop, so reading the overview scrolled the only thing the screen
      // exists for off the display.
      final router = await _pump(tester, _phone, server: const _FakeServer());
      router.push('/library/movie', extra: 'm1');
      await tester.pumpAndSettle();

      // The vertical one: the action chips under the backdrop are a
      // horizontal ListView, so `byType` alone matches two.
      final page = find.byWidgetPredicate(
        (w) => w is ListView && w.scrollDirection == Axis.vertical,
      );
      await tester.drag(page, const Offset(0, -400));
      await tester.pumpAndSettle();

      final play = find.widgetWithText(FilledButton, 'Play');
      expect(play, findsOneWidget);
      expect(_verticalPosition(tester, play), greaterThan(0.6));
    });

    testWidgets('goes back inline on a tablet', (tester) async {
      // Nobody holds a tablet in one hand, and the design puts the action row
      // under the backdrop. So the bar is a phone affordance only.
      final router = await _pump(tester, _tablet, server: const _FakeServer());
      router.push('/library/movie', extra: 'm1');
      await tester.pumpAndSettle();

      expect(find.byType(ItemPrimaryActionBar), findsNothing);
      expect(find.byType(ItemActionRow), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Play'), findsOneWidget);
    });

    testWidgets('is not drawn twice', (tester) async {
      // `primary: false` on the inline row is what stops the phone showing
      // one Play under the backdrop and another in the bar.
      final router = await _pump(tester, _phone, server: const _FakeServer());
      router.push('/library/movie', extra: 'm1');
      await tester.pumpAndSettle();

      expect(find.widgetWithText(FilledButton, 'Play'), findsOneWidget);
    });
  });

  group('search is reachable from the browse screens', () {
    testWidgets('the library grid offers it as a button near the thumb',
        (tester) async {
      final router = await _pump(tester, _phone, server: const _FakeServer());
      router.push('/library', extra: 'v1');
      await tester.pumpAndSettle();

      final fab = find.byType(FloatingActionButton);
      expect(fab, findsOneWidget);
      expect(_verticalPosition(tester, fab), greaterThan(0.6));

      // And no longer in the corner it used to sit in.
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byIcon(Icons.search_rounded),
        ),
        findsNothing,
      );
    });

    testWidgets('so does the server home', (tester) async {
      final router = await _pump(tester, _phone, server: const _FakeServer());
      router.push('/servers/home');
      await tester.pumpAndSettle();

      final fab = find.byType(FloatingActionButton);
      expect(fab, findsOneWidget);
      expect(_verticalPosition(tester, fab), greaterThan(0.6));

      // The cast button that used to sit beside it was a stub that reported
      // "not implemented"; casting belongs to the player, which has the
      // stream and the position to start it from.
      expect(find.byIcon(Icons.cast_rounded), findsNothing);
    });
  });
}

class _FakeServer extends FakeLibrarySource {
  const _FakeServer();

  static const movie = ServerItem(
    id: 'm1',
    title: 'The Harbour Line',
    kind: ServerItemKind.movie,
    year: 2024,
    rating: 8.1,
    certificate: 'PG-13',
    overview:
        'A long overview, so that the page has something to scroll and the '
        'test can show the action bar staying where it is while it does. '
        'It runs on for a few lines to make sure the list is taller than '
        'the window it is drawn in, which is the whole point of it.',
    genres: <String>['Drama', 'Thriller'],
  );

  @override
  Future<ServerItem> item(String itemId) async => movie;
}
