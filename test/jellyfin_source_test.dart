// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:convert';
import 'dart:typed_data' show Uint8List;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mplayer/servers/jellyfin_source.dart';
import 'package:mplayer/servers/media_library_source.dart';
import 'package:mplayer/servers/server_profile.dart';

/// Answers requests from a table instead of a network.
///
/// A recorded server, in other words: the point of these tests is the shape
/// of what this client sends and how it reads what comes back, neither of
/// which needs a Jellyfin instance to check.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final ResponseBody Function(RequestOptions options) handler;
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object body, {int status = 200}) {
  return ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    },
  );
}

const _profile = ServerProfile(
  id: 'p1',
  kind: ServerKind.jellyfin,
  name: 'Home',
  uri: 'https://media.home.lan',
  userId: 'u1',
  username: 'nam',
);

const _identity = ClientIdentity(deviceId: 'dev1', deviceName: 'Test');

(JellyfinSource, _FakeAdapter) sourceWith(
  ResponseBody Function(RequestOptions) handler,
) {
  final adapter = _FakeAdapter(handler);
  final dio = Dio(BaseOptions(validateStatus: (_) => true))
    ..httpClientAdapter = adapter;

  return (
    JellyfinSource(
      profile: _profile,
      token: 'tok',
      identity: _identity,
      client: dio,
    ),
    adapter,
  );
}

