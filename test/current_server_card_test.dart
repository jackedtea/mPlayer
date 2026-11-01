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
import 'package:mplayer/features/servers/servers_list_page.dart';
import 'package:mplayer/servers/server_registry.dart';

/// Signed in already, without the keychain the real registry reads.
class _SignedInRegistry extends ServerRegistry {
  @override
  ServerRegistryState build() => const ServerRegistryState(
        profiles: [fakeServerProfile],
        activeId: 'p1',
        source: FakeLibrarySource(),
        loading: false,
      );
}

Future<GoRouter> _pump(WidgetTester tester, Size size) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);

  final router = buildRouter();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [serverRegistryProvider.overrideWith(_SignedInRegistry.new)],
      child: MPlayerApp(router: router),
    ),
  );
  await tester.pumpAndSettle();
  router.go('/settings');
  await tester.pumpAndSettle();
  return router;
}

void main() {
  for (final Size size in const <Size>[Size(360, 800), Size(1400, 900)]) {
    testWidgets('names the server at the top at ${size.width.toInt()}px',
        (tester) async {
      await _pump(tester, size);

      expect(tester.takeException(), isNull);
      expect(find.text('Home'), findsWidgets);
      expect(find.text('media.home.lan'), findsOneWidget);
      expect(find.text('nam'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Edit server'), findsOneWidget);

      // Above the first section, which is the point of putting it there.
      expect(
        tester.getTopLeft(find.text('media.home.lan')).dy,
        lessThan(tester.getTopLeft(find.text('App settings')).dy),
      );
    });
  }

  testWidgets('switching goes back to the server list on Home',
      (tester) async {
    await _pump(tester, const Size(400, 900));

    await tester.tap(find.text('Switch server'));
    await tester.pumpAndSettle();

    expect(find.byType(ServersListPage), findsOneWidget);
  });

  testWidgets('edit opens the server sheet on this server', (tester) async {
    await _pump(tester, const Size(400, 900));

    await tester.tap(find.widgetWithText(OutlinedButton, 'Edit server'));
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(TextField, 'Server address'),
      findsOneWidget,
    );
    expect(find.text('https://media.home.lan'), findsOneWidget);
  });
}
