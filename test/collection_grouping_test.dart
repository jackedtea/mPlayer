// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_library_source.dart';

import 'package:mplayer/app/app.dart';
import 'package:mplayer/app/router.dart';
import 'package:mplayer/features/servers/server_library.dart';
import 'package:mplayer/servers/jellyfin_source.dart';
import 'package:mplayer/servers/media_library_source.dart';

/// A library holding two films in one box set, and whether they are asked for
/// grouped decides which comes back.
class _Server extends FakeLibrarySource {
  _Server({this.kind = 'movies', this.saved = false, this.refuses = false});

  final String kind;
  final bool refuses;
  bool saved;

  @override
  Future<List<LibraryView>> views() async => <LibraryView>[
    LibraryView(id: 'v1', name: 'Films', kind: kind),
  ];

  @override
  Future<bool> groupsCollections(String viewId) async => saved;

  @override
  Future<void> setGroupsCollections(String viewId, bool group) async {
    if (refuses) throw const ServerException('Refused.');
    saved = group;
  }

  @override
  Future<int> itemCount(String viewId, {bool groupCollections = false}) async =>
      groupCollections ? 5 : 12;

  @override
  Future<List<ServerItem>> items(
    String viewId, {
    int startIndex = 0,
    int limit = 100,
    ServerSort sort = ServerSort.name,
    SortOrder? order,
    LibraryFilter filter = LibraryFilter.none,
    bool groupCollections = false,
  }) async => viewId == 'set1'
      ? const <ServerItem>[
          ServerItem(id: 'm1', title: 'Part One', kind: ServerItemKind.movie),
          ServerItem(id: 'm2', title: 'Part Two', kind: ServerItemKind.movie),
        ]
      : groupCollections
      ? const <ServerItem>[
          ServerItem(
            id: 'set1',
            title: 'The Saga',
            kind: ServerItemKind.collection,
          ),
        ]
      : const <ServerItem>[
          ServerItem(id: 'm1', title: 'Part One', kind: ServerItemKind.movie),
          ServerItem(id: 'm2', title: 'Part Two', kind: ServerItemKind.movie),
        ];
}

Future<void> _pump(WidgetTester tester, MediaLibrarySource server) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(600, 1000);
  addTearDown(tester.view.reset);

  final router = buildRouter();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [activeServerProvider.overrideWithValue(server)],
      child: MPlayerApp(router: router),
    ),
  );
  await tester.pumpAndSettle();
  router.push('/library', extra: 'v1');
  await tester.pumpAndSettle();
}

Future<void> _openViewOptions(WidgetTester tester) async {
  await tester.tap(find.byTooltip('View options'));
  await tester.pumpAndSettle();
}

void main() {
  group('the switch', () {
    testWidgets('turns the grid into collections and saves on the server', (
      tester,
    ) async {
      final server = _Server();
      await _pump(tester, server);
      expect(find.text('Part One'), findsOneWidget);
      expect(find.text('The Saga'), findsNothing);
      expect(find.text('12 items'), findsOneWidget);

      await _openViewOptions(tester);
      await tester.tap(find.text('Group by collection'));
      await tester.pumpAndSettle();
      expect(server.saved, isTrue);

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.text('The Saga'), findsOneWidget);
      expect(find.text('Part One'), findsNothing);
      expect(find.text('5 items'), findsOneWidget);
    });

    testWidgets('a library saved as grouped opens grouped', (tester) async {
      await _pump(tester, _Server(saved: true));
      expect(find.text('The Saga'), findsOneWidget);
      expect(find.text('Part One'), findsNothing);
    });

    testWidgets('goes back and says why when the server refuses', (
      tester,
    ) async {
      final server = _Server(refuses: true);
      await _pump(tester, server);

      await _openViewOptions(tester);
      await tester.tap(find.text('Group by collection'));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<SwitchListTile>(
              find.widgetWithText(SwitchListTile, 'Group by collection'),
            )
            .value,
        isFalse,
      );
      expect(find.text('Refused.'), findsOneWidget);
      expect(server.saved, isFalse);
    });

    testWidgets('is not offered in a music library', (tester) async {
      await _pump(tester, _Server(kind: 'music'));
      await _openViewOptions(tester);
      expect(find.text('Group by collection'), findsNothing);
    });

    testWidgets('opening a box set lists its films, not the set again', (
      tester,
    ) async {
      await _pump(tester, _Server(saved: true));
      await tester.tap(find.text('The Saga'));
      await tester.pumpAndSettle();

      expect(find.text('Part One'), findsOneWidget);
      expect(find.text('Part Two'), findsOneWidget);
    });
  });

  group('the requests', () {
    late List<RequestOptions> sent;
    late Map<String, dynamic> stored;

    JellyfinSource source() {
      final dio = Dio(BaseOptions(validateStatus: (_) => true));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            sent.add(options);
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 200,
                data: options.method == 'POST'
                    ? null
                    : options.path.contains('DisplayPreferences')
                    ? stored
                    : <String, dynamic>{
                        'Items': <dynamic>[],
                        'TotalRecordCount': 0,
                      },
              ),
            );
          },
        ),
      );
      return JellyfinSource(
        profile: fakeServerProfile,
        token: 't',
        identity: const ClientIdentity(deviceId: 'd', deviceName: 'n'),
        client: dio,
      );
    }

    setUp(() {
      sent = <RequestOptions>[];
      stored = <String, dynamic>{
        'SortBy': 'SortName',
        'CustomPrefs': <String, dynamic>{'homesection0': 'resume'},
      };
    });

    test('the listing and its count both say which they want', () async {
      final s = source();
      await s.items('v1', groupCollections: true);
      await s.itemCount('v1', groupCollections: true);
      await s.items('v1');

      expect(sent[0].uri.queryParameters['collapseBoxSetItems'], 'true');
      expect(sent[1].uri.queryParameters['collapseBoxSetItems'], 'true');
      // Off is said too, or an admin's server-wide default would answer.
      expect(sent[2].uri.queryParameters['collapseBoxSetItems'], 'false');
    });

    test('saving keeps every other preference the server holds', () async {
      await source().setGroupsCollections('v1', true);

      final post = sent.last;
      expect(post.method, 'POST');
      expect(post.uri.path, '/DisplayPreferences/v1');
      expect(post.uri.queryParameters['client'], 'mPlayer');
      expect(post.uri.queryParameters['userId'], 'u1');

      final body = jsonDecode(jsonEncode(post.data)) as Map<String, dynamic>;
      expect(body['SortBy'], 'SortName');
      expect(body['CustomPrefs'], <String, dynamic>{
        'homesection0': 'resume',
        'mplayerGroupCollections': 'true',
      });
    });

    test('reads back what was saved, and off when nothing was', () async {
      expect(await source().groupsCollections('v1'), isFalse);

      (stored['CustomPrefs'] as Map<String, dynamic>)['mplayerGroupCollections'] =
          'true';
      expect(await source().groupsCollections('v1'), isTrue);
    });
  });
}
