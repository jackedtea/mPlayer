// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_library_source.dart';

import 'package:mplayer/app/app.dart';
import 'package:mplayer/app/router.dart';
import 'package:mplayer/features/servers/server_library.dart';
import 'package:mplayer/servers/media_library_source.dart';

/// The screen from the report, with episodes in it.
///
/// The general inset test measures screens the test harness can render with
/// nothing signed in, and every one of those is empty — so the list that was
/// actually disappearing behind the navigation buttons was never among them.
/// This one stands a real episode list up and measures where its last row
/// ends.
const _statusBar = 48.0;
const _navigationBar = 56.0;


void main() {
  testWidgets('the last episode row clears the navigation bar', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(400, 900);
    tester.view.padding = const FakeViewPadding(
      top: _statusBar,
      bottom: _navigationBar,
    );
    tester.view.viewPadding = const FakeViewPadding(
      top: _statusBar,
      bottom: _navigationBar,
    );
    addTearDown(tester.view.reset);

    final router = buildRouter();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeServerProvider.overrideWithValue(_FakeSeriesServer()),
        ],
        child: MPlayerApp(router: router),
      ),
    );
    await tester.pumpAndSettle();

    router.push('/library/series', extra: 's1');
    await tester.pumpAndSettle();

    // Enough episodes that the list runs off the bottom of the window.
    expect(find.textContaining('1. Episode'), findsOneWidget);

    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    final safeBottom = size.height - _navigationBar;

    // The list's own viewport, which is what would run under the buttons.
    for (final Element element in find.byType(Scrollable).evaluate()) {
      final scrollable = element.widget as Scrollable;
      if (scrollable.axis != Axis.vertical) continue;

      final box = element.renderObject! as RenderBox;
      final bottom = box.localToGlobal(Offset.zero).dy + box.size.height;

      expect(
        bottom,
        lessThanOrEqualTo(safeBottom),
        reason: 'an episode list running to ${bottom.toStringAsFixed(0)} is '
            'behind the navigation bar, which starts at $safeBottom',
      );
    }

    // The top is deliberately *not* inset here: a detail screen claims
    // `WindowEdges.bottomOnly` so its backdrop runs to the top edge under the
    // status bar, which is what the design asks for. Only the bottom is the
    // bug — the list disappearing behind the navigation buttons.
    final backdrop = tester.getRect(find.byType(Scaffold).last);
    expect(backdrop.top, 0, reason: 'the backdrop should reach the top edge');
  });
}

/// A series with enough episodes to overflow the window.
class _FakeSeriesServer extends FakeLibrarySource {
  const _FakeSeriesServer();

  static const _series = ServerItem(
    id: 's1',
    title: 'Bottom-tier Character Tomozaki',
    kind: ServerItemKind.series,
    overview: 'Tomozaki is one of the best gamers in Japan.',
    genres: <String>['Drama', 'Comedy', 'Animation'],
  );

  @override
  Future<ServerItem> item(String itemId) async => _series;

  @override
  Future<List<ServerItem>> episodes(String seriesId, {String? seasonId}) async {
    return <ServerItem>[
      for (var i = 1; i <= 12; i++)
        ServerItem(
          id: 'e$i',
          title: 'Episode $i',
          kind: ServerItemKind.episode,
          seriesId: 's1',
          seriesTitle: _series.title,
          seasonNumber: 1,
          episodeNumber: i,
          overview: 'Something happens in episode $i, at some length.',
          runtime: const Duration(minutes: 23),
        ),
    ];
  }
}
