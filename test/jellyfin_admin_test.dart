// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:convert';
import 'dart:typed_data' show Uint8List;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mplayer/servers/jellyfin_admin.dart';
import 'package:mplayer/servers/jellyfin_admin_dto.dart';
import 'package:mplayer/servers/jellyfin_source.dart' show ClientIdentity;
import 'package:mplayer/servers/media_library_source.dart' show ServerException;
import 'package:mplayer/servers/server_admin.dart';
import 'package:mplayer/servers/server_profile.dart';

/// Answers requests from a table instead of a network.
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
  isAdministrator: true,
);

(JellyfinAdmin, _FakeAdapter) adminWith(
  ResponseBody Function(RequestOptions) handler,
) {
  final adapter = _FakeAdapter(handler);
  final dio = Dio(BaseOptions(validateStatus: (_) => true))
    ..httpClientAdapter = adapter;

  return (
    JellyfinAdmin(
      profile: _profile,
      token: 'tok',
      identity: const ClientIdentity(deviceId: 'dev1', deviceName: 'Test'),
      client: dio,
    ),
    adapter,
  );
}

void main() {
  group('sessions', () {
    test('what is playing sorts above what is idle', () async {
      // An administrator opening this is looking for who is watching; a list
      // in the server's own order buries that under idle devices.
      final (admin, _) = adminWith(
        (_) => _json(<Map<String, dynamic>>[
          <String, dynamic>{
            'Id': 'idle',
            'UserName': 'nam',
            'DeviceName': 'Android TV',
            'LastActivityDate': '2026-08-30T09:00:00.0000000Z',
          },
          <String, dynamic>{
            'Id': 'playing',
            'UserName': 'minh',
            'DeviceName': 'Chrome',
            'NowPlayingItem': <String, dynamic>{'Name': 'Dune'},
            'LastActivityDate': '2026-08-30T08:00:00.0000000Z',
          },
        ]),
      );

      final sessions = await admin.sessions();

      expect(sessions.map((s) => s.id).toList(), <String>['playing', 'idle']);
      expect(sessions.first.isPlaying, isTrue);
      expect(sessions.last.isPlaying, isFalse);
    });

    test('an episode reads as its series, not as its own title', () async {
      // "The Bicameral Mind" on its own says nothing about what is being
      // watched, which is the one thing this row exists to say.
      final session = adminSessionFromJson(<String, dynamic>{
        'Id': 's1',
        'NowPlayingItem': <String, dynamic>{
          'Name': 'The Bicameral Mind',
          'SeriesName': 'Westworld',
          'ParentIndexNumber': 1,
          'IndexNumber': 10,
          'RunTimeTicks': 54000000000,
        },
        'PlayState': <String, dynamic>{
          'PositionTicks': 27000000000,
          'IsPaused': true,
        },
      })!;

      expect(session.nowPlaying, 'Westworld · S1E10 · The Bicameral Mind');
      expect(session.position, const Duration(minutes: 45));
      expect(session.runtime, const Duration(minutes: 90));
      expect(session.isPaused, isTrue);
      expect(session.progress, closeTo(0.5, 0.001));
    });

    test('a session with no id is dropped rather than drawn', () async {
      // Nothing can be stopped or messaged on it, so its buttons would all
      // fail.
      expect(adminSessionFromJson(<String, dynamic>{'UserName': 'nam'}), isNull);
    });

    test('a message carries a timeout', () async {
      final (admin, adapter) = adminWith((_) => _json(<String, dynamic>{}));

      await admin.messageSession('s1', header: 'mPlayer', text: 'dinner');

      expect(adapter.requests.single.uri.path, '/Sessions/s1/Message');
      // Without one, some clients leave the message up until it is dismissed
      // — which on a television nobody is sitting at means for ever.
      expect(
        (adapter.requests.single.data as Map)['TimeoutMs'],
        isNotNull,
      );
    });
  });

  group('tasks', () {
    test('running tasks come first, then alphabetically', () async {
      final (admin, _) = adminWith(
        (_) => _json(<Map<String, dynamic>>[
          <String, dynamic>{'Id': 'z', 'Name': 'Zulu', 'State': 'Idle'},
          <String, dynamic>{'Id': 'a', 'Name': 'Alpha', 'State': 'Idle'},
          <String, dynamic>{
            'Id': 'r',
            'Name': 'Running one',
            'State': 'Running',
            'CurrentProgressPercentage': 42.5,
          },
        ]),
      );

      final tasks = await admin.tasks();

      expect(tasks.map((t) => t.id).toList(), <String>['r', 'a', 'z']);
      expect(tasks.first.progress, 42.5);
      expect(tasks.first.isRunning, isTrue);
    });

    test('anything but Completed counts as a failed last run', () async {
      ScheduledTask parse(String? status) => scheduledTaskFromJson(
            <String, dynamic>{
              'Id': 't',
              'Name': 'Scan',
              'LastExecutionResult': <String, dynamic>{'Status': status},
            },
          );

      expect(parse('Completed').lastFailed, isFalse);
      expect(parse('Failed').lastFailed, isTrue);
      expect(parse('Cancelled').lastFailed, isTrue);
      // A task that has never run has no result, which is not a failure.
      expect(parse(null).lastFailed, isFalse);
    });

    test('run and stop address the same route two ways', () async {
      final (admin, adapter) = adminWith((_) => _json(<String, dynamic>{}));

      await admin.runTask('t1');
      await admin.stopTask('t1');

      expect(adapter.requests[0].method, 'POST');
      expect(adapter.requests[0].uri.path, '/ScheduledTasks/Running/t1');
      expect(adapter.requests[1].method, 'DELETE');
      expect(adapter.requests[1].uri.path, '/ScheduledTasks/Running/t1');
    });
  });

  group('changing a user', () {
    test('the whole policy is written back, not just the one field', () async {
      // This object *is* the account's permissions. Posting one field would
      // strip every library grant and parental limit it has.
      final (admin, adapter) = adminWith((options) {
        if (options.method == 'GET') {
          return _json(<String, dynamic>{
            'Id': 'u2',
            'Name': 'nam',
            'Policy': <String, dynamic>{
              'IsAdministrator': false,
              'IsDisabled': false,
              'EnabledFolders': <String>['lib-1', 'lib-2'],
              'MaxParentalRating': 13,
            },
          });
        }
        return _json(<String, dynamic>{});
      });

      await admin.setUserDisabled('u2', disabled: true);

      final post = adapter.requests.last;
      expect(post.uri.path, '/Users/u2/Policy');

      final body = post.data as Map;
      expect(body['IsDisabled'], isTrue);
      expect(body['EnabledFolders'], <String>['lib-1', 'lib-2']);
      expect(body['MaxParentalRating'], 13);
    });

    test('a server that will not describe the account changes nothing',
        () async {
      final (admin, adapter) = adminWith(
        (_) => _json(<String, dynamic>{'Id': 'u2', 'Name': 'nam'}),
      );

      await expectLater(
        admin.setUserDisabled('u2', disabled: true),
        throwsA(isA<ServerException>()),
      );
      // Read only. Guessing at a policy and posting it would be worse than
      // refusing.
      expect(adapter.requests.every((r) => r.method == 'GET'), isTrue);
    });
  });

  group('renaming the server', () {
    test('the whole configuration is written back', () async {
      // The route replaces the configuration rather than patching it, so
      // posting `{ServerName: …}` alone would reset every other setting.
      final (admin, adapter) = adminWith((options) {
        if (options.method == 'GET') {
          return _json(<String, dynamic>{
            'ServerName': 'Old',
            'LibraryScanFanoutConcurrency': 4,
            'EnableMetrics': true,
          });
        }
        return _json(<String, dynamic>{});
      });

      await admin.setServerName('  New  ');

      final body = adapter.requests.last.data as Map;
      expect(body['ServerName'], 'New');
      expect(body['LibraryScanFanoutConcurrency'], 4);
      expect(body['EnableMetrics'], isTrue);
    });
  });

  group('plugins', () {
    test('enable and disable are addressed by id and version', () async {
      // A server can hold two versions of one plugin, and only one of them is
      // meant to change.
      final (admin, adapter) = adminWith((_) => _json(<String, dynamic>{}));

      await admin.setPluginEnabled('abc', '1.2.0', enabled: false);
      await admin.setPluginEnabled('abc', '1.2.0', enabled: true);
      await admin.uninstallPlugin('abc', '1.2.0');

      expect(adapter.requests[0].uri.path, '/Plugins/abc/1.2.0/Disable');
      expect(adapter.requests[1].uri.path, '/Plugins/abc/1.2.0/Enable');
      expect(adapter.requests[2].method, 'DELETE');
      expect(adapter.requests[2].uri.path, '/Plugins/abc/1.2.0');
    });

    test('a status the app has no wording for still reads as active', () {
      expect(
        serverPluginFromJson(<String, dynamic>{'Id': 'a', 'Status': 'Active'})
            .isEnabled,
        isTrue,
      );
      expect(
        serverPluginFromJson(<String, dynamic>{'Id': 'a', 'Status': 'Disabled'})
            .isEnabled,
        isFalse,
      );
      expect(
        serverPluginFromJson(<String, dynamic>{'Id': 'a'}).isEnabled,
        isTrue,
      );
    });
  });

  group('what a rejection means', () {
    test('403 says the account is not an administrator, not "sign in again"',
        () async {
      // The whole reason this client has its own error mapping. Sending a
      // user who is signed in perfectly well to a password prompt would send
      // them somewhere that cannot help.
      final (admin, _) = adminWith(
        (_) => _json(<String, dynamic>{}, status: 403),
      );

      await expectLater(
        admin.sessions(),
        throwsA(
          isA<ServerException>()
              .having((e) => e.isUnauthorised, 'isUnauthorised', isFalse)
              .having((e) => e.message, 'message', contains('administrator')),
        ),
      );
    });

    test('401 still means the session is gone', () async {
      final (admin, _) = adminWith(
        (_) => _json(<String, dynamic>{}, status: 401),
      );

      await expectLater(
        admin.sessions(),
        throwsA(
          isA<ServerException>()
              .having((e) => e.isUnauthorised, 'isUnauthorised', isTrue),
        ),
      );
    });
  });

  group('system info', () {
    test('a server that cannot restart itself says so', () async {
      // A server in a container usually cannot: the process is the container.
      // Offering the button anyway offers one that takes the server away and
      // does not bring it back.
      final info = systemInfoFromJson(<String, dynamic>{
        'ServerName': 'Home',
        'Version': '10.10.3',
        'OperatingSystem': 'Linux',
        'SystemArchitecture': 'X64',
        'CanSelfRestart': false,
      });

      expect(info.canRestart, isFalse);
      expect(info.canShutdown, isFalse);
      expect(info.architecture, 'X64');
    });

    test('shutdown falls back to the restart answer on 10.9 and later', () {
      // `CanSelfShutdown` was dropped from the payload; defaulting to the
      // restart answer keeps the button present where it works.
      final info = systemInfoFromJson(<String, dynamic>{
        'Version': '10.10.3',
        'CanSelfRestart': true,
      });

      expect(info.canShutdown, isTrue);
    });
  });

  group('devices', () {
    test('the most recently seen comes first', () async {
      final (admin, _) = adminWith(
        (_) => _json(<String, dynamic>{
          'Items': <Map<String, dynamic>>[
            <String, dynamic>{
              'Id': 'old',
              'Name': 'Old tablet',
              'DateLastActivity': '2026-08-01T09:00:00.0000000Z',
            },
            <String, dynamic>{
              'Id': 'new',
              'Name': 'Phone',
              'DateLastActivity': '2026-08-29T09:00:00.0000000Z',
            },
          ],
        }),
      );

      expect(
        (await admin.devices()).map((d) => d.id).toList(),
        <String>['new', 'old'],
      );
    });

    test('forgetting one names it in the query, not the path', () async {
      final (admin, adapter) = adminWith((_) => _json(<String, dynamic>{}));

      await admin.deleteDevice('dev-9');

      expect(adapter.requests.single.uri.path, '/Devices');
      expect(adapter.requests.single.uri.queryParameters['id'], 'dev-9');
    });
  });

  group('the activity log', () {
    test('severity and the int id both survive', () async {
      final entry = activityEntryFromJson(<String, dynamic>{
        // An int on this route and a string on every other one.
        'Id': 42,
        'Name': 'Playback failed',
        'Severity': 'Error',
        'Date': '2026-08-30T09:12:00.0000000Z',
      });

      expect(entry.id, '42');
      expect(entry.severity, ActivitySeverity.error);
      expect(entry.at, isNotNull);
    });

    test('a severity nobody mapped reads as information', () {
      expect(
        activityEntryFromJson(<String, dynamic>{'Severity': 'Verbose'}).severity,
        ActivitySeverity.information,
      );
    });
  });
}
