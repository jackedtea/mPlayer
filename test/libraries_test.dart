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
}

Future<GoRouter> _openLibraries(
  WidgetTester tester, {
  Map<String, String>? remembered,
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
      overrides: [
        activeServerProvider.overrideWithValue(const _TwoLibraries()),
      ],
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
  testWidgets('opens the first library when none has been browsed',
      (tester) async {
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

  testWidgets('a library remembered for another server is not used',
      (tester) async {
    await _openLibraries(tester, remembered: <String, String>{'p9': 'tv'});

    expect(_titled('Films'), findsOneWidget);
  });

  testWidgets('the title switches library, and the choice is remembered',
      (tester) async {
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
}
