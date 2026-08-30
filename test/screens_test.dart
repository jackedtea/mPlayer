// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mplayer/app/app.dart';
import 'package:mplayer/app/router.dart';
import 'package:mplayer/core/models/library_models.dart';
import 'package:mplayer/core/models/media_models.dart';
import 'package:mplayer/features/browse/browse_controller.dart';
import 'package:mplayer/sources/source_config.dart';
import 'package:mplayer/widgets/source_tile.dart';

import 'fake_keychain.dart';

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
  '/files',
  '/servers',
  '/search',
  '/settings',
  '/settings/appearance',
  '/settings/general',
  '/settings/player',
  '/settings/audio',
  '/settings/subtitle',
  '/settings/about',
  '/settings/diagnostics',
  '/settings/privacy',
  '/servers/home',
  '/library',
  '/library/movie',
  '/library/series',
  '/library/episode',
  '/library/person',
  '/browse?source=device',
  '/downloads',
  // With nothing signed in these draw their guard rather than a dashboard,
  // which is exactly the state worth pumping: an administration screen opened
  // by someone who is not one must still lay out.
  '/admin',
  '/admin/tasks',
  '/admin/users',
  '/admin/activity',
  '/admin/plugins',
];

/// Stand-in directory listing.
///
/// Without this the browser walks the real filesystem: the spinner animates
/// forever, `pumpAndSettle` times out, and the test reads the machine it runs
/// on. Drivers are covered by their own tests instead.
const _stubListing = BrowseListing(
  path: '/media',
  entries: <BrowseEntry>[
    BrowseEntry(
      name: 'Short films',
      kind: BrowseEntryKind.folder,
      path: '/media/Short films',
      detail: 'Folder',
    ),
    BrowseEntry(
      name: 'The Harbour Line.mkv',
      kind: BrowseEntryKind.video,
      path: '/media/The Harbour Line.mkv',
      sizeBytes: 19783286784,
      detail: '18.4 GB',
    ),
  ],
);

Future<GoRouter> pumpRouterAt(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);

  final router = buildRouter();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        directoryListingProvider.overrideWith((ref, arg) async => _stubListing),
      ],
      child: MPlayerApp(router: router),
    ),
  );
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

      // The idle scope picker gives way to results — which, with no server
      // signed in, is the empty answer rather than sample groups.
      expect(find.text('Where to look'), findsNothing);
      expect(find.text('Nothing matched that'), findsOneWidget);
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
    testWidgets('opens showing everything, with the filter off', (tester) async {
      final router = await pumpRouterAt(tester, const Size(400, 900));
      router.go('/library');
      await tester.pumpAndSettle();

      // A library opens showing its whole contents. Hiding most of a
      // collection until the user notices a chip is the wrong first
      // impression, so Unwatched starts off.
      final chip = tester.widget<FilterChip>(
        find.widgetWithText(FilterChip, 'Unwatched'),
      );
      expect(chip.selected, isFalse);

      // Nothing is signed in here, so the grid is empty and says so rather
      // than rendering sample titles.
      expect(find.text('0 items'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilterChip, 'Unwatched'));
      await tester.pumpAndSettle();

      expect(find.text('0 unwatched'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('editing a configured share', () {
    const share = SourceConfig(
      id: 'webdav_1',
      kind: SourceKind.webdav,
      name: 'NAS',
      uri: 'https://old.home.lan/dav',
      username: 'minh',
    );

    setUp(() {
      // The sheet reads the saved password to prefill its field, so the
      // keychain has to answer for the flow to be exercised at all.
      installFakeKeychain(<String, String>{share.credentialKey: 'hunter2'});
      SharedPreferences.setMockInitialValues(<String, Object>{
        'configured_sources_v1': <String>[jsonEncode(share.toJson())],
      });
    });

    testWidgets('the sheet opens filled in and saves back to the tile',
        (tester) async {
      // Tall enough that the Network section needs no scrolling.
      final router = await pumpRouterAt(tester, const Size(420, 1600));
      router.go('/files');
      await tester.pumpAndSettle();

      // Scoped to the tile: the Continue-watching card carries a "NAS" badge
      // of its own.
      expect(find.widgetWithText(SourceTile, 'NAS'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit share'));
      await tester.pumpAndSettle();

      // Every field arrives populated — a share is usually wrong in one place,
      // and retyping the rest to fix it is what this feature exists to avoid.
      // Read through the controller: a field's hint carries the same text as
      // its value here, so a text finder would match twice.
      String field(String label) => tester
          .widget<TextField>(
            find.byWidgetPredicate(
              (w) => w is TextField && w.decoration?.labelText == label,
            ),
          )
          .controller!
          .text;

      expect(field('Name'), 'NAS');
      expect(field('Address'), 'https://old.home.lan/dav');
      expect(field('Username'), 'minh');
      expect(field('Password'), 'hunter2');

      await tester.enterText(find.byType(TextField).first, 'Nextcloud');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNothing, reason: 'sheet stays open');
      expect(find.widgetWithText(SourceTile, 'Nextcloud'), findsOneWidget);
      expect(find.widgetWithText(SourceTile, 'NAS'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
