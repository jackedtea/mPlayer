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

  group('editing an account', () {
    Map<String, dynamic> serverUser() => <String, dynamic>{
          'Id': 'u2',
          'Name': 'kids',
          'HasConfiguredPassword': false,
          'Policy': <String, dynamic>{
            'IsAdministrator': false,
            'EnableAllFolders': false,
            'EnabledFolders': <String>['lib-1'],
            'MaxParentalRating': 10,
            // Fields the editor does not model, which must survive a save.
            'BlockedTags': <String>['horror'],
            'AccessSchedules': <Map<String, dynamic>>[
              <String, dynamic>{'DayOfWeek': 'Sunday', 'StartHour': 8},
            ],
            'EnableCollectionManagement': false,
          },
        };

    test('reads the policy and whether there is a password', () async {
      final (admin, _) = adminWith((_) => _json(serverUser()));

      final detail = await admin.user('u2');

      expect(detail.user.name, 'kids');
      expect(detail.hasPassword, isFalse);
      expect(detail.policy.enableAllFolders, isFalse);
      expect(detail.policy.enabledFolders, <String>['lib-1']);
      expect(detail.policy.maxParentalRating, 10);
    });

    test('a save keeps every field the editor does not show', () async {
      final (admin, adapter) = adminWith((options) {
        if (options.method == 'GET') return _json(serverUser());
        return _json(<String, dynamic>{});
      });

      final detail = await admin.user('u2');
      await admin.setUserPolicy(
        'u2',
        detail.policy.copyWith(
          enabledFolders: <String>['lib-1', 'lib-2'],
          parentalRating: (score: null, subScore: null),
        ),
      );

      final post = adapter.requests.last;
      expect(post.method, 'POST');
      expect(post.uri.path, '/Users/u2/Policy');

      final body = post.data as Map;
      expect(body['EnabledFolders'], <String>['lib-1', 'lib-2']);
      expect(body.containsKey('MaxParentalRating'), isTrue);
      expect(body['MaxParentalRating'], isNull);
      expect(body['BlockedTags'], <String>['horror']);
      expect(body['AccessSchedules'], hasLength(1));
    });

    test('the policy is read again at save time, not reused', () async {
      // Another administrator may have changed a field this screen does not
      // show since it opened; writing the old copy back would undo it.
      var reads = 0;
      final (admin, _) = adminWith((options) {
        if (options.method == 'GET') {
          reads++;
          return _json(serverUser());
        }
        return _json(<String, dynamic>{});
      });

      await admin.setUserPolicy('u2', const UserPolicy());
      expect(reads, 1);
    });

    test('"all libraries" sends no stale grant list beside it', () {
      final body = applyUserPolicy(
        serverUser()['Policy'] as Map<String, dynamic>,
        const UserPolicy(
          enableAllFolders: true,
          enabledFolders: <String>['lib-1'],
        ),
      );
      expect(body['EnableAllFolders'], isTrue);
      expect(body['EnabledFolders'], isEmpty);
    });

    test('a switch the server does not have is not sent', () {
      // EnableCollectionManagement arrived in 10.9.
      final body = applyUserPolicy(
        <String, dynamic>{'IsAdministrator': false},
        const UserPolicy(enableCollectionManagement: true),
      );
      expect(body.containsKey('EnableCollectionManagement'), isFalse);
    });

    test('a new account sends no password when none was typed', () async {
      final (admin, adapter) = adminWith(
        (_) => _json(<String, dynamic>{'Id': 'new', 'Name': 'anna'}),
      );

      final made = await admin.createUser(' anna ', '');

      expect(made.id, 'new');
      final post = adapter.requests.single;
      expect(post.uri.path, '/Users/New');
      expect(post.data, <String, dynamic>{'Name': 'anna'});
    });

    test('a password is set without the old one', () async {
      final (admin, adapter) = adminWith((_) => _json(<String, dynamic>{}));

      await admin.setUserPassword('u2', 'secret');

      final post = adapter.requests.single;
      expect(post.uri.path, '/Users/u2/Password');
      expect((post.data as Map)['NewPw'], 'secret');
    });

    test('deleting is a DELETE on the account', () async {
      final (admin, adapter) = adminWith((_) => _json(<String, dynamic>{}));

      await admin.deleteUser('u2');

      expect(adapter.requests.single.method, 'DELETE');
      expect(adapter.requests.single.uri.path, '/Users/u2');
    });

    test('libraries leave out what the server hid', () async {
      final (admin, adapter) = adminWith(
        (_) => _json(<String, dynamic>{
          'Items': <Map<String, dynamic>>[
            <String, dynamic>{
              'Id': 'lib-1',
              'Name': 'Films',
              'CollectionType': 'movies',
            },
            <String, dynamic>{'Name': 'no id'},
          ],
        }),
      );

      final libraries = await admin.libraries();

      expect(adapter.requests.single.uri.queryParameters['isHidden'], 'false');
      expect(libraries.map((l) => l.name), <String>['Films']);
    });
  });

  group('parental ratings', () {
    test('one option per score, names joined, lowest first', () {
      final options = parentalRatingsFromJson(<Object?>[
        <String, dynamic>{'Name': 'TV-14', 'Value': 14},
        <String, dynamic>{'Name': 'PG-13', 'Value': 13},
        <String, dynamic>{'Name': 'TV-PG', 'Value': 13},
        <String, dynamic>{'Name': 'Unrated'},
      ]);

      expect(options.map((o) => o.name), <String>['PG-13 / TV-PG', 'TV-14']);
      expect(options.map((o) => o.score), <int>[13, 14]);
    });

    test('the 10.11 rating score, with its sub-score', () {
      final options = parentalRatingsFromJson(<Object?>[
        <String, dynamic>{
          'Name': '12A',
          'Value': 12,
          'RatingScore': <String, dynamic>{'Score': 12, 'SubScore': 1},
        },
        <String, dynamic>{
          'Name': '12',
          'Value': 12,
          'RatingScore': <String, dynamic>{'Score': 12},
        },
      ]);

      expect(options.map((o) => o.name), <String>['12', '12A']);
      expect(options.last.subScore, 1);
    });
  });

  group('one account, its devices and its log', () {
    test('devices are asked for by user', () async {
      final (admin, adapter) =
          adminWith((_) => _json(<String, dynamic>{'Items': <Object>[]}));

      await admin.devices(userId: 'u2');

      expect(adapter.requests.single.uri.queryParameters['userId'], 'u2');
    });

    test('the log is filtered by name on the wire and by id here', () async {
      // 10.11 filters on the name; an older server ignores it and sends
      // everyone's, so the id check is what makes it exact.
      final (admin, adapter) = adminWith(
        (_) => _json(<String, dynamic>{
          'Items': <Map<String, dynamic>>[
            <String, dynamic>{
              'Id': 1,
              'Name': 'kids signed in',
              'UserId': '0f8fad5b-d9cb-469f-a165-70867728950e',
            },
            <String, dynamic>{
              'Id': 2,
              'Name': 'minh signed in',
              'UserId': 'aaaaaaaa-0000-0000-0000-000000000000',
            },
            <String, dynamic>{'Id': 3, 'Name': 'Scan finished'},
          ],
        }),
      );

      final entries = await admin.activity(
        // Without dashes, as `/Users` spells it.
        user: (id: '0F8FAD5BD9CB469FA16570867728950E', name: 'kids'),
      );

      final query = adapter.requests.single.uri.queryParameters;
      expect(query['username'], 'kids');
      expect(query['hasUserId'], 'true');
      expect(entries.map((e) => e.name), <String>['kids signed in']);
    });
  });

  group('libraries and items', () {
    test('folders carry their paths, and progress only while scanning', () {
      final running = adminLibraryFolderFromJson(<String, dynamic>{
        'Name': 'Films',
        'ItemId': 'lib-1',
        'CollectionType': 'movies',
        'Locations': <String>['/media/films', '/mnt/more'],
        'RefreshProgress': 42.5,
        'RefreshStatus': 'Active',
      });
      expect(running.paths, hasLength(2));
      expect(running.refreshProgress, 42.5);

      final idle = adminLibraryFolderFromJson(<String, dynamic>{
        'Name': 'Shows',
        'ItemId': 'lib-2',
        'RefreshProgress': 100,
        'RefreshStatus': 'Idle',
      });
      expect(idle.refreshProgress, isNull);
    });

    test('a scan keeps metadata; a replace throws it away, never images', () {
      final scan = refreshQuery(MetadataRefresh.scan);
      expect(scan['MetadataRefreshMode'], 'Default');
      expect(scan['ReplaceAllMetadata'], 'false');

      final missing = refreshQuery(MetadataRefresh.missing);
      expect(missing['MetadataRefreshMode'], 'FullRefresh');
      expect(missing['ReplaceAllMetadata'], 'false');

      final replace = refreshQuery(MetadataRefresh.replaceAll);
      expect(replace['MetadataRefreshMode'], 'FullRefresh');
      expect(replace['ReplaceAllMetadata'], 'true');
      expect(replace['ReplaceAllImages'], 'false');
    });

    test('refreshing posts to the item with the query', () async {
      final (admin, adapter) = adminWith((_) => _json(<String, dynamic>{}));

      await admin.refreshItem('lib-1', MetadataRefresh.missing);

      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.uri.path, '/Items/lib-1/Refresh');
      expect(request.uri.queryParameters['Recursive'], 'true');
    });

    test('rename and remove address the library by name', () async {
      final (admin, adapter) = adminWith((_) => _json(<String, dynamic>{}));

      await admin.renameLibrary('Films', ' Movies ');
      await admin.deleteLibrary('Films');

      final rename = adapter.requests.first;
      expect(rename.uri.path, '/Library/VirtualFolders/Name');
      expect(rename.uri.queryParameters['name'], 'Films');
      expect(rename.uri.queryParameters['newName'], 'Movies');

      final remove = adapter.requests.last;
      expect(remove.method, 'DELETE');
      expect(remove.uri.path, '/Library/VirtualFolders');
      expect(remove.uri.queryParameters['name'], 'Films');
    });

    test('metadata is read from the item, sort name only when forced', () {
      final m = itemMetadataFromJson(<String, dynamic>{
        'Name': 'Dune',
        'SortName': 'dune',
        'ProductionYear': 2021,
        'Genres': <String>['Science Fiction', ' '],
        'Tags': <String>['imax'],
        'LockData': true,
      });

      expect(m.name, 'Dune');
      // The server's own derivation; writing it back would freeze it.
      expect(m.sortName, '');
      expect(m.year, 2021);
      expect(m.genres, <String>['Science Fiction']);
      expect(m.locked, isTrue);
    });

    test('a save keeps every field the editor does not show', () async {
      final server = <String, dynamic>{
        'Id': 'i1',
        'Name': 'Dune',
        'ProductionYear': 2021,
        'People': <Map<String, dynamic>>[
          <String, dynamic>{'Name': 'Denis Villeneuve', 'Type': 'Director'},
        ],
        'ProviderIds': <String, dynamic>{'Imdb': 'tt1160419'},
        'PremiereDate': '2021-09-15T00:00:00.0000000Z',
      };
      var reads = 0;
      final (admin, adapter) = adminWith((options) {
        if (options.method == 'GET') {
          reads++;
          return _json(server);
        }
        return _json(<String, dynamic>{});
      });

      await admin.setItemMetadata(
        'i1',
        const ItemMetadata(name: 'Dune: Part One', overview: '  '),
      );

      // Read at save time, not reused from when the editor opened.
      expect(reads, 1);
      final get = adapter.requests.first;
      expect(get.uri.path, '/Items/i1');
      expect(get.uri.queryParameters['userId'], 'u1');

      final post = adapter.requests.last;
      expect(post.uri.path, '/Items/i1');
      final body = post.data as Map;
      expect(body['Name'], 'Dune: Part One');
      // Blank is "none", not an overview of spaces.
      expect(body['Overview'], isNull);
      // The year was cleared in the editor's copy, so it goes.
      expect(body['ProductionYear'], isNull);
      expect(body['People'], hasLength(1));
      expect(body['ProviderIds'], <String, dynamic>{'Imdb': 'tt1160419'});
      expect(body['PremiereDate'], isNotNull);
    });

    test('deleting an item is a DELETE on it', () async {
      final (admin, adapter) = adminWith((_) => _json(<String, dynamic>{}));

      await admin.deleteItem('i1');

      expect(adapter.requests.single.method, 'DELETE');
      expect(adapter.requests.single.uri.path, '/Items/i1');
    });
  });

  group('what a session is doing to the server', () {
    test('the play method and the transcode, with reasons as a list', () {
      final session = adminSessionFromJson(<String, dynamic>{
        'Id': 's1',
        'NowPlayingItem': <String, dynamic>{'Name': 'Dune'},
        'PlayState': <String, dynamic>{'PlayMethod': 'Transcode'},
        'ApplicationVersion': '10.11.0',
        'RemoteEndPoint': '192.168.1.20',
        'TranscodingInfo': <String, dynamic>{
          'IsVideoDirect': false,
          'IsAudioDirect': true,
          'VideoCodec': 'h264',
          'Bitrate': 8400000,
          'HardwareAccelerationType': 'none',
          'TranscodeReasons': <String>['VideoCodecNotSupported'],
        },
      })!;

      expect(session.playMethod, PlayMethod.transcode);
      expect(session.clientVersion, '10.11.0');
      expect(session.remoteAddress, '192.168.1.20');
      final t = session.transcoding!;
      expect(t.isVideoDirect, isFalse);
      expect(t.bitrate, 8400000);
      // "none" is software, said as nothing rather than as "NONE".
      expect(t.hardwareAcceleration, '');
      expect(t.reasons, <String>['VideoCodecNotSupported']);
    });

    test('older servers write the reasons as one string', () {
      expect(
        transcodeReasonsFromJson('ContainerNotSupported, AudioCodecNotSupported'),
        <String>['ContainerNotSupported', 'AudioCodecNotSupported'],
      );
      expect(transcodeReasonsFromJson(null), isEmpty);
    });

    test('an idle session has no play method, whatever the state says', () {
      final session = adminSessionFromJson(<String, dynamic>{
        'Id': 's1',
        'PlayState': <String, dynamic>{'PlayMethod': 'DirectPlay'},
      })!;
      expect(session.playMethod, isNull);
      expect(session.transcoding, isNull);
    });
  });

  group('tasks, storage and the system', () {
    test('triggers come with their times', () {
      final task = scheduledTaskFromJson(<String, dynamic>{
        'Id': 't1',
        'Name': 'Scan',
        'Triggers': <Map<String, dynamic>>[
          <String, dynamic>{
            'Type': 'DailyTrigger',
            'TimeOfDayTicks': 3 * 60 * 60 * 10000000,
          },
          <String, dynamic>{
            'Type': 'IntervalTrigger',
            'IntervalTicks': 12 * 60 * 60 * 10000000,
          },
          <String, dynamic>{
            'Type': 'WeeklyTrigger',
            'DayOfWeek': 'Sunday',
            'TimeOfDayTicks': 0,
          },
          <String, dynamic>{'Type': 'StartupTrigger'},
        ],
      });

      expect(task.triggers.map((t) => t.kind), <TaskTriggerKind>[
        TaskTriggerKind.daily,
        TaskTriggerKind.interval,
        TaskTriggerKind.weekly,
        TaskTriggerKind.startup,
      ]);
      expect(task.triggers[0].timeOfDay, const Duration(hours: 3));
      expect(task.triggers[1].interval, const Duration(hours: 12));
      // Midnight is a real time, not "unset".
      expect(task.triggers[2].timeOfDay, Duration.zero);
      expect(task.triggers[2].dayOfWeek, 'Sunday');
    });

    test('a restart that is waiting is read', () {
      final info = systemInfoFromJson(<String, dynamic>{
        'ServerName': 'Home',
        'HasPendingRestart': true,
      });
      expect(info.hasPendingRestart, isTrue);
    });

    test('storage: -1 is "could not measure", not a size', () {
      final storage = serverStorageFromJson(<String, dynamic>{
        'CacheFolder': <String, dynamic>{
          'Path': '/cache',
          'FreeSpace': 1000,
          'UsedSpace': -1,
        },
        'Libraries': <Map<String, dynamic>>[
          <String, dynamic>{
            'Name': 'Films',
            'Folders': <Map<String, dynamic>>[
              <String, dynamic>{'Path': '/media/films', 'FreeSpace': 5},
            ],
          },
        ],
      });
      expect(storage.folders.single.kind, StorageFolderKind.cache);
      expect(storage.folders.single.free, 1000);
      expect(storage.folders.single.used, isNull);
      expect(storage.libraries.single.folders.single.path, '/media/films');
    });

    test('a server before 10.10 has no storage to report', () async {
      final (admin, _) = adminWith((_) => _json('', status: 404));
      expect(await admin.storage(), isNull);
    });

    test('other storage failures are still failures', () async {
      final (admin, _) = adminWith(
        (_) => _json(<String, dynamic>{}, status: 500),
      );
      await expectLater(admin.storage(), throwsA(isA<ServerException>()));
    });
  });

  group('logs', () {
    test('a large log is cut to its tail, at a line', () {
      final text = 'first line\nsecond line\nthird line\n';
      final tail = logTail(text, 15);
      expect(tail, 'third line\n');
      expect(logTail(text, 1000), text);
    });

    test('the text is fetched as text, by name in the query', () async {
      final (admin, adapter) = adminWith(
        (_) => ResponseBody.fromString(
          '{"looks": "like json"}\n[ERR] real line\n',
          200,
          headers: <String, List<String>>{
            Headers.contentTypeHeader: <String>['application/json'],
          },
        ),
      );

      final text = await admin.logText('log_1.log');

      expect(adapter.requests.single.uri.path, '/System/Logs/Log');
      expect(adapter.requests.single.uri.queryParameters['name'], 'log_1.log');
      expect(text, contains('real line'));
    });
  });

  group('the activity log in pages', () {
    test('asks from the start index, with the filters on the wire', () async {
      final (admin, adapter) = adminWith(
        (_) => _json(<String, dynamic>{
          'TotalRecordCount': 120,
          'Items': <Map<String, dynamic>>[
            <String, dynamic>{'Id': 1, 'Name': 'ok', 'Severity': 'Information'},
            <String, dynamic>{'Id': 2, 'Name': 'bad', 'Severity': 'Error'},
          ],
        }),
      );

      final page = await admin.activityPage(
        startIndex: 50,
        problemsOnly: true,
        since: DateTime.utc(2026, 11, 9),
      );

      final query = adapter.requests.single.uri.queryParameters;
      expect(query['startIndex'], '50');
      expect(query['severity'], 'Warning');
      expect(query['minDate'], startsWith('2026-11-09'));
      // An older server ignored the filter; it is applied here too, and the
      // next page still starts after everything that was sent.
      expect(page.entries.map((e) => e.name), <String>['bad']);
      expect(page.fetched, 2);
      expect(page.total, 120);
    });
  });

  group('API keys', () {
    test('listed newest first, created by app name, revoked by key', () async {
      final (admin, adapter) = adminWith((options) {
        if (options.method == 'GET') {
          return _json(<String, dynamic>{
            'Items': <Map<String, dynamic>>[
              <String, dynamic>{
                'AccessToken': 'old',
                'AppName': 'A',
                'DateCreated': '2025-01-01T00:00:00Z',
              },
              <String, dynamic>{
                'AccessToken': 'new',
                'AppName': 'B',
                'DateCreated': '2026-01-01T00:00:00Z',
              },
              <String, dynamic>{'AppName': 'no token'},
            ],
          });
        }
        return _json(<String, dynamic>{});
      });

      final keys = await admin.apiKeys();
      expect(keys.map((k) => k.token), <String>['new', 'old']);

      await admin.createApiKey(' Sonarr ');
      final create = adapter.requests.last;
      expect(create.method, 'POST');
      expect(create.uri.path, '/Auth/Keys');
      expect(create.uri.queryParameters['app'], 'Sonarr');

      await admin.revokeApiKey('old');
      expect(adapter.requests.last.method, 'DELETE');
      expect(adapter.requests.last.uri.path, '/Auth/Keys/old');
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

    test('a refusal the server explained is passed on in its words',
        () async {
      // The policy route answers 403 for "there must be at least one
      // administrator"; "you are not an administrator" would be false.
      final (admin, _) = adminWith(
        (_) => _json(
          'There must be at least one user in the system with administrative '
          'access.',
          status: 403,
        ),
      );

      await expectLater(
        admin.setUserPassword('u1', 'x'),
        throwsA(
          isA<ServerException>().having(
            (e) => e.message,
            'message',
            contains('at least one user'),
          ),
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
