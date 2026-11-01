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
  VoidCallback? onSpeed,
  VoidCallback? onScreenshot,
  VoidCallback? onBackgroundPlay,
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
              onPressed: () => MoreMenu.show(
                context,
                onSpeed: onSpeed ?? () {},
                onScreenshot: onScreenshot ?? () {},
                onBackgroundPlay: onBackgroundPlay ?? () {},
              ),
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

      // Lock moved to the control bar's bottom-left group in the redesign and
      // came off this sheet when the decoder went on it: seven rows is all a
      // phone on its side has room for.
      expect(find.text('Lock player'), findsNothing);

      // Rotation and aspect are buttons on the bar, and came off the sheet
      // to make room for the quick actions.
      expect(find.text('Rotation'), findsNothing);
      expect(find.text('Aspect ratio'), findsNothing);

      for (final String label in <String>[
        'Background',
        'Loop',
        'Sleep timer',
        'Audio delay',
        'Decoder',
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
        tester.getRect(find.text('Auto (safe)')).right,
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
      expect(find.text('Sleep timer'), findsOneWidget);

      await tester.drag(find.text('Sleep timer'), const Offset(0, -200));
      await tester.pumpAndSettle();

      expect(find.text('Player settings'), findsOneWidget);
      expect(
        tester.getRect(find.text('Player settings')).bottom,
        lessThanOrEqualTo(300 - 48),
      );
    });
  });

  group('the decoder picker', () {
    testWidgets('offers hardware and software, each with what it costs',
        (tester) async {
      await openMoreMenu(tester);

      // The row reports the setting; the sheet is where it is changed.
      expect(find.text('Decoder'), findsOneWidget);
      expect(find.text('Auto (safe)'), findsOneWidget);

      await tester.tap(find.text('Decoder'));
      await tester.pumpAndSettle();

      expect(find.text('Prefer hardware'), findsOneWidget);
      expect(find.text('Software only'), findsOneWidget);
      // The names alone do not say which to reach for, which is the whole
      // question a viewer opens this sheet with.
      expect(
        find.text(
          'The CPU decodes everything. Heavier on the battery, but it plays '
          'what hardware gets wrong',
        ),
        findsOneWidget,
      );
      // The mode already in force is ticked rather than merely listed.
      expect(
        find.descendant(
          of: find.widgetWithText(ListTile, 'Auto (safe)'),
          matching: find.byIcon(Icons.check_rounded),
        ),
        findsOneWidget,
      );
    });

    testWidgets('says nothing about what is decoding when nothing is playing',
        (tester) async {
      // The reading is mpv's, and there is no mpv here — a line reporting
      // "software" for a player that has not opened a file would be a claim
      // about a decoder that does not exist.
      await openMoreMenu(tester);
      await tester.tap(find.text('Decoder'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Decoding now'), findsNothing);
    });
  });

  group('the quick actions', () {
    testWidgets('sit above the rows, one tile each', (tester) async {
      await openMoreMenu(tester);

      expect(tester.takeException(), isNull);
      for (final String label in <String>[
        'Background',
        'Speed',
        'Loop',
        'Screenshot',
      ]) {
        expect(
          tester.getRect(find.text(label)).bottom,
          lessThan(tester.getRect(find.text('Sleep timer')).top),
          reason: label,
        );
      }
      // Normal speed and no loop say so rather than leaving a blank.
      expect(find.text('1.00×'), findsOneWidget);
    });

    testWidgets('loop cycles in place and says what it is on',
        (tester) async {
      await openMoreMenu(tester);

      await tester.tap(find.text('Loop'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.repeat_one_rounded), findsOneWidget);
      expect(find.text('Repeat this video'), findsOneWidget);
      // Still open: the next tap is often the same tile again.
      expect(find.text('Sleep timer'), findsOneWidget);
    });

    testWidgets('speed and screenshot close the sheet before acting',
        (tester) async {
      var speed = 0;
      var grabbed = 0;
      await openMoreMenu(
        tester,
        onSpeed: () => speed++,
        onScreenshot: () => grabbed++,
      );

      await tester.tap(find.text('Speed'));
      await tester.pumpAndSettle();
      expect(speed, 1);
      expect(find.text('Sleep timer'), findsNothing);

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Screenshot'));
      await tester.pumpAndSettle();
      expect(grabbed, 1);
      expect(find.text('Sleep timer'), findsNothing);
    });

    testWidgets('background play toggles without closing', (tester) async {
      var toggled = 0;
      await openMoreMenu(tester, onBackgroundPlay: () => toggled++);

      await tester.tap(find.text('Background'));
      await tester.pumpAndSettle();

      expect(toggled, 1);
      expect(find.text('Sleep timer'), findsOneWidget);
    });
  });
}
