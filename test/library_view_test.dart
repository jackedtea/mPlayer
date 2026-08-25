// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mplayer/features/player/player_ui_state.dart';
import 'package:mplayer/features/servers/library_view_settings.dart';
import 'package:mplayer/servers/jellyfin_dto.dart';
import 'package:mplayer/servers/media_library_source.dart';

void main() {
  group('collections', () {
    test('a box set is a collection, and a collection is browsed', () {
      // Filed as a plain folder it went to the movie screen, which drew a
      // Play button over something that has no stream behind it.
      final item = serverItemFromJson(<String, dynamic>{
        'Id': 'c1',
        'Name': 'Toy Story Collection',
        'Type': 'BoxSet',
        'ChildCount': 4,
      });

      expect(item.kind, ServerItemKind.collection);
      expect(item.kind.isBrowsable, isTrue);
      expect(ServerItemKind.movie.isBrowsable, isFalse);
      expect(ServerItemKind.series.isBrowsable, isFalse);
    });
  });

  group('detail metadata', () {
    test('the fields the detail screens grew are parsed', () {
      final item = serverItemFromJson(<String, dynamic>{
        'Id': 's1',
        'Name': 'A Series',
        'Type': 'Series',
        'Tags': <Object?>['miniseries', 42, 'secret'],
        'Studios': <Object?>[
          <String, dynamic>{'Name': 'Netflix', 'Id': 'n1'},
          <String, dynamic>{'Id': 'no-name'},
        ],
        'Status': 'Ended',
        'EndDate': '2026-01-05T17:03:00.0000000Z',
      });

      // A non-string in the list is dropped rather than stringified.
      expect(item.tags, <String>['miniseries', 'secret']);
      expect(item.studios, <String>['Netflix']);
      expect(item.status, 'Ended');
      expect(item.endYear, 2026);
    });

    test('a series still running has no end year', () {
      final item = serverItemFromJson(<String, dynamic>{
        'Id': 's2',
        'Name': 'B',
        'Type': 'Series',
        'Status': 'Continuing',
      });

      expect(item.endYear, isNull);
      expect(item.tags, isEmpty);
    });

    test("a person's headshot is asked for under their own id", () {
      // Not the item's: a credit's PrimaryImageTag belongs to the person, and
      // asking the film for it returns nothing.
      final item = serverItemFromJson(<String, dynamic>{
        'Id': 'm1',
        'Name': 'A Film',
        'Type': 'Movie',
        'People': <Object?>[
          <String, dynamic>{
            'Id': 'p1',
            'Name': 'Kim Ji-soo',
            'Role': 'Seo Mi-rae',
            'Type': 'Actor',
            'PrimaryImageTag': 'tag1',
          },
          <String, dynamic>{'Id': 'p2', 'Name': 'Nobody', 'Type': 'Writer'},
        ],
      });

      final url = personImageUrlFor(
        item.people.first,
        base: Uri.parse('https://media.home.lan'),
        maxWidth: 160,
      );

      expect(url?.path, '/Items/p1/Images/Primary');
      expect(url?.queryParameters['tag'], 'tag1');

      // No tag, no URL — the strip falls back to the initial rather than
      // requesting an image the server does not have.
      expect(
        personImageUrlFor(
          item.people.last,
          base: Uri.parse('https://media.home.lan'),
        ),
        isNull,
      );
    });
  });

  group('grid density', () {
    test('the setting is what a phone shows', () {
      expect(columnsForWidth(3, 390), 3);
      expect(columnsForWidth(5, 390), 5);
    });

    test('a wider window earns columns rather than wider posters', () {
      // The setting says how big a poster should be; obeying it literally on
      // a desktop window would draw posters the width of a hand.
      expect(columnsForWidth(3, 1280), greaterThan(columnsForWidth(3, 700)));
      expect(columnsForWidth(3, 700), greaterThan(columnsForWidth(3, 390)));
    });

    test('the stored value is clamped, not trusted', () {
      expect(LibraryColumnsController.minColumns, lessThan(
          LibraryColumnsController.maxColumns));
      expect(LibraryColumnsController.defaultColumns, 3);
    });
  });

  group('releasing the rotation lock', () {
    late List<List<String>> calls;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      calls = <List<String>>[];

      TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'SystemChrome.setPreferredOrientations') {
          calls.add(List<String>.from(call.arguments as List<Object?>));
        }
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    testWidgets('the sensor gets a turn before the lock is dropped',
        (tester) async {
      // Releasing straight to the empty list is what left the app sideways:
      // an empty list means "system decides", and a system with auto-rotate
      // switched off decides to keep whatever is already on screen. A moment
      // of full-sensor is what actually moves the window back.
      final done = releaseOrientation();
      await tester.pump(const Duration(seconds: 1));
      await done;

      expect(calls.length, 2);
      expect(calls.first.length, 4, reason: 'every orientation, ie the sensor');
      expect(calls.last, isEmpty, reason: 'the lock goes back to the user');
    });
  });
}
