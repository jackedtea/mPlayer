// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mplayer/app/theme.dart';
import 'package:mplayer/l10n/app_localizations.dart';
import 'package:mplayer/core/models/media_models.dart';
import 'package:mplayer/widgets/continue_watching_card.dart';

/// A play button has to play.
///
/// The Continue watching and Next up shelves draw a play glyph in the middle
/// of the artwork, and on the server home the whole card opened the item's
/// detail screen — so the one control on the card that says "play" was the
/// one that did not. These shelves exist to carry on watching; the glyph is
/// the short way there.
void main() {
  const item = ResumeItem(
    id: 'a1',
    title: 'Tomozaki',
    sourceKind: SourceKind.jellyfin,
    sourceLabel: 'Home',
    remaining: '11m left',
    quality: '',
    progress: 0.4,
  );

  Future<void> pumpCard(
    WidgetTester tester, {
    required VoidCallback onTap,
    VoidCallback? onPlay,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        // The card reads spacing and colours from the theme extensions and
        // its labels from AppLocalizations; a bare MaterialApp supplies
        // neither and it throws on the first null.
        theme: buildTheme(Brightness.dark),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: ContinueWatchingCard(
              item: item,
              onTap: onTap,
              onPlay: onPlay,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('the glyph plays while the card opens the item', (tester) async {
    var opened = 0;
    var played = 0;

    await pumpCard(tester, onTap: () => opened++, onPlay: () => played++);

    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pump();

    expect(played, 1, reason: 'the play glyph must play');
    expect(opened, 0, reason: 'and must not fall through to the card');
  });

  testWidgets('the rest of the card still opens the item', (tester) async {
    var opened = 0;
    var played = 0;

    await pumpCard(tester, onTap: () => opened++, onPlay: () => played++);

    // The caption, well clear of the glyph.
    await tester.tap(find.text('Tomozaki'));
    await tester.pump();

    expect(opened, 1);
    expect(played, 0);
  });

  testWidgets('with no play callback the glyph does what the card does',
      (tester) async {
    // The Files shelf, where the card as a whole already resumes.
    var opened = 0;
    await pumpCard(tester, onTap: () => opened++);

    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pump();

    expect(opened, 1);
  });
}
