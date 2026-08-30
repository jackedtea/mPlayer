// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mplayer/app/theme.dart';
import 'package:mplayer/features/player/more_menu.dart';
import 'package:mplayer/l10n/app_localizations.dart';

/// Opens the sheet on a screen of [size], with [navigationBar] logical pixels
/// of system bar along the bottom.
///
/// Landscape and short, because that is how a video player is held.
Future<void> openMoreMenu(
  WidgetTester tester, {
  Size size = const Size(1280, 582),
  double navigationBar = 48,
  double statusBar = 0,
  double sideBar = 0,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  tester.view.padding = FakeViewPadding(
    bottom: navigationBar,
    top: statusBar,
    right: sideBar,
  );
  tester.view.viewPadding = FakeViewPadding(
    bottom: navigationBar,
    top: statusBar,
    right: sideBar,
  );
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: buildTheme(Brightness.dark),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => MoreMenu.show(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  group('the more sheet on a short screen', () {
    testWidgets('every row fits above the navigation bar', (tester) async {
      // The default sheet is capped at nine sixteenths of the screen, which
      // in landscape is shorter than the rows — and the ones past the cap
      // were cut off rather than scrolled to. "Sleep timer" was the row the
      // navigation bar sat across.
      await openMoreMenu(tester);

      expect(tester.takeException(), isNull);

      for (final String label in <String>[
        'Rotation',
        'Lock player',
        'Aspect ratio',
        'Sleep timer',
        'Audio delay',
        'Stats for nerds',
        'Player settings',
      ]) {
        final row = find.text(label);
        expect(row, findsOneWidget, reason: label);
        expect(
          tester.getRect(row).bottom,
          lessThanOrEqualTo(582 - 48),
          reason: '$label is under the navigation bar',
        );
      }
    });

    testWidgets('the status bar does not cost the sheet a row', (tester) async {
      // A phone on its side, bars up: 393 points of height, a status bar
      // across the top and the navigation bar down the side. The sheet has
      // no reason to avoid the status bar — it is anchored to the opposite
      // edge — and giving that strip up is what pushed the last row out.
      await openMoreMenu(
        tester,
        size: const Size(872, 393),
        navigationBar: 0,
        statusBar: 28,
      );

      expect(tester.takeException(), isNull);
      expect(
        tester.getRect(find.text('Player settings')).bottom,
        lessThanOrEqualTo(393),
      );
    });

    testWidgets('a navigation bar down the side is kept clear of',
        (tester) async {
      // Landscape on Android puts the buttons down an edge rather than along
      // the bottom, so the row's own trailing value is what would end up
      // underneath them.
      await openMoreMenu(
        tester,
        size: const Size(872, 393),
        navigationBar: 0,
        statusBar: 28,
        sideBar: 48,
      );

      expect(
        tester.getRect(find.text('Auto')).right,
        lessThanOrEqualTo(872 - 48),
      );
      expect(
        tester.getRect(find.text('Player settings')).bottom,
        lessThanOrEqualTo(393),
      );
    });

    testWidgets('a screen too short for the rows scrolls them', (tester) async {
      // Nothing is unreachable on a small window: what does not fit is
      // scrolled to rather than clipped.
      await openMoreMenu(tester, size: const Size(1280, 300));

      expect(tester.takeException(), isNull);
      expect(find.text('Rotation'), findsOneWidget);

      await tester.drag(find.text('Rotation'), const Offset(0, -200));
      await tester.pumpAndSettle();

      expect(find.text('Player settings'), findsOneWidget);
      expect(
        tester.getRect(find.text('Player settings')).bottom,
        lessThanOrEqualTo(300 - 48),
      );
    });
  });
}
