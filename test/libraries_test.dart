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

import 'fake_library_source.dart';

import 'package:mplayer/app/app.dart';
import 'package:mplayer/app/router.dart';
import 'package:mplayer/features/servers/server_library.dart';
import 'package:mplayer/servers/media_library_source.dart';

class _TwoLibraries extends FakeLibrarySource {
  const _TwoLibraries();

  @override
  Future<List<LibraryView>> views() async => const <LibraryView>[
    LibraryView(id: 'films', name: 'Films', kind: 'movies'),
    LibraryView(id: 'tv', name: 'Television', kind: 'tvshows'),
  ];

  /// Far more than one page, which is the point.
  @override
  Future<int> itemCount(String viewId) async => 1234;

  /// Always a full page, as a large library answers.
  @override
  Future<List<ServerItem>> items(
    String viewId, {
    int startIndex = 0,
    int limit = 100,
    ServerSort sort = ServerSort.name,
    SortOrder? order,
    LibraryFilter filter = LibraryFilter.none,
  }) async => <ServerItem>[
    for (var i = 0; i < limit; i++) ServerItem(id: '$i', title: 'Film $i'),
  ];
}

/// Counts how often the grid is asked for.
class _CountingLibraries extends _TwoLibraries {
  _CountingLibraries();

  int asks = 0;

  @override
  Future<List<ServerItem>> items(
    String viewId, {
    int startIndex = 0,
    int limit = 100,
    ServerSort sort = ServerSort.name,
    SortOrder? order,
    LibraryFilter filter = LibraryFilter.none,
  }) {
    asks++;
    return super.items(
      viewId,
      startIndex: startIndex,
      limit: limit,
      sort: sort,
      order: order,
      filter: filter,
    );
  }
}

Future<GoRouter> _openLibraries(
  WidgetTester tester, {
  Map<String, String>? remembered,
  MediaLibrarySource source = const _TwoLibraries(),
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    if (remembered != null) 'last_library_by_server': jsonEncode(remembered),
  });
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(400, 900);
  addTearDown(tester.view.reset);

  final router = buildRouter();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [activeServerProvider.overrideWithValue(source)],
      child: MPlayerApp(router: router),
    ),
  );
  await tester.pumpAndSettle();
  router.go('/libraries');
  await tester.pumpAndSettle();
  return router;
}

/// The library named in the app bar's switcher.
Finder _titled(String name) =>
    find.descendant(of: find.byType(AppBar), matching: find.text(name));

void main() {
  testWidgets('Refresh asks the server for the grid again', (tester) async {
    final source = _CountingLibraries();
    await _openLibraries(tester, source: source);
    final before = source.asks;

    await tester.tap(find.byTooltip('Refresh'));
    await tester.pumpAndSettle();

    expect(source.asks, greaterThan(before));
  });

  testWidgets('opens the first library when none has been browsed', (
    tester,
  ) async {
    await _openLibraries(tester);

    expect(_titled('Films'), findsOneWidget);
    // Straight into it: no list of libraries in front, and nothing behind it
    // to go back to.
    expect(find.widgetWithText(Tab, 'Browse'), findsOneWidget);
    expect(find.byTooltip('Back'), findsNothing);
  });

  testWidgets('opens the library last browsed on this server', (tester) async {
    await _openLibraries(tester, remembered: <String, String>{'p1': 'tv'});

    expect(_titled('Television'), findsOneWidget);
  });

  testWidgets('a library remembered for another server is not used', (
    tester,
  ) async {
    await _openLibraries(tester, remembered: <String, String>{'p9': 'tv'});

    expect(_titled('Films'), findsOneWidget);
  });

  testWidgets('the title switches library, and the choice is remembered', (
    tester,
  ) async {
    await _openLibraries(tester);

    await tester.tap(_titled('Films'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Television'));
    await tester.pumpAndSettle();

    expect(_titled('Television'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    expect(
      jsonDecode(prefs.getString('last_library_by_server')!),
      <String, String>{'p1': 'tv'},
    );
  });

  group('the count in the title', () {
    testWidgets('is the real total of the library, not the page in hand', (
      tester,
    ) async {
      await _openLibraries(tester);

      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('1234 items'),
        ),
        findsOneWidget,
      );
      // And nowhere down in the grid any more.
      expect(find.text('100 items'), findsNothing);
    });

    testWidgets('a filtered full page says it may be more', (tester) async {
      await _openLibraries(tester);

      await tester.tap(find.byTooltip('Sort & filter'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'Unwatched'));
      await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('100+ items'),
        ),
        findsOneWidget,
      );
    });
  });
}
