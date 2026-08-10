// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mplayer/app/app.dart';
import 'package:mplayer/app/theme.dart';
import 'package:mplayer/app/tokens.dart';
import 'package:mplayer/widgets/gradient_art.dart';

/// Pumps the real app at a specific logical window size.
///
/// The design fixes behaviour at three widths, so every shell test states the
/// width it is asserting about rather than relying on the default 800x600.
Future<void> pumpAppAt(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(const ProviderScope(child: MPlayerApp()));
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
      await pumpAppAt(tester, const Size(400, 800));

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.byType(NavigationDrawer), findsNothing);
    });

    testWidgets('tablet width uses a NavigationRail', (tester) async {
      await pumpAppAt(tester, const Size(900, 1000));

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('desktop width uses a NavigationDrawer', (tester) async {
      await pumpAppAt(tester, const Size(1400, 900));

      expect(find.byType(NavigationDrawer), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(NavigationRail), findsNothing);
    });
  });

  group('startup', () {
    testWidgets('opens on Storage with no server gate', (tester) async {
      await pumpAppAt(tester, const Size(400, 800));

      // The Storage app bar title, not a login screen.
      expect(find.widgetWithText(AppBar, 'Storage'), findsOneWidget);
      expect(find.text('Continue watching'), findsOneWidget);
      expect(find.text('This device'), findsOneWidget);
    });

    testWidgets('Server tab is an opt-in empty state, not a login wall', (
      tester,
    ) async {
      await pumpAppAt(tester, const Size(400, 800));

      await tester.tap(find.text('Server'));
      await tester.pumpAndSettle();

      expect(find.text('No media server yet'), findsOneWidget);
      expect(find.text('Add Jellyfin server'), findsOneWidget);
      expect(find.text('Scan this network'), findsOneWidget);
    });

    testWidgets('add-server sheet opens and defaults to Quick Connect', (
      tester,
    ) async {
      await pumpAppAt(tester, const Size(400, 900));

      await tester.tap(find.text('Server'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add Jellyfin server'));
      await tester.pumpAndSettle();

      expect(find.text('Add a server'), findsOneWidget);

      final quickConnect = tester.widget<SwitchListTile>(
        find.byType(SwitchListTile),
      );
      expect(quickConnect.value, isTrue);

      // Quick Connect approves on another device, so no password field.
      expect(find.widgetWithText(TextField, 'Password'), findsNothing);

      // Connect stays disabled until an address is entered.
      final connect = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Connect'),
      );
      expect(connect.onPressed, isNull);
    });
  });

  group('continue-watching shelf geometry', () {
    testWidgets('artwork lands on the 16pt margin and 12pt card gap', (
      tester,
    ) async {
      await pumpAppAt(tester, const Size(400, 800));

      // The ink ring around each card is drawn outside the artwork, so the
      // shelf has to compensate. Measure the artwork itself, not the card.
      final art = find.byType(GradientArt);
      expect(art, findsWidgets);

      final first = tester.getRect(art.first);
      expect(first.left, 16, reason: 'artwork must start at the screen margin');
      expect(first.width, 200);
      expect(first.height, 112);

      final second = tester.getRect(art.at(1));
      expect(
        second.left - first.right,
        12,
        reason: 'design fixes the card gap at 12',
      );
    });

    testWidgets('press highlight is inset from the artwork and caption', (
      tester,
    ) async {
      await pumpAppAt(tester, const Size(400, 800));

      final inkWell = find
          .ancestor(
            of: find.byType(GradientArt).first,
            matching: find.byType(InkWell),
          )
          .first;

      final inkRect = tester.getRect(inkWell);
      final artRect = tester.getRect(find.byType(GradientArt).first);

      expect(
        artRect.left - inkRect.left,
        greaterThan(0),
        reason: 'ink must not sit flush against the content',
      );
      expect(artRect.top - inkRect.top, artRect.left - inkRect.left);
    });

    testWidgets('shelf grows with the text scale instead of overflowing', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(400, 800);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const ProviderScope(
          child: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: MPlayerApp(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // A RenderFlex overflow would have been recorded as an exception here.
      expect(tester.takeException(), isNull);
      expect(find.byType(GradientArt), findsWidgets);
    });
  });

  group('search scoping', () {
    testWidgets('offline sources are listed, unchecked and not selectable', (
      tester,
    ) async {
      await pumpAppAt(tester, const Size(400, 900));

      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();

      expect(find.text('Where to look'), findsOneWidget);

      // Nextcloud is offline in the sample data: shown, but skipped.
      final offlineTile = find.ancestor(
        of: find.text('Offline — will be skipped'),
        matching: find.byType(Checkbox),
      );
      expect(offlineTile, findsNothing);

      final checkboxes = tester
          .widgetList<Checkbox>(find.byType(Checkbox))
          .toList();
      expect(checkboxes.length, 4);
      expect(
        checkboxes.where((c) => c.onChanged == null).length,
        1,
        reason: 'the single offline source must be inert',
      );
      expect(checkboxes.where((c) => c.value == true).length, 3);
    });
  });
}
