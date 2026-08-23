// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mplayer/app/theme.dart';
import 'package:mplayer/features/player/playback_state.dart';
import 'package:mplayer/features/player/track_sheet.dart';

const _tracks = <MediaTrack>[
  MediaTrack(id: 'no', kind: TrackKind.subtitle, label: 'Off'),
  MediaTrack(id: '1', kind: TrackKind.subtitle, label: 'English'),
  MediaTrack(id: '2', kind: TrackKind.subtitle, label: 'Tiếng Việt'),
];

Future<void> pumpSheet(
  WidgetTester tester, {
  String? selectedId,
  ValueChanged<TrackOption>? onSelected,
  TrackSheetAction? action,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(Brightness.dark),
      home: Scaffold(
        body: TrackSheet(
          title: 'Subtitles',
          options: <TrackOption>[
            for (final MediaTrack t in _tracks) TrackOption.fromTrack(t),
          ],
          selectedId: selectedId,
          onSelected: onSelected ?? (_) {},
          action: action,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('without an action the sheet is just the list', (tester) async {
    await pumpSheet(tester);

    expect(find.text('Subtitles'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('Open subtitle file…'), findsNothing);
  });

  testWidgets('the action row runs its callback', (tester) async {
    var opened = 0;
    await pumpSheet(
      tester,
      action: TrackSheetAction(
        label: 'Open subtitle file…',
        icon: Icons.subtitles_outlined,
        onTap: () => opened++,
      ),
    );

    await tester.tap(find.text('Open subtitle file…'));
    await tester.pumpAndSettle();

    expect(opened, 1);
  });

  testWidgets('the action does not report a track selection', (tester) async {
    // The row sits outside the list on purpose: picking a file is not
    // picking a stream, and reporting one would switch the subtitle off.
    TrackOption? selected;
    await pumpSheet(
      tester,
      onSelected: (o) => selected = o,
      action: TrackSheetAction(
        label: 'Open subtitle file…',
        icon: Icons.subtitles_outlined,
        onTap: () {},
      ),
    );

    await tester.tap(find.text('Open subtitle file…'));
    await tester.pumpAndSettle();

    expect(selected, isNull);
  });

  testWidgets('the active track is the one ticked', (tester) async {
    await pumpSheet(tester, selectedId: '2');

    final ticked = tester.widgetList<Icon>(find.byIcon(Icons.check_rounded));
    expect(ticked.length, 1);
  });
}
