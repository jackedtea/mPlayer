// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_library_source.dart';

import 'package:mplayer/app/app.dart';
import 'package:mplayer/app/router.dart';
import 'package:mplayer/features/servers/server_library.dart';
import 'package:mplayer/servers/media_library_source.dart';

/// A TV library: one ended series, one still running, one with no year.
class _Shows extends FakeLibrarySource {
  const _Shows();

  @override
  Future<List<LibraryView>> views() async => const <LibraryView>[
        LibraryView(id: 'tv', name: 'Television', kind: 'tvshows'),
      ];

  @override
  Future<List<ServerItem>> items(
    String viewId, {
    int startIndex = 0,
    int limit = 100,
    ServerSort sort = ServerSort.name,
    SortOrder? order,
    LibraryFilter filter = LibraryFilter.none,
  }) async =>
      const <ServerItem>[
        ServerItem(
          id: 's1',
          title: 'Over and done',
          kind: ServerItemKind.series,
          year: 2019,
          endYear: 2023,
          status: 'Ended',
          episodeCount: 40,
        ),
        ServerItem(
          id: 's2',
          title: 'Still going',
          kind: ServerItemKind.series,
          year: 2024,
          status: 'Continuing',
          episodeCount: 12,
        ),
        ServerItem(id: 's3', title: 'Undated', kind: ServerItemKind.series),
      ];
}

Future<void> _open(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);

  final router = buildRouter();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [activeServerProvider.overrideWithValue(const _Shows())],
      child: MPlayerApp(router: router),
    ),
  );
  await tester.pumpAndSettle();
  router.push('/library?title=Television', extra: 'tv');
  await tester.pumpAndSettle();
}

Future<void> _toggle(WidgetTester tester, String label) async {
  await tester.tap(find.byTooltip('View options'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(SwitchListTile, label));
  await tester.pumpAndSettle();
  await tester.tapAt(const Offset(10, 10));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  for (final Size size in const <Size>[
    Size(400, 900),
    Size(900, 1000),
    Size(1400, 900),
  ]) {
    testWidgets('cards carry year, status and count at '
        '${size.width.toInt()}px', (tester) async {
      await _open(tester, size);

      expect(tester.takeException(), isNull);
      // An ended series reads as its span; a running one as its start.
      expect(find.text('2019–2023 · Ended'), findsOneWidget);
      expect(find.text('2024 · Continuing'), findsOneWidget);
      // Episodes across every season, not ChildCount's seasons.
      expect(find.text('40 ep'), findsOneWidget);
      expect(find.text('12 ep'), findsOneWidget);
    });
  }

  testWidgets('each fact can be turned off on its own, and stays off',
      (tester) async {
    await _open(tester, const Size(400, 900));

    await _toggle(tester, 'Status');
    expect(find.text('2019–2023'), findsOneWidget);
    expect(find.textContaining('Ended'), findsNothing);

    await _toggle(tester, 'Number of items');
    expect(find.text('40 ep'), findsNothing);

    await _toggle(tester, 'Year');
    expect(find.text('2019–2023'), findsNothing);
    expect(tester.takeException(), isNull);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('library_card_year'), isFalse);
    expect(prefs.getBool('library_card_count'), isFalse);
    expect(prefs.getBool('library_card_status'), isFalse);
  });

  testWidgets('posters per row moved into the same sheet', (tester) async {
    await _open(tester, const Size(400, 900));

    await tester.tap(find.byTooltip('View options'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ChoiceChip, '4 per row'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, '4 per row'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('library_columns_v1'), 4);
  });
}
