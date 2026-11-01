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
import 'package:mplayer/features/player/stable_insets.dart';
import 'package:mplayer/features/player/track_sheet.dart';
import 'package:mplayer/l10n/app_localizations.dart';

/// A phone on its side: status bar along the top, navigation bar down the
/// right — or neither, in sticky immersion.
Future<Rect> _openWith(WidgetTester tester, {required bool bars}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(872, 393);
  final padding = bars
      ? const FakeViewPadding(top: 28, right: 48)
      : FakeViewPadding.zero;
  tester.view.padding = padding;
  tester.view.viewPadding = padding;

  await tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(Brightness.dark),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => TrackSheet.show(
              context: context,
              title: 'Playback quality',
              selectedId: 'a',
              options: const <TrackOption>[
                TrackOption(id: 'a', label: 'Original'),
                TrackOption(id: 'b', label: '1080p · 20 Mbps'),
                TrackOption(id: 'c', label: '720p · 4 Mbps'),
              ],
              onSelected: (_) {},
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();

  final title = tester.getRect(find.text('Playback quality'));
  await tester.tapAt(const Offset(436, 5));
  await tester.pumpAndSettle();
  return title;
}

void main() {
  setUp(debugResetKnownSystemInsets);

  testWidgets('a player sheet sits in the same place with the bars up or down',
      (tester) async {
    addTearDown(tester.view.reset);

    // The bars once, as the player sees them when it opens.
    final shown = await _openWith(tester, bars: true);
    // Then sticky immersion hides them, and the same sheet is opened again.
    final hidden = await _openWith(tester, bars: false);

    expect(hidden, shown);
  });

  testWidgets('and never reaches up under the status bar', (tester) async {
    addTearDown(tester.view.reset);

    final shown = await _openWith(tester, bars: true);
    expect(shown.top, greaterThan(28));
  });

  testWidgets('a centred sheet is not padded for a bar it does not reach',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(872, 393);
    // A navigation bar down the right and a cut-out down the left: the
    // 640-wide sheet sits 116 in from either edge, clear of both.
    const padding = FakeViewPadding(top: 28, left: 32, right: 48);
    tester.view.padding = padding;
    tester.view.viewPadding = padding;
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
                child: const Text('more'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('more'));
    await tester.pumpAndSettle();

    // The route spans the screen; the 640-wide surface is centred in it.
    final surface = (tester.getSize(find.byType(BottomSheet)).width - 640) / 2;
    final icon = tester.getRect(
      find
          .descendant(
            of: find.widgetWithText(ListTile, 'Sleep timer'),
            matching: find.byType(Icon),
          )
          .first,
    );
    // The rows' own margin, and nothing for the bars on top of it.
    expect(icon.left - surface, 24);
  });

  testWidgets('More keeps the same side margin as the track sheets',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(872, 393);
    addTearDown(tester.view.reset);

    // The edge of the sheet, and how far in from it a row's first thing is.
    double inset(Finder sheet, Finder first) =>
        tester.getTopLeft(first).dx - tester.getTopLeft(sheet).dx;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildTheme(Brightness.dark),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => Column(
                children: <Widget>[
                  TextButton(
                    onPressed: () => MoreMenu.show(context),
                    child: const Text('more'),
                  ),
                  TextButton(
                    onPressed: () => TrackSheet.show(
                      context: context,
                      title: 'Playback quality',
                      selectedId: null,
                      options: const <TrackOption>[
                        TrackOption(id: 'a', label: 'Original'),
                      ],
                      onSelected: (_) {},
                    ),
                    child: const Text('quality'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('quality'));
    await tester.pumpAndSettle();
    final quality = inset(find.byType(BottomSheet), find.text('Original'));
    await tester.tapAt(const Offset(436, 5));
    await tester.pumpAndSettle();

    await tester.tap(find.text('more'));
    await tester.pumpAndSettle();
    final more = inset(
      find.byType(BottomSheet),
      find
          .descendant(
            of: find.widgetWithText(ListTile, 'Sleep timer'),
            matching: find.byType(Icon),
          )
          .first,
    );

    expect(more, quality);
  });
}
