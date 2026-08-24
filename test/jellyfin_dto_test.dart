// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter_test/flutter_test.dart';

import 'package:mplayer/servers/jellyfin_dto.dart';
import 'package:mplayer/servers/media_library_source.dart';
import 'package:mplayer/servers/server_profile.dart';

final _base = Uri.parse('https://media.home.lan');

void main() {
  group('ticks', () {
    test('convert at ten thousand to the millisecond', () {
      // 1h 32m 15s, which is how Jellyfin states a runtime.
      expect(ticksToDuration(55350000000), const Duration(minutes: 92, seconds: 15));
      expect(durationToTicks(const Duration(seconds: 1)), 10000000);
    });

    test('zero and nonsense read as no value', () {
      // Zero ticks is "never started", not "at the beginning", and the two
      // drive different buttons.
      expect(ticksToDuration(0), isNull);
      expect(ticksToDuration(null), isNull);
      expect(ticksToDuration('lots'), isNull);
      expect(ticksToDuration(-5), isNull);
    });

    test('a double survives the trip', () {
      // Some servers hand these back as JSON numbers, not integers.
      expect(ticksToDuration(10000000.0), const Duration(seconds: 1));
    });
  });

  group('authorization header', () {
    test('has the shape Jellyfin parses', () {
      final header = authorizationHeader(
        client: 'mPlayer',
        device: 'Pixel 8',
        deviceId: 'abc-123',
        version: '1.0.0',
        token: 'tok',
      );

      expect(header, startsWith('MediaBrowser '));
      expect(header, contains('Client="mPlayer"'));
      expect(header, contains('Device="Pixel 8"'));
      expect(header, contains('DeviceId="abc-123"'));
      expect(header, contains('Token="tok"'));
    });

    test('omits the token before sign-in', () {
      // An empty Token field reads as a malformed request rather than an
      // anonymous one.
      final header = authorizationHeader(
        client: 'mPlayer',
        device: 'PC',
        deviceId: 'id',
        version: '1.0.0',
      );

      expect(header, isNot(contains('Token=')));
    });

    test('a quote in the device name cannot break the header', () {
      final header = authorizationHeader(
        client: 'mPlayer',
        device: 'Nam"s PC',
        deviceId: 'id',
        version: '1.0.0',
        token: 't',
      );

      expect(header, contains('Device="Nams PC"'));
    });
  });

  group('server URL', () {
    test('a bare host gets http, since a LAN server rarely has TLS', () {
      expect(normaliseServerUrl('192.168.1.10:8096'),
          'http://192.168.1.10:8096');
      expect(normaliseServerUrl('jellyfin.home.lan'), 'http://jellyfin.home.lan');
    });

    test('https is kept', () {
      expect(normaliseServerUrl('https://media.example.com'),
          'https://media.example.com');
    });

    test('a trailing slash is dropped', () {
      expect(normaliseServerUrl('https://media.example.com/'),
          'https://media.example.com');
    });

    test('a pasted web-client URL finds the API root', () {
      // What someone actually copies out of the browser address bar.
      expect(
        normaliseServerUrl('https://media.example.com/web/index.html#!/home.html'),
        'https://media.example.com',
      );
      expect(normaliseServerUrl('http://host:8096/web/'), 'http://host:8096');
    });

    test('a reverse-proxy prefix survives', () {
      // The prefix is part of the API root; only the web client's own path
      // is the UI.
      expect(
        normaliseServerUrl('https://home.example.com/jellyfin/web/index.html'),
        'https://home.example.com/jellyfin',
      );
      expect(normaliseServerUrl('https://home.example.com/jellyfin'),
          'https://home.example.com/jellyfin');
    });

    test('nothing usable returns null', () {
      expect(normaliseServerUrl(''), isNull);
      expect(normaliseServerUrl('   '), isNull);
      expect(normaliseServerUrl('ftp://host'), isNull);
    });
  });

  group('items', () {
    test('a movie carries its runtime, year and resume point', () {
      final item = serverItemFromJson(<String, dynamic>{
        'Id': 'a1',
        'Name': 'Dune',
        'Type': 'Movie',
        'ProductionYear': 2021,
        'RunTimeTicks': 55350000000,
        'ImageTags': <String, dynamic>{'Primary': 'tag1'},
        'UserData': <String, dynamic>{
          'PlaybackPositionTicks': 27675000000,
          'Played': false,
          'IsFavorite': true,
        },
      });

      expect(item.title, 'Dune');
      expect(item.kind, ServerItemKind.movie);
      expect(item.year, 2021);
      expect(item.runtime, const Duration(minutes: 92, seconds: 15));
      expect(item.position, const Duration(minutes: 46, seconds: 7, milliseconds: 500));
      expect(item.favourite, isTrue);
      expect(item.watchedFraction, closeTo(0.5, 0.01));
      expect(item.isStarted, isTrue);
    });

    test('an unwatched item has no position and no fraction', () {
      final item = serverItemFromJson(<String, dynamic>{
        'Id': 'a2',
        'Name': 'Arrival',
        'Type': 'Movie',
        'RunTimeTicks': 10000000,
        'UserData': <String, dynamic>{'PlaybackPositionTicks': 0},
      });

      expect(item.position, isNull);
      expect(item.watchedFraction, isNull);
      expect(item.isStarted, isFalse);
    });

    test('an episode keeps its series and numbering', () {
      final item = serverItemFromJson(<String, dynamic>{
        'Id': 'e1',
        'Name': 'The Bicameral Mind',
        'Type': 'Episode',
        'SeriesId': 's1',
        'SeriesName': 'Westworld',
        'ParentIndexNumber': 1,
        'IndexNumber': 10,
      });

      expect(item.kind, ServerItemKind.episode);
      expect(item.seriesTitle, 'Westworld');
      expect(item.seasonNumber, 1);
      expect(item.episodeNumber, 10);
    });

    test('an item with no name is identified by its id, not left blank', () {
      final item = serverItemFromJson(<String, dynamic>{'Id': 'x9', 'Name': '  '});

      expect(item.title, 'x9');
    });
  });

  group('artwork', () {
    test('an episode with its own image is asked for under its own id', () {
      final item = serverItemFromJson(<String, dynamic>{
        'Id': 'e1',
        'Type': 'Episode',
        'SeriesId': 's1',
        'ImageTags': <String, dynamic>{'Primary': 'own'},
        'SeriesPrimaryImageTag': 'series',
      });

      final url = imageUrlFor(item, base: _base, maxWidth: 300);
      expect(url.toString(), contains('/Items/e1/Images/Primary'));
      expect(url!.queryParameters['tag'], 'own');
      expect(url.queryParameters['maxWidth'], '300');
    });

    test('an episode borrowing its series image is asked under the series id',
        () {
      // The tag and its owner have to travel together: asking the episode
      // for the series' tag returns nothing at all.
      final item = serverItemFromJson(<String, dynamic>{
        'Id': 'e2',
        'Type': 'Episode',
        'SeriesId': 's1',
        'SeriesPrimaryImageTag': 'series',
      });

      final url = imageUrlFor(item, base: _base);
      expect(url.toString(), contains('/Items/s1/Images/Primary'));
      expect(url!.queryParameters['tag'], 'series');
    });

    test('no tag means no artwork, not a broken URL', () {
      final item = serverItemFromJson(<String, dynamic>{'Id': 'n1'});

      expect(imageUrlFor(item, base: _base), isNull);
    });

    test('a reverse-proxy prefix is kept in the image URL', () {
      final item = serverItemFromJson(<String, dynamic>{
        'Id': 'a1',
        'ImageTags': <String, dynamic>{'Primary': 't'},
      });

      final url = imageUrlFor(
        item,
        base: Uri.parse('https://home.example.com/jellyfin'),
      );
      expect(url.toString(), startsWith('https://home.example.com/jellyfin/Items/a1'));
    });
  });

  group('playback', () {
    test('a transcoding URL means the server chose to re-encode', () {
      // Even with the direct-play flags set: those say what is possible, not
      // what was decided.
      final playback = playbackFromJson(
        <String, dynamic>{
          'PlaySessionId': 'sess1',
          'MediaSources': <dynamic>[
            <String, dynamic>{
              'Id': 'ms1',
              'Container': 'mkv',
              'SupportsDirectPlay': true,
              'TranscodingUrl': '/videos/a1/master.m3u8?PlaySessionId=sess1',
            },
          ],
        },
        base: _base,
        itemId: 'a1',
        token: 'tok',
      );

      expect(playback!.isDirectPlay, isFalse);
      expect(playback.uri.toString(),
          'https://media.home.lan/videos/a1/master.m3u8?PlaySessionId=sess1');
      expect(playback.playSessionId, 'sess1');
    });

    test('no transcoding URL builds a static stream', () {
      final playback = playbackFromJson(
        <String, dynamic>{
          'PlaySessionId': 'sess2',
          'MediaSources': <dynamic>[
            <String, dynamic>{'Id': 'ms2', 'Container': 'mkv', 'Bitrate': 8000000},
          ],
        },
        base: _base,
        itemId: 'a1',
        token: 'tok',
      );

      expect(playback!.isDirectPlay, isTrue);
      expect(playback.uri.path, '/Videos/a1/stream');
      expect(playback.uri.queryParameters['static'], 'true');
      expect(playback.uri.queryParameters['mediaSourceId'], 'ms2');
      // libmpv fetches this itself and cannot be handed a header, so the
      // token has to be in the query.
      expect(playback.uri.queryParameters['api_key'], 'tok');
      expect(playback.bitrate, 8000000);
    });

    test('a response with no media source is not playable', () {
      expect(
        playbackFromJson(
          <String, dynamic>{'MediaSources': <dynamic>[]},
          base: _base,
          itemId: 'a1',
          token: 't',
        ),
        isNull,
      );
    });
  });

  group('views and sorting', () {
    test('a library keeps the collection type the server gave it', () {
      final view = libraryViewFromJson(<String, dynamic>{
        'Id': 'v1',
        'Name': 'Movies',
        'CollectionType': 'movies',
        'ChildCount': 412,
      });

      expect(view.kind, 'movies');
      expect(view.itemCount, 412);
    });

    test('a plain folder with no collection type still lists', () {
      final view = libraryViewFromJson(<String, dynamic>{'Id': 'v2', 'Name': 'Odds'});

      expect(view.kind, 'unknown');
      expect(view.itemCount, isNull);
    });

    test('names sort ascending, everything time-based descending', () {
      expect(sortByFor(ServerSort.name), 'SortName');
      expect(sortOrderFor(ServerSort.name), 'Ascending');
      expect(sortByFor(ServerSort.dateAdded), 'DateCreated');
      expect(sortOrderFor(ServerSort.dateAdded), 'Descending');
    });
  });
}
