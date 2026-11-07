// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

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

class _Server extends FakeLibrarySource {
  const _Server();

  @override
  Future<List<LibraryView>> views() async => const <LibraryView>[
    LibraryView(id: 'v1', name: 'Films', kind: 'movies'),
  ];
}

Future<GoRouter> _launch(
  WidgetTester tester, {
  Map<String, Object> prefs = const <String, Object>{},
  MediaLibrarySource? server = const _Server(),
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(400, 800);
  addTearDown(tester.view.reset);

  final router = buildRouter();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [activeServerProvider.overrideWithValue(server)],
      child: MPlayerApp(router: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  testWidgets('opens on Home with nothing chosen', (tester) async {
    final router = await _launch(tester);
    expect(router.state.uri.path, '/home');
  });

  testWidgets('opens on the tab chosen', (tester) async {
    final router = await _launch(
      tester,
      prefs: <String, Object>{'start_tab': 'libraries'},
    );
    expect(router.state.uri.path, '/libraries');
  });

  testWidgets('with no server open it stays Home, where one gets opened', (
    tester,
  ) async {
    final router = await _launch(
      tester,
      prefs: <String, Object>{'start_tab': 'libraries'},
      server: null,
    );
    expect(router.state.uri.path, '/home');
  });

  testWidgets('remembering prefers the last tab over the chosen one', (
    tester,
  ) async {
    final router = await _launch(
      tester,
      prefs: <String, Object>{
        'start_tab': 'libraries',
        'start_tab_remember_last': true,
        'start_tab_last': 'search',
      },
    );
    expect(router.state.uri.path, '/search');
  });

  testWidgets('remembering with no last tab yet uses the chosen one', (
    tester,
  ) async {
    final router = await _launch(
      tester,
      prefs: <String, Object>{
        'start_tab': 'downloads',
        'start_tab_remember_last': true,
      },
    );
    expect(router.state.uri.path, '/downloads');
  });

  testWidgets('a stored tab this version has never heard of is Home', (
    tester,
  ) async {
    final router = await _launch(
      tester,
      prefs: <String, Object>{'start_tab': 'files'},
    );
    expect(router.state.uri.path, '/home');
  });

  testWidgets('every move is noted, including back to Home', (tester) async {
    await _launch(tester);
    final prefs = await SharedPreferences.getInstance();

    Future<void> tap(IconData icon) async {
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.byIcon(icon),
        ),
      );
      await tester.pumpAndSettle();
    }

    await tap(Icons.search_rounded);
    expect(prefs.getString('start_tab_last'), 'search');

    await tap(Icons.home_outlined);
    expect(prefs.getString('start_tab_last'), 'home');
  });

  group('General settings', () {
    Future<GoRouter> openGeneral(WidgetTester tester) async {
      final router = await _launch(tester);
      router.go('/settings/general');
      await tester.pumpAndSettle();
      return router;
    }

    testWidgets('choosing a tab saves it', (tester) async {
      await openGeneral(tester);

      await tester.tap(find.text('Tab when opening the app'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('Downloads'),
        ),
      );
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('start_tab'), 'downloads');
    });

    testWidgets('remembering saves it and takes the choice away', (
      tester,
    ) async {
      await openGeneral(tester);

      await tester.tap(find.text('Remember last tab'));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('start_tab_remember_last'), isTrue);

      await tester.tap(find.text('Tab when opening the app'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
    });
  });
}
