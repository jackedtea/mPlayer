// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.


import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_library_source.dart';

import 'package:mplayer/app/app.dart';
import 'package:mplayer/app/theme.dart';
import 'package:mplayer/app/tokens.dart';
import 'package:mplayer/features/servers/server_library.dart';

/// Pumps the real app at a specific logical window size.
///
/// The design fixes behaviour at three widths, so every shell test states the
/// width it is asserting about rather than relying on the default 800x600.
/// [connected] opens a server, which is what puts the navigation up: while
/// Home is choosing one there is none.
Future<void> pumpAppAt(
  WidgetTester tester,
  Size size, {
  bool connected = false,
}) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (connected)
          activeServerProvider.overrideWithValue(const FakeLibrarySource()),
      ],
      child: const MPlayerApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('theme', () {
    test('light scheme matches the design tokens', () {
      final scheme = buildTheme(Brightness.light).colorScheme;

      expect(scheme.brightness, Brightness.light);
      expect(scheme.primary, const Color(0xFF00658F));
      expect(scheme.primaryContainer, const Color(0xFFC7E7FF));
      expect(scheme.surface, const Color(0xFFF6FAFE));
      expect(scheme.onSurfaceVariant, const Color(0xFF41484D));
      expect(scheme.outline, const Color(0xFF71787E));
    });

    test('dark scheme matches the design tokens', () {
      final scheme = buildTheme(Brightness.dark).colorScheme;

      expect(scheme.brightness, Brightness.dark);
      expect(scheme.primary, const Color(0xFF82CFFF));
      expect(scheme.primaryContainer, const Color(0xFF004C6D));
      expect(scheme.surface, const Color(0xFF0F1417));
      expect(scheme.surfaceContainer, const Color(0xFF1A2125));
    });

    test('both brightnesses carry the token extensions', () {
      for (final brightness in Brightness.values) {
        final theme = buildTheme(brightness);
        expect(theme.extension<AppSpacing>(), isNotNull);
        expect(theme.extension<AppRadii>(), isNotNull);
        expect(theme.extension<AppSemanticColors>(), isNotNull);
      }
    });
  });

  group('window size classes', () {
    test('boundaries follow the adaptive-layout table', () {
      expect(WindowSize.fromWidth(599), WindowSize.compact);
      expect(WindowSize.fromWidth(600), WindowSize.medium);
      expect(WindowSize.fromWidth(1239), WindowSize.medium);
      expect(WindowSize.fromWidth(1240), WindowSize.large);
    });

    test('screen padding is 16 except on desktop, where it is 24', () {
      const spacing = AppSpacing();
      expect(spacing.screenHorizontal(WindowSize.compact), 16);
      expect(spacing.screenHorizontal(WindowSize.medium), 16);
      expect(spacing.screenHorizontal(WindowSize.large), 24);
    });
  });

  group('adaptive shell', () {
    testWidgets('phone width uses a NavigationBar', (tester) async {
      await pumpAppAt(tester, const Size(400, 800), connected: true);

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.byType(NavigationDrawer), findsNothing);
    });

    testWidgets('tablet width uses a NavigationRail', (tester) async {
      await pumpAppAt(tester, const Size(900, 1000), connected: true);

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('desktop width uses a NavigationDrawer', (tester) async {
      await pumpAppAt(tester, const Size(1400, 900), connected: true);

      expect(find.byType(NavigationDrawer), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(NavigationRail), findsNothing);
    });
  });

  group('startup', () {
    testWidgets('opens on Home as an empty state, not a login wall',
        (tester) async {
      // It used to open on Files, so the app had something to play before any
      // server existed. There is nothing local to play now, so Home is the
      // first screen — and it still has to be an empty state that offers to
      // add one, never a gate that demands it.
      await pumpAppAt(tester, const Size(400, 800));

      expect(find.text('No media server yet'), findsOneWidget);
      expect(find.text('Add Jellyfin server'), findsOneWidget);
      // Network scanning was dropped, so the button that promised it is gone
      // rather than left reporting that it does nothing.
      expect(find.text('Scan this network'), findsNothing);
    });

    testWidgets('choosing a server offers no other destination',
        (tester) async {
      // Every other tab browses a server, so before one is open they would
      // each only say "open a server first".
      for (final Size size in const <Size>[
        Size(400, 800),
        Size(900, 1000),
        Size(1400, 900),
      ]) {
        await pumpAppAt(tester, size);
        expect(find.byType(NavigationBar), findsNothing);
        expect(find.byType(NavigationRail), findsNothing);
        expect(find.byType(NavigationDrawer), findsNothing);
      }
    });

    testWidgets('there is no Files destination left', (tester) async {
      await pumpAppAt(tester, const Size(400, 800), connected: true);

      expect(find.text('Files'), findsNothing);
      for (final String label in <String>[
        'Home',
        'Libraries',
        'Search',
        'Downloads',
        'Settings',
      ]) {
        expect(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text(label),
          ),
          findsOneWidget,
          reason: label,
        );
      }
    });

    testWidgets('add-server sheet asks for an address before anything else', (
      tester,
    ) async {
      await pumpAppAt(tester, const Size(400, 900));

      await tester.tap(find.text('Add Jellyfin server'));
      await tester.pumpAndSettle();

      // The heading is translated now, so it reads as the ARB spells it.
      expect(find.text('Add server'), findsOneWidget);
      expect(find.text('Enter an address to detect the server'), findsOneWidget);

      // Username and password are the path that always works, so they are
      // what the sheet opens on.
      expect(find.widgetWithText(TextField, 'Username'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Password'), findsOneWidget);

      // Quick Connect is *not* offered yet: nothing is known about the
      // server, and a Jellyfin administrator can switch the feature off. Offering it before
      // asking would be a switch that sometimes cannot work.
      expect(find.byType(SegmentedButton<bool>), findsNothing);

      // Connect stays disabled until an address has been detected.
      final connect = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Connect'),
      );
      expect(connect.onPressed, isNull);
    });
  });
}
