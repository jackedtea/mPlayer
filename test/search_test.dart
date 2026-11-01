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
import 'package:mplayer/features/search/search_history.dart';
import 'package:mplayer/features/servers/server_library.dart';
import 'package:mplayer/servers/media_library_source.dart';

/// Answers each kind with its own titles, or with nothing when asked to.
class _Server extends FakeLibrarySource {
  _Server({this.withEpisodes = true});

  final bool withEpisodes;
  final List<Set<ServerItemKind>> asked = <Set<ServerItemKind>>[];

  @override
  Future<List<ServerItem>> search(
    String query, {
    int limit = 40,
    Set<ServerItemKind> kinds = const <ServerItemKind>{
      ServerItemKind.movie,
      ServerItemKind.series,
      ServerItemKind.episode,
    },
  }) async {
    asked.add(kinds);
    final kind = kinds.single;
    if (kind == ServerItemKind.episode && !withEpisodes) {
      return const <ServerItem>[];
    }
    return <ServerItem>[
      ServerItem(
        id: '${kind.name}1',
        title: 'A ${kind.name} about $query',
        kind: kind,
        seriesTitle: kind == ServerItemKind.episode ? 'Some show' : null,
        seasonNumber: kind == ServerItemKind.episode ? 1 : null,
        episodeNumber: kind == ServerItemKind.episode ? 2 : null,
      ),
    ];
  }

  @override
  Future<List<ServerPerson>> searchPeople(
    String query, {
    int limit = 24,
  }) async =>
      const <ServerPerson>[ServerPerson(name: 'Jane Actor', role: '', id: 'p9')];
}

Future<GoRouter> _openSearch(WidgetTester tester, _Server server) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(400, 1200);
  addTearDown(tester.view.reset);

  final router = buildRouter();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [activeServerProvider.overrideWithValue(server)],
      child: MPlayerApp(router: router),
    ),
  );
  await tester.pumpAndSettle();
  router.go('/search');
  await tester.pumpAndSettle();
  return router;
}

Future<void> _search(WidgetTester tester, String query) async {
  await tester.enterText(find.byType(SearchBar), query);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  group('results', () {
    testWidgets('a section per kind, in the order the web client uses',
        (tester) async {
      final server = _Server();
      await _openSearch(tester, server);
      await _search(tester, 'night');

      final headings = <String>['Movies', 'Shows', 'Episodes', 'People'];
      for (final String h in headings) {
        expect(find.text(h), findsOneWidget, reason: h);
      }
      for (var i = 1; i < headings.length; i++) {
        expect(
          tester.getTopLeft(find.text(headings[i - 1])).dy,
          lessThan(tester.getTopLeft(find.text(headings[i])).dy),
        );
      }
      expect(find.text('Jane Actor'), findsOneWidget);

      // One request per kind, so no kind can crowd out another.
      expect(
        server.asked.map((k) => k.single).toSet(),
        <ServerItemKind>{
          ServerItemKind.movie,
          ServerItemKind.series,
          ServerItemKind.episode,
        },
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a kind with nothing in it is not drawn', (tester) async {
      await _openSearch(tester, _Server(withEpisodes: false));
      await _search(tester, 'night');

      expect(find.text('Movies'), findsOneWidget);
      expect(find.text('Episodes'), findsNothing);
    });
  });

  group('history', () {
    testWidgets('the last searches show newest first, one of each',
        (tester) async {
      await _openSearch(tester, _Server());
      await _search(tester, 'dune');
      await _search(tester, 'arrival');
      await _search(tester, 'Dune');

      await tester.tap(find.byTooltip('Clear'));
      await tester.pumpAndSettle();

      expect(find.text('Recent searches'), findsOneWidget);
      // Running "Dune" again moved it up rather than listing it twice.
      expect(find.text('Dune'), findsOneWidget);
      expect(find.text('dune'), findsNothing);
      expect(
        tester.getTopLeft(find.text('Dune')).dy,
        lessThan(tester.getTopLeft(find.text('arrival')).dy),
      );
    });

    testWidgets('one entry can be removed, or all of them', (tester) async {
      await _openSearch(tester, _Server());
      await _search(tester, 'dune');
      await _search(tester, 'arrival');
      await tester.tap(find.byTooltip('Clear'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.widgetWithText(ListTile, 'dune'),
          matching: find.byTooltip('Remove from history'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('dune'), findsNothing);
      expect(find.text('arrival'), findsOneWidget);

      await tester.tap(find.text('Clear all'));
      await tester.pumpAndSettle();
      expect(find.text('arrival'), findsNothing);
      expect(find.text('Recent searches'), findsNothing);
    });

    test('keeps ten, and survives a restart', () async {
      final first = ProviderContainer();
      addTearDown(first.dispose);
      final history = first.read(searchHistoryProvider.notifier);
      await first.read(searchHistoryProvider.future);
      for (var i = 1; i <= 12; i++) {
        await history.add('query $i');
      }

      final restarted = ProviderContainer();
      addTearDown(restarted.dispose);
      final kept = await restarted.read(searchHistoryProvider.future);

      expect(kept, hasLength(SearchHistoryController.limit));
      expect(kept.first, 'query 12');
      expect(kept.last, 'query 3');
    });
  });
}
