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

const _statusBar = 32.0;

/// One season of twenty episodes, the second of them half watched.
class _Series extends FakeLibrarySource {
  const _Series();

  static const series = ServerItem(
    id: 's1',
    title: 'The Long Series',
    kind: ServerItemKind.series,
    year: 2024,
  );

  @override
  Future<ServerItem> item(String itemId) async => series;

  @override
  Future<List<ServerItem>> episodes(String seriesId, {String? seasonId}) async {
    return <ServerItem>[
      for (var i = 1; i <= 20; i++)
        ServerItem(
          id: 'e$i',
          title: 'Episode title $i',
          kind: ServerItemKind.episode,
          seriesId: 's1',
          seriesTitle: series.title,
          seasonNumber: 1,
          episodeNumber: i,
          runtime: const Duration(minutes: 50),
          played: i == 1,
          position: i == 2 ? const Duration(minutes: 20) : null,
        ),
    ];
  }
}

/// The same series over a slow connection: the series lands first and the
/// episodes a second later, as they do from a real server.
class _SlowEpisodes extends _Series {
  const _SlowEpisodes();

  @override
  Future<List<ServerItem>> episodes(String seriesId, {String? seasonId}) async {
    await Future<void>.delayed(const Duration(seconds: 1));
    return super.episodes(seriesId, seasonId: seasonId);
  }
}

Future<void> _open(
  WidgetTester tester, {
  MediaLibrarySource source = const _Series(),
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(400, 900);
  tester.view.padding = const FakeViewPadding(top: _statusBar);
  tester.view.viewPadding = const FakeViewPadding(top: _statusBar);
  addTearDown(tester.view.reset);

  final router = buildRouter();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [activeServerProvider.overrideWithValue(source)],
      child: MPlayerApp(router: router),
    ),
  );
  await tester.pumpAndSettle();
  router.push('/library/series', extra: 's1');
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('scrolled down, the title stays in a toolbar under the '
      'status bar, with the season tabs below it', (tester) async {
    await _open(tester);

    // At the top there is no toolbar: the header carries the title.
    final toolbarTitle = find.descendant(
      of: find.byType(Row),
      matching: find.text('The Long Series'),
    );
    expect(find.byTooltip('Back'), findsOneWidget);

    await tester.drag(find.byType(NestedScrollView), const Offset(0, -1200));
    await tester.pumpAndSettle();

    expect(toolbarTitle, findsWidgets);
    final title = tester.getRect(toolbarTitle.last);
    expect(title.top, greaterThanOrEqualTo(_statusBar));
    expect(title.bottom, lessThanOrEqualTo(_statusBar + kToolbarHeight));

    // The tabs hold still under the toolbar, never under the clock.
    final tab = tester.getRect(find.widgetWithText(Tab, 'Season 1'));
    expect(tab.top, greaterThanOrEqualTo(_statusBar + kToolbarHeight - 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Play says which episode it will play', (tester) async {
    await _open(tester);

    final bar = find.byType(FilledButton).last;
    // The part-watched episode, not the first unwatched one after it...
    expect(
      find.descendant(of: bar, matching: find.textContaining('S1E2')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: bar,
        matching: find.textContaining('Episode title 2'),
      ),
      findsOneWidget,
    );
    // ...and, since it has a position, offers to carry on rather than play.
    expect(
      find.descendant(of: bar, matching: find.text('Continue watching')),
      findsOneWidget,
    );
  });

  testWidgets('episodes arriving after the series replace the tabs cleanly', (
    tester,
  ) async {
    // The tab controller is made for "About" alone, then again for the
    // seasons: a second ticker from the same state, which a single-ticker
    // mixin refuses with a red screen.
    await _open(tester, source: const _SlowEpisodes());
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.widgetWithText(Tab, 'Season 1'), findsOneWidget);
  });
}