void main() {
  group('requests', () {
    test('every call carries the MediaBrowser authorization header', () async {
      final (source, adapter) = sourceWith(
        (_) => _json(<String, dynamic>{'Items': <dynamic>[]}),
      );

      await source.views();

      final header = adapter.requests.single.headers['Authorization'] as String;
      expect(header, startsWith('MediaBrowser '));
      expect(header, contains('Token="tok"'));
      expect(header, contains('DeviceId="dev1"'));
    });

    test('a library listing asks recursively, or it returns folders',
        () async {
      final (source, adapter) = sourceWith(
        (_) => _json(<String, dynamic>{'Items': <dynamic>[]}),
      );

      await source.items('v1', limit: 50, sort: ServerSort.dateAdded);

      final query = adapter.requests.single.uri.queryParameters;
      expect(query['parentId'], 'v1');
      expect(query['recursive'], 'true');
      expect(query['limit'], '50');
      expect(query['sortBy'], 'DateCreated');
      expect(query['sortOrder'], 'Descending');
    });

    test('a reverse-proxy prefix survives into every path', () async {
      final adapter = _FakeAdapter(
        (_) => _json(<String, dynamic>{'Items': <dynamic>[]}),
      );
      final dio = Dio(BaseOptions(validateStatus: (_) => true))
        ..httpClientAdapter = adapter;

      final source = JellyfinSource(
        profile: const ServerProfile(
          id: 'p2',
          kind: ServerKind.jellyfin,
          name: 'Proxied',
          uri: 'https://home.example.com/jellyfin',
          userId: 'u1',
          username: 'nam',
        ),
        token: 't',
        identity: _identity,
        client: dio,
      );

      await source.views();

      expect(adapter.requests.single.uri.path, '/jellyfin/UserViews');
    });

    test('stopping reports the position, which also ends a transcode',
        () async {
      final (source, adapter) = sourceWith((_) => _json(<String, dynamic>{}));

      await source.reportStopped(
        'a1',
        position: const Duration(minutes: 3),
        playSessionId: 'sess',
      );

      final body = adapter.requests.single.data as Map<String, dynamic>;
      expect(body['ItemId'], 'a1');
      expect(body['PlaySessionId'], 'sess');
      // Ticks, not milliseconds.
      expect(body['PositionTicks'], 1800000000);
    });

    test('unmarking played is a DELETE, not a POST with a flag', () async {
      final (source, adapter) = sourceWith((_) => _json(<String, dynamic>{}));

      await source.setPlayed('a1', played: false);

      expect(adapter.requests.single.method, 'DELETE');
      expect(adapter.requests.single.uri.path, '/UserPlayedItems/a1');
    });
  });

  group('responses', () {
    test('items come back parsed', () async {
      final (source, _) = sourceWith(
        (_) => _json(<String, dynamic>{
          'Items': <dynamic>[
            <String, dynamic>{
              'Id': 'a1',
              'Name': 'Dune',
              'Type': 'Movie',
              'RunTimeTicks': 55350000000,
            },
          ],
        }),
      );

      final items = await source.items('v1');

      expect(items.single.title, 'Dune');
      expect(items.single.runtime, const Duration(minutes: 92, seconds: 15));
    });

    test('a bare object from /Items/{id} is read as one item', () async {
      final (source, _) = sourceWith(
        (_) => _json(<String, dynamic>{'Id': 'a1', 'Name': 'Arrival'}),
      );

      expect((await source.item('a1')).title, 'Arrival');
    });

    test('a 401 says the session expired and is flagged as such', () async {
      // The UI answers this one by asking for the password again, which it
      // can only do if the reason is distinguishable from any other failure.
      final (source, _) = sourceWith(
        (_) => _json(<String, dynamic>{}, status: 401),
      );

      await expectLater(
        source.views(),
        throwsA(
          isA<ServerException>()
              .having((e) => e.isUnauthorised, 'isUnauthorised', isTrue)
              .having((e) => e.message, 'message', contains('Home')),
        ),
      );
    });

    test('a 500 names the server rather than the status alone', () async {
      final (source, _) = sourceWith(
        (_) => _json(<String, dynamic>{}, status: 500),
      );

      await expectLater(
        source.views(),
        throwsA(
          isA<ServerException>()
              .having((e) => e.isUnauthorised, 'isUnauthorised', isFalse)
              .having((e) => e.message, 'message', contains('Home')),
        ),
      );
    });

    test('a playback response with no source is an error, not a null URL',
        () async {
      final (source, _) = sourceWith(
        (_) => _json(<String, dynamic>{'MediaSources': <dynamic>[]}),
      );

      await expectLater(
        source.playback('a1', const PlaybackCapabilities()),
        throwsA(isA<ServerException>()),
      );
    });
  });

  group('sign-in', () {
    test('probe reads the public info and spots Emby', () async {
      final adapter = _FakeAdapter(
        (_) => _json(<String, dynamic>{
          'ServerName': 'Living room',
          'Version': '4.9.0',
          'Id': 'srv1',
          'ProductName': 'Emby Server',
        }),
      );
      final dio = Dio(BaseOptions(validateStatus: (_) => true))
        ..httpClientAdapter = adapter;

      final auth = JellyfinAuth(identity: _identity, client: dio);
      final info = await auth.probe('media.home.lan');

      expect(info.name, 'Living room');
      expect(info.kind, ServerKind.emby);
      // The typed address had no scheme; probing must still have worked.
      expect(info.uri, 'http://media.home.lan');
      expect(adapter.requests.single.uri.path, '/System/Info/Public');
    });

    test('Emby 4.9 is recognised even though it omits ProductName', () async {
      // The trap: an Emby server filed as Jellyfin gets called on routes it
      // does not have. `RemoteAddresses` is the only signal it gives.
      final dio = Dio(BaseOptions(validateStatus: (_) => true))
        ..httpClientAdapter = _FakeAdapter(
          (_) => _json(<String, dynamic>{
            'ServerName': 'Old Emby',
            'Id': 'srv2',
            'RemoteAddresses': <dynamic>['1.2.3.4'],
          }),
        );

      final auth = JellyfinAuth(identity: _identity, client: dio);
      expect((await auth.probe('http://host')).kind, ServerKind.emby);
    });

    test('a server naming itself Jellyfin is Jellyfin', () async {
      final dio = Dio(BaseOptions(validateStatus: (_) => true))
        ..httpClientAdapter = _FakeAdapter(
          (_) => _json(<String, dynamic>{
            'ServerName': 'Home',
            'Id': 's',
            'ProductName': 'Jellyfin Server',
          }),
        );

      final auth = JellyfinAuth(identity: _identity, client: dio);
      expect((await auth.probe('http://host')).kind, ServerKind.jellyfin);
    });

    test('something that is not a server says so', () async {
      final dio = Dio(BaseOptions(validateStatus: (_) => true))
        ..httpClientAdapter = _FakeAdapter(
          (_) => ResponseBody.fromString('<html>hello</html>', 200),
        );

      final auth = JellyfinAuth(identity: _identity, client: dio);

      await expectLater(auth.probe('http://router.lan'),
          throwsA(isA<ServerException>()));
    });

    test('signing in returns a token and the user id endpoints need',
        () async {
      final adapter = _FakeAdapter(
        (_) => _json(<String, dynamic>{
          'AccessToken': 'tok123',
          'ServerId': 'srv1',
          'User': <String, dynamic>{'Id': 'u9', 'Name': 'nam'},
        }),
      );
      final dio = Dio(BaseOptions(validateStatus: (_) => true))
        ..httpClientAdapter = adapter;

      final auth = JellyfinAuth(identity: _identity, client: dio);
      final result = await auth.signIn(
        const ServerInfo(
          uri: 'https://media.home.lan',
          name: 'Home',
          version: '10.9',
          serverId: 'srv1',
          kind: ServerKind.jellyfin,
        ),
        username: 'nam',
        password: 'hunter2',
      );

      expect(result.token, 'tok123');
      expect(result.userId, 'u9');

      // The sign-in request itself must not claim a token it does not have.
      final header = adapter.requests.single.headers['Authorization'] as String;
      expect(header, isNot(contains('Token=')));
    });

    test('a wrong password is reported as such, not as a server error',
        () async {
      final dio = Dio(BaseOptions(validateStatus: (_) => true))
        ..httpClientAdapter = _FakeAdapter(
          (_) => _json(<String, dynamic>{}, status: 401),
        );

      final auth = JellyfinAuth(identity: _identity, client: dio);

      await expectLater(
        auth.signIn(
          const ServerInfo(
            uri: 'https://media.home.lan',
            name: 'Home',
            version: '10.9',
            serverId: 's',
            kind: ServerKind.jellyfin,
          ),
          username: 'nam',
          password: 'wrong',
        ),
        throwsA(
          isA<ServerException>()
              .having((e) => e.isUnauthorised, 'isUnauthorised', isTrue),
        ),
      );
    });
  });
}
