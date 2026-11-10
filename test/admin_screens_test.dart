// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mplayer/app/app.dart';
import 'package:mplayer/app/router.dart';
import 'package:mplayer/features/admin/admin_dashboard_page.dart';
import 'package:mplayer/features/admin/admin_providers.dart';
import 'package:mplayer/features/admin/admin_user_page.dart';
import 'package:mplayer/servers/media_library_source.dart'
    show ServerException;
import 'package:mplayer/servers/server_admin.dart';

/// A server that answers every administration question.
class FakeAdmin implements ServerAdmin {
  FakeAdmin({
    this.canRestart = true,
    this.pendingRestart = false,
    this.hasStorage = true,
  });

  final bool canRestart;
  final bool pendingRestart;

  /// False is a server before 10.10, which cannot report disk use.
  final bool hasStorage;

  final List<String> calls = <String>[];

  @override
  Future<ServerSystemInfo> systemInfo() async => ServerSystemInfo(
        name: 'Home',
        version: '10.10.3',
        operatingSystem: 'Linux',
        architecture: 'X64',
        canRestart: canRestart,
        canShutdown: canRestart,
        hasPendingRestart: pendingRestart,
      );

  @override
  Future<List<AdminSession>> sessions() async => <AdminSession>[
        const AdminSession(
          id: 'playing',
          username: 'minh',
          deviceName: 'Chrome',
          client: 'Jellyfin Web',
          nowPlaying: 'Dune',
          position: Duration(minutes: 41),
          runtime: Duration(minutes: 155),
          supportsRemoteControl: true,
          playMethod: PlayMethod.transcode,
          transcoding: SessionTranscoding(
            isVideoDirect: false,
            videoCodec: 'h264',
            width: 1920,
            height: 1080,
            bitrate: 8400000,
            reasons: <String>['VideoCodecNotSupported', 'SomethingNew'],
          ),
        ),
        const AdminSession(
          id: 'idle',
          username: 'nam',
          deviceName: 'Android TV',
          // A renderer that accepts neither stop nor message.
          supportsRemoteControl: false,
        ),
      ];

  @override
  Future<List<ScheduledTask>> tasks() async => <ScheduledTask>[
        const ScheduledTask(
          id: 'running',
          name: 'Scan media library',
          state: TaskState.running,
          progress: 62,
        ),
        const ScheduledTask(
          id: 'idle',
          name: 'Clean transcode directory',
          triggers: <TaskTrigger>[
            TaskTrigger(
              kind: TaskTriggerKind.daily,
              timeOfDay: Duration(hours: 3),
            ),
            TaskTrigger(kind: TaskTriggerKind.startup),
          ],
        ),
      ];

  @override
  Future<List<AdminUser>> users() async => <AdminUser>[
        const AdminUser(id: 'u1', name: 'minh', isAdministrator: true),
        const AdminUser(id: 'u2', name: 'guest', isDisabled: true),
        const AdminUser(id: 'u3', name: 'kids'),
      ];

  /// What the editor saved, per account.
  final Map<String, UserPolicy> savedPolicies = <String, UserPolicy>{};

  @override
  Future<AdminUserDetail> user(String userId) async {
    final user = (await users()).firstWhere((u) => u.id == userId);
    return AdminUserDetail(
      user: user,
      policy: savedPolicies[userId] ??
          UserPolicy(
            isAdministrator: user.isAdministrator,
            isDisabled: user.isDisabled,
          ),
      hasPassword: userId != 'u3',
    );
  }

  @override
  Future<void> setUserPolicy(String userId, UserPolicy policy) async {
    calls.add('policy:$userId');
    savedPolicies[userId] = policy;
  }

  @override
  Future<AdminUser> createUser(String name, String password) async {
    calls.add('create:$name:$password');
    return AdminUser(id: 'new', name: name);
  }

  @override
  Future<void> deleteUser(String userId) async => calls.add('delete:$userId');

  @override
  Future<void> setUserPassword(String userId, String password) async =>
      calls.add('password:$userId:$password');

  @override
  Future<List<AdminLibrary>> libraries() async => const <AdminLibrary>[
        AdminLibrary(id: 'films', name: 'Films', kind: 'movies'),
        AdminLibrary(id: 'shows', name: 'Shows', kind: 'tvshows'),
      ];

  @override
  Future<List<ParentalRatingOption>> parentalRatings() async =>
      const <ParentalRatingOption>[
        ParentalRatingOption(name: 'PG', score: 10),
        ParentalRatingOption(name: 'PG-13 / TV-14', score: 13),
      ];

  @override
  Future<List<AdminDevice>> devices({String? userId}) async => <AdminDevice>[
        if (userId == null || userId == 'u3')
          const AdminDevice(
          id: 'd1',
          name: 'Living room TV',
          appName: 'Jellyfin Android TV',
          username: 'nam',
        ),
      ];

  @override
  Future<List<ActivityEntry>> activity({
    int limit = 50,
    ({String id, String name})? user,
  }) async =>
      <ActivityEntry>[
        if (user == null)
          const ActivityEntry(
            id: '1',
            name: 'minh signed in',
            severity: ActivitySeverity.information,
            userId: 'u1',
          ),
        if (user == null || user.id == 'u3')
          const ActivityEntry(
            id: '3',
            name: 'kids is playing Bluey',
            userId: 'u3',
          ),
        // The server's own line, caused by no account.
        if (user == null)
          const ActivityEntry(
            id: '2',
            name: 'Playback failed',
            severity: ActivitySeverity.error,
          ),
      ];

  @override
  Future<List<ServerPlugin>> plugins() async => <ServerPlugin>[
        const ServerPlugin(
          id: 'intro',
          name: 'Intro Skipper',
          version: '1.2.0',
        ),
        const ServerPlugin(
          id: 'builtin',
          name: 'Bundled thing',
          version: '1.0.0',
          status: PluginStatus.disabled,
          canUninstall: false,
        ),
      ];

  @override
  Future<void> stopSession(String sessionId) async => calls.add('stop:$sessionId');

  @override
  Future<void> messageSession(
    String sessionId, {
    required String header,
    required String text,
  }) async =>
      calls.add('message:$sessionId:$text');

  @override
  Future<void> runTask(String taskId) async => calls.add('run:$taskId');

  @override
  Future<void> stopTask(String taskId) async => calls.add('stopTask:$taskId');

  @override
  Future<void> scanLibraries() async => calls.add('scan');

  @override
  Future<void> setUserDisabled(String userId, {required bool disabled}) async =>
      calls.add('disable:$userId:$disabled');

  @override
  Future<void> deleteDevice(String deviceId) async =>
      calls.add('forget:$deviceId');

  @override
  Future<void> setPluginEnabled(
    String pluginId,
    String version, {
    required bool enabled,
  }) async =>
      calls.add('plugin:$pluginId:$enabled');

  @override
  Future<void> uninstallPlugin(String pluginId, String version) async =>
      calls.add('uninstall:$pluginId');

  @override
  Future<void> setServerName(String name) async => calls.add('rename:$name');

  @override
  Future<void> restartServer() async => calls.add('restart');

  @override
  Future<void> shutdownServer() async => calls.add('shutdown');

  @override
  Future<List<AdminLibraryFolder>> libraryFolders() async =>
      const <AdminLibraryFolder>[
        AdminLibraryFolder(
          name: 'Films',
          itemId: 'lib-films',
          kind: 'movies',
          paths: <String>['/media/films'],
        ),
      ];

  @override
  Future<void> refreshItem(String itemId, MetadataRefresh mode) async =>
      calls.add('refresh:$itemId:${mode.name}');

  @override
  Future<void> renameLibrary(String name, String newName) async =>
      calls.add('renameLibrary:$name:$newName');

  @override
  Future<void> deleteLibrary(String name) async =>
      calls.add('deleteLibrary:$name');

  @override
  Future<void> deleteItem(String itemId) async =>
      calls.add('deleteItem:$itemId');

  final Map<String, ItemMetadata> savedMetadata = <String, ItemMetadata>{};

  @override
  Future<ItemMetadata> itemMetadata(String itemId) async =>
      savedMetadata[itemId] ??
      const ItemMetadata(
        name: 'Dune',
        year: 2021,
        genres: <String>['Science Fiction'],
      );

  @override
  Future<void> setItemMetadata(String itemId, ItemMetadata metadata) async {
    calls.add('metadata:$itemId');
    savedMetadata[itemId] = metadata;
  }

  /// The pages asked for, as `start:problemsOnly`.
  final List<String> activityAsks = <String>[];

  @override
  Future<ActivityPage> activityPage({
    int startIndex = 0,
    int limit = 50,
    bool problemsOnly = false,
    DateTime? since,
  }) async {
    activityAsks.add('$startIndex:$problemsOnly:${since != null}');
    // Two pages of [limit] and a short third, for "Load more".
    final count = startIndex >= 2 * limit ? 3 : limit;
    final entries = <ActivityEntry>[
      for (var i = 0; i < count; i++)
        ActivityEntry(
          id: '${startIndex + i}',
          name: 'Entry ${startIndex + i}',
          severity: problemsOnly
              ? ActivitySeverity.error
              : ActivitySeverity.information,
        ),
    ];
    return ActivityPage(entries: entries, fetched: count);
  }

  @override
  Future<List<ServerLogFile>> logFiles() async => const <ServerLogFile>[
        ServerLogFile(name: 'log_20261110.log', size: 2048),
      ];

  @override
  Future<String> logText(String name, {int maxBytes = 512 * 1024}) async =>
      '[2026-11-10 03:00:00.000 +07:00] [INF] [1] Main: Server started\n'
      '[2026-11-10 03:00:01.000 +07:00] [WRN] [1] Disk is getting full\n'
      '[2026-11-10 03:00:02.000 +07:00] [ERR] [1] Playback failed\n';

  @override
  Future<ServerStorage?> storage() async => hasStorage
      ? const ServerStorage(
          folders: <StorageFolder>[
            StorageFolder(
              path: '/cache/transcodes',
              kind: StorageFolderKind.transcodes,
              free: 5 * 1024 * 1024 * 1024,
              used: 20 * 1024 * 1024 * 1024,
            ),
          ],
          libraries: <({String name, List<StorageFolder> folders})>[
            (
              name: 'Films',
              folders: <StorageFolder>[
                StorageFolder(path: '/media/films', free: 800000000000),
              ],
            ),
          ],
        )
      : null;

  final List<ServerApiKey> keys = <ServerApiKey>[
    const ServerApiKey(token: 'abcd1234efgh5678', appName: 'Sonarr'),
  ];

  @override
  Future<List<ServerApiKey>> apiKeys() async => List.of(keys);

  @override
  Future<void> createApiKey(String appName) async {
    calls.add('createKey:$appName');
    keys.add(ServerApiKey(token: 'new0000000000key', appName: appName));
  }

  @override
  Future<void> revokeApiKey(String token) async {
    calls.add('revokeKey:$token');
    keys.removeWhere((k) => k.token == token);
  }

  /// A server disk of `/`, `/media` and `/media/films`.
  static const Map<String, List<String>> disk = <String, List<String>>{
    '/': <String>['media'],
    '/media': <String>['films'],
    '/media/films': <String>[],
  };

  @override
  Future<List<ServerFolder>> drives() async =>
      const <ServerFolder>[ServerFolder(name: '/', path: '/')];

  @override
  Future<List<ServerFolder>> folders(String path) async {
    final children = disk[path];
    if (children == null) {
      throw const ServerException('That folder does not exist on the server.');
    }
    return <ServerFolder>[
      for (final String c in children)
        ServerFolder(name: c, path: path == '/' ? '/$c' : '$path/$c'),
    ];
  }

  @override
  Future<String?> parentFolder(String path) async {
    if (path == '/') return null;
    final cut = path.lastIndexOf('/');
    return cut <= 0 ? '/' : path.substring(0, cut);
  }

  @override
  Future<void> addLibrary({
    required String name,
    required String? kind,
    required List<String> paths,
  }) async =>
      calls.add('addLibrary:$name:$kind:${paths.join('|')}');

  @override
  Future<void> addLibraryPath(String name, String path) async =>
      calls.add('addPath:$name:$path');

  @override
  Future<void> removeLibraryPath(String name, String path) async =>
      calls.add('removePath:$name:$path');

  @override
  Future<void> dispose() async {}
}

/// Opens [route] with [admin] behind it. A null admin is the guard's case:
/// nothing signed in, or an account that is not an administrator.
Future<FakeAdmin?> pumpAdmin(
  WidgetTester tester,
  String route, {
  FakeAdmin? admin,
  bool isAdministrator = true,
  Size size = const Size(900, 900),
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);

  final resolved = admin ?? (isAdministrator ? FakeAdmin() : null);

  final router = buildRouter();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        serverAdminProvider.overrideWith((ref) async => resolved),
        isAdministratorProvider.overrideWithValue(isAdministrator),
      ],
      child: MPlayerApp(router: router),
    ),
  );
  await tester.pumpAndSettle();

  router.go(route);
  await tester.pumpAndSettle();

  return resolved;
}

/// The editor's own list. `Scrollable.first` would be the users list under
/// it once the editor was pushed from there.
///
/// Vertical only: the tabs' own `PageView` is a horizontal scrollable too.
final Finder _editorScrollable = find
    .descendant(
      of: find.byType(AdminUserPage),
      matching: find.byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
      ),
    )
    .first;

void main() {
  group('the guard', () {
    testWidgets('without an administrator the dashboard is a sentence',
        (tester) async {
      // The route being reachable is not permission. Somebody who reaches it
      // without one has to land on an explanation, not on a dashboard that
      // 403s in the background.
      //
      // The wording splits on *why*: no server signed in at all reads
      // differently from an account that is signed in and not an
      // administrator, and only the first is reachable from a bare test
      // harness with an empty registry.
      await pumpAdmin(tester, '/admin', isAdministrator: false);

      expect(find.text('Sign in to a server first.'), findsOneWidget);
      expect(find.text('Active sessions'), findsNothing);
      expect(find.byIcon(Icons.stop_circle_outlined), findsNothing);
    });

    testWidgets('every admin screen carries the same guard', (tester) async {
      // The guard lives in `AdminScaffold` precisely so this is true of all
      // five without each screen re-deriving it.
      for (final String route in <String>[
        '/admin/tasks',
        '/admin/users',
        '/admin/activity',
        '/admin/plugins',
      ]) {
        await pumpAdmin(tester, route, isAdministrator: false);
        expect(
          find.text('Sign in to a server first.'),
          findsOneWidget,
          reason: '$route drew no guard',
        );
      }
    });

    testWidgets('the Settings row is absent for a non-administrator',
        (tester) async {
      await pumpAdmin(tester, '/settings', isAdministrator: false);
      expect(find.text('Server administration'), findsNothing);

      await pumpAdmin(tester, '/settings');
      expect(find.text('Server administration'), findsOneWidget);
    });

    testWidgets('Settings has one way in, and it is the dashboard',
        (tester) async {
      // The dashboard is the one list of administration screens. Shortcuts
      // to each of them here duplicated it, and drifted from it as soon as
      // a screen was added to one place and not the other.
      await pumpAdmin(tester, '/settings');

      expect(find.text('Users'), findsNothing);
      expect(find.text('Scheduled tasks'), findsNothing);
      expect(find.text('Activity log'), findsNothing);
      expect(find.text('Plugins'), findsNothing);

      await tester.ensureVisible(find.text('Server administration'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Server administration'));
      await tester.pumpAndSettle();
      expect(find.byType(AdminDashboardPage), findsOneWidget);
    });
  });

  group('the dashboard', () {
    testWidgets('lists who is connected and what they are watching',
        (tester) async {
      await pumpAdmin(tester, '/admin');

      expect(find.text('minh'), findsOneWidget);
      expect(find.text('Dune'), findsOneWidget);
      // An idle session says so rather than showing a blank line.
      expect(find.text('Connected, not playing'), findsOneWidget);
    });

    testWidgets('a session that cannot be controlled gets no buttons',
        (tester) async {
      await pumpAdmin(tester, '/admin');

      // One stop button and one message button, both on the controllable
      // session — not two of each.
      expect(find.byIcon(Icons.stop_circle_outlined), findsOneWidget);
      expect(find.byIcon(Icons.message_outlined), findsOneWidget);
    });

    testWidgets('stopping a session asks the server to', (tester) async {
      final admin = await pumpAdmin(tester, '/admin');

      await tester.tap(find.byIcon(Icons.stop_circle_outlined));
      await tester.pumpAndSettle();

      expect(admin!.calls, contains('stop:playing'));
    });

    testWidgets('a server that cannot restart offers neither button',
        (tester) async {
      // Absent, not disabled: a menu item that explains why it does nothing
      // is a menu item nobody wanted.
      await pumpAdmin(tester, '/admin', admin: FakeAdmin(canRestart: false));

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Scan all libraries'), findsOneWidget);
      expect(find.text('Restart server'), findsNothing);
      expect(find.text('Shut down server'), findsNothing);
    });

    testWidgets('shutting down asks first, and says what it costs',
        (tester) async {
      final admin = await pumpAdmin(tester, '/admin');

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Shut down server'));
      await tester.pumpAndSettle();

      // Nothing has happened yet — the dialog is the point.
      expect(admin!.calls, isEmpty);
      expect(find.textContaining('nothing here can start it again'),
          findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(admin.calls, isEmpty);
    });
  });

  group('tasks', () {
    testWidgets('a running task shows progress and offers Stop',
        (tester) async {
      await pumpAdmin(tester, '/admin/tasks');

      expect(find.text('Scan media library'), findsOneWidget);
      expect(find.text('62%'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Stop'), findsOneWidget);
      // The idle one offers Run instead.
      expect(find.widgetWithText(TextButton, 'Run now'), findsOneWidget);
    });

    testWidgets('running one asks the server to', (tester) async {
      final admin = await pumpAdmin(tester, '/admin/tasks');

      await tester.tap(find.widgetWithText(TextButton, 'Run now'));
      await tester.pumpAndSettle();

      expect(admin!.calls, contains('run:idle'));
    });
  });

  group('users and devices', () {
    testWidgets('an administrator and a disabled account read differently',
        (tester) async {
      await pumpAdmin(tester, '/admin/users');

      expect(find.text('minh'), findsOneWidget);
      expect(find.text('Administrator'), findsOneWidget);
      expect(find.text('guest'), findsOneWidget);
      // The disabled one offers to be enabled, and vice versa.
      expect(find.widgetWithText(TextButton, 'Enable'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Disable'), findsOneWidget);
    });

    testWidgets('the list is accounts only; devices live on each account',
        (tester) async {
      await pumpAdmin(tester, '/admin/users');

      expect(find.text('Living room TV'), findsNothing);
      expect(find.text('Devices'), findsNothing);
    });

    testWidgets('disabling an account sends the opposite of its current state',
        (tester) async {
      final admin = await pumpAdmin(tester, '/admin/users');

      await tester.tap(find.widgetWithText(TextButton, 'Disable'));
      await tester.pumpAndSettle();

      // u3: the administrator's row has no such button, because the server
      // refuses to disable an administrator.
      expect(admin!.calls, contains('disable:u3:true'));
    });

    testWidgets('an administrator offers no Disable button', (tester) async {
      await pumpAdmin(tester, '/admin/users');

      final minh = find.ancestor(
        of: find.text('minh'),
        matching: find.byType(ListTile),
      );
      expect(
        find.descendant(of: minh, matching: find.byType(TextButton)),
        findsNothing,
      );
    });

    testWidgets('Add user creates the account and opens it', (tester) async {
      final admin = await pumpAdmin(tester, '/admin/users');

      await tester.tap(find.text('Add user'));
      await tester.pumpAndSettle();

      // Create waits for a name.
      final create = find.widgetWithText(FilledButton, 'Create');
      expect(tester.widget<FilledButton>(create).onPressed, isNull);

      await tester.enterText(find.widgetWithText(TextField, 'Name'), 'anna');
      await tester.pumpAndSettle();
      await tester.tap(create);
      await tester.pumpAndSettle();

      expect(admin!.calls, contains('create:anna:'));
    });
  });

  group('the user editor', () {
    testWidgets('a row opens its account', (tester) async {
      await pumpAdmin(tester, '/admin/users');

      await tester.tap(find.text('kids'));
      await tester.pumpAndSettle();

      expect(find.text('Library access'), findsOneWidget);
      expect(find.textContaining('No password'), findsOneWidget);
    });

    testWidgets('nothing is saved until Save, and Save sends the draft',
        (tester) async {
      final admin = await pumpAdmin(tester, '/admin/users/u3');

      final save = find.widgetWithText(FilledButton, 'Save');
      expect(tester.widget<FilledButton>(save).onPressed, isNull);

      await tester.tap(find.text('All libraries'));
      await tester.pumpAndSettle();
      // The per-library list appears once "all" is off.
      await tester.tap(find.text('Films'));
      await tester.pumpAndSettle();

      expect(admin!.calls, isEmpty);

      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(admin.calls, contains('policy:u3'));
      final saved = admin.savedPolicies['u3']!;
      expect(saved.enableAllFolders, isFalse);
      expect(saved.enabledFolders, <String>['films']);
    });

    testWidgets('the parental limit is picked from the ratings the server has',
        (tester) async {
      final admin = await pumpAdmin(tester, '/admin/users/u3');

      await tester.scrollUntilVisible(
        find.text('Maximum allowed rating'),
        200,
        scrollable: _editorScrollable,
      );
      await tester.tap(find.text('Maximum allowed rating'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('PG-13 / TV-14'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(admin!.savedPolicies['u3']!.maxParentalRating, 13);
    });

    testWidgets('an administrator cannot be switched to disabled',
        (tester) async {
      await pumpAdmin(tester, '/admin/users/u1');

      final disabled = find.widgetWithText(SwitchListTile, 'Disabled');
      expect(tester.widget<SwitchListTile>(disabled).onChanged, isNull);
    });

    testWidgets('leaving with unsaved changes asks first', (tester) async {
      await pumpAdmin(tester, '/admin/users');
      await tester.tap(find.text('kids'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Allow downloads'),
        200,
        scrollable: _editorScrollable,
      );
      // Clear of the Save bar at the foot.
      await tester.drag(_editorScrollable, const Offset(0, -200));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Allow downloads'));
      await tester.pumpAndSettle();

      // Something to lose: Save is live.
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
            .onPressed,
        isNotNull,
      );

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Discard'));
      await tester.pumpAndSettle();
      expect(find.text('Library access'), findsNothing);
      expect(find.text('Add user'), findsOneWidget);
    });

    testWidgets('a password has to be typed the same twice', (tester) async {
      final admin = await pumpAdmin(tester, '/admin/users/u3');

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Set password'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextField, 'New password'), 'one');
      await tester.enterText(
          find.widgetWithText(TextField, 'Confirm password'), 'two');
      await tester.tap(find.widgetWithText(FilledButton, 'Save').last);
      await tester.pumpAndSettle();

      expect(find.text('The passwords do not match.'), findsOneWidget);
      expect(admin!.calls, isEmpty);

      await tester.enterText(
          find.widgetWithText(TextField, 'Confirm password'), 'one');
      await tester.tap(find.widgetWithText(FilledButton, 'Save').last);
      await tester.pumpAndSettle();

      expect(admin.calls, contains('password:u3:one'));
    });

    testWidgets('deleting asks, then leaves the screen', (tester) async {
      final admin = await pumpAdmin(tester, '/admin/users');
      await tester.tap(find.text('kids'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete user'));
      await tester.pumpAndSettle();

      expect(find.text('Delete kids?'), findsOneWidget);
      expect(admin!.calls, isEmpty);

      await tester.tap(find.widgetWithText(FilledButton, 'Delete user'));
      await tester.pumpAndSettle();

      expect(admin.calls, contains('delete:u3'));
      expect(find.text('Library access'), findsNothing);
    });
  });

  group('plugins', () {
    testWidgets('one that cannot be uninstalled shows no delete button',
        (tester) async {
      await pumpAdmin(tester, '/admin/plugins');

      expect(find.text('Intro Skipper'), findsOneWidget);
      expect(find.text('Bundled thing'), findsOneWidget);
      // Two plugins, one bundled: exactly one delete button.
      expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
      expect(find.byType(Switch), findsNWidgets(2));
    });

    testWidgets('uninstalling asks first', (tester) async {
      final admin = await pumpAdmin(tester, '/admin/plugins');

      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Uninstall Intro Skipper?'), findsOneWidget);
      expect(admin!.calls, isEmpty);

      await tester.tap(find.widgetWithText(FilledButton, 'Uninstall'));
      await tester.pumpAndSettle();
      expect(admin.calls, contains('uninstall:intro'));
    });
  });

  group('the activity log', () {
    testWidgets('an error is drawn differently from an ordinary line',
        (tester) async {
      await pumpAdmin(tester, '/admin/activity');

      expect(find.text('Entry 0'), findsOneWidget);
      expect(find.byIcon(Icons.info_outline_rounded), findsWidgets);
      expect(find.byIcon(Icons.error_outline_rounded), findsNothing);

      // The fake answers "problems only" with errors.
      await tester.tap(find.widgetWithText(FilterChip, 'Warnings and errors'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.error_outline_rounded), findsWidgets);
      expect(find.byIcon(Icons.info_outline_rounded), findsNothing);
    });
  });

  group('an account in three tabs', () {
    Future<void> openTab(WidgetTester tester, String label) async {
      await tester.tap(find.descendant(
        of: find.byType(TabBar),
        matching: find.text(label),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('Profile holds the editor and its Save', (tester) async {
      await pumpAdmin(tester, '/admin/users/u3');

      final tabs = find.byType(TabBar);
      for (final String label in <String>['Profile', 'Devices', 'Activity log']) {
        expect(
          find.descendant(of: tabs, matching: find.text(label)),
          findsOneWidget,
        );
      }
      expect(find.text('Library access'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Save'), findsOneWidget);
    });

    testWidgets('Devices lists the account own devices and forgets one',
        (tester) async {
      final admin = await pumpAdmin(tester, '/admin/users/u3');

      await openTab(tester, 'Devices');

      expect(find.text('Living room TV'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Save'), findsNothing);

      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pumpAndSettle();
      expect(admin!.calls, contains('forget:d1'));
    });

    testWidgets('Activity log shows only that account', (tester) async {
      await pumpAdmin(tester, '/admin/users/u3');

      await openTab(tester, 'Activity log');

      expect(find.text('kids is playing Bluey'), findsOneWidget);
      // Someone else's line is not in it, nor are the devices.
      expect(find.text('minh signed in'), findsNothing);
      expect(find.text('Living room TV'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Save'), findsNothing);
    });

    testWidgets('an account with nothing to show says so on each tab',
        (tester) async {
      await pumpAdmin(tester, '/admin/users/u1');

      await openTab(tester, 'Devices');
      expect(find.text('No devices have signed in.'), findsOneWidget);

      await openTab(tester, 'Activity log');
      expect(
        find.text('Nothing logged for this account recently.'),
        findsOneWidget,
      );
    });
  });

  group('libraries', () {
    testWidgets('the dashboard leads to them', (tester) async {
      await pumpAdmin(tester, '/admin');

      await tester.tap(find.text('Libraries'));
      await tester.pumpAndSettle();

      expect(find.text('Films'), findsOneWidget);
      expect(find.text('/media/films'), findsOneWidget);
    });

    testWidgets('scanning one asks the server for that library only',
        (tester) async {
      final admin = await pumpAdmin(tester, '/admin/libraries');

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Scan library'));
      await tester.pumpAndSettle();

      expect(admin!.calls, <String>['refresh:lib-films:scan']);
    });

    testWidgets('a refresh asks how deep to go', (tester) async {
      final admin = await pumpAdmin(tester, '/admin/libraries');

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Refresh metadata'));
      await tester.pumpAndSettle();
      expect(admin!.calls, isEmpty);

      await tester.tap(find.text('Replace all metadata'));
      await tester.pumpAndSettle();
      expect(admin.calls, <String>['refresh:lib-films:replaceAll']);
    });

    testWidgets('removing one asks first, and says the files stay',
        (tester) async {
      final admin = await pumpAdmin(tester, '/admin/libraries');

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove library'));
      await tester.pumpAndSettle();

      expect(find.text('Remove Films?'), findsOneWidget);
      expect(find.textContaining('not touched'), findsOneWidget);
      expect(admin!.calls, isEmpty);

      await tester.tap(find.widgetWithText(FilledButton, 'Remove library'));
      await tester.pumpAndSettle();
      expect(admin.calls, <String>['deleteLibrary:Films']);
    });

    testWidgets('renaming sends the old name and the new one', (tester) async {
      final admin = await pumpAdmin(tester, '/admin/libraries');

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rename library'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Movies');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(admin!.calls, <String>['renameLibrary:Films:Movies']);
    });
  });

  group('the metadata editor', () {
    testWidgets('opens on what the server holds, with nothing to save',
        (tester) async {
      await pumpAdmin(tester, '/admin/item/i1?title=Dune');

      expect(find.widgetWithText(TextField, 'Dune'), findsOneWidget);
      expect(find.widgetWithText(TextField, '2021'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Science Fiction'), findsOneWidget);
      final save = find.widgetWithText(FilledButton, 'Save');
      expect(tester.widget<FilledButton>(save).onPressed, isNull);
    });

    testWidgets('saves the fields typed, genres split on commas',
        (tester) async {
      final admin = await pumpAdmin(tester, '/admin/item/i1?title=Dune');

      await tester.enterText(
        find.widgetWithText(TextField, 'Dune'),
        'Dune: Part One',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Science Fiction'),
        'Science Fiction, Adventure,, adventure',
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(admin!.calls, <String>['metadata:i1']);
      final saved = admin.savedMetadata['i1']!;
      expect(saved.name, 'Dune: Part One');
      expect(saved.year, 2021);
      expect(saved.genres, <String>['Science Fiction', 'Adventure']);
    });

    testWidgets('a year that is not one cannot be saved', (tester) async {
      final admin = await pumpAdmin(tester, '/admin/item/i1?title=Dune');

      await tester.enterText(find.widgetWithText(TextField, '2021'), '20x1');
      await tester.pump();

      expect(find.text('Not a year.'), findsOneWidget);
      final save = find.widgetWithText(FilledButton, 'Save');
      expect(tester.widget<FilledButton>(save).onPressed, isNull);
      expect(admin!.calls, isEmpty);
    });
  });

  group('sessions in detail', () {
    testWidgets('a transcoding session says so, and why', (tester) async {
      await pumpAdmin(tester, '/admin');

      expect(find.text('Transcoding'), findsOneWidget);

      await tester.tap(find.text('Dune'));
      await tester.pumpAndSettle();

      expect(find.text('Why it is transcoding'), findsOneWidget);
      expect(
        find.text('The app cannot decode this video codec'),
        findsOneWidget,
      );
      // One the client has no wording for is still shown, readably.
      expect(find.text('Something New'), findsOneWidget);
      expect(find.text('8.4 Mbps'), findsOneWidget);
      expect(find.text('Software (no hardware acceleration)'), findsOneWidget);
    });
  });

  group('restart pending', () {
    testWidgets('a waiting restart is announced and offered', (tester) async {
      final admin = await pumpAdmin(
        tester,
        '/admin',
        admin: FakeAdmin(pendingRestart: true),
      );

      expect(find.text('Restart needed'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Restart'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Restart server'));
      await tester.pumpAndSettle();

      expect(admin!.calls, <String>['restart']);
    });

    testWidgets('no banner when nothing waits', (tester) async {
      await pumpAdmin(tester, '/admin');
      expect(find.text('Restart needed'), findsNothing);
    });

    testWidgets('a server that cannot restart gets the notice, no button',
        (tester) async {
      await pumpAdmin(
        tester,
        '/admin',
        admin: FakeAdmin(pendingRestart: true, canRestart: false),
      );
      expect(find.text('Restart needed'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Restart'), findsNothing);
    });
  });

  group('storage', () {
    testWidgets('folders show free space, and low space is flagged',
        (tester) async {
      await pumpAdmin(tester, '/admin/storage');

      expect(find.text('Transcodes'), findsOneWidget);
      expect(find.text('5.0 GB free · 20.0 GB used here'), findsOneWidget);
      expect(find.text('/media/films'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('an older server says it cannot report', (tester) async {
      await pumpAdmin(
        tester,
        '/admin/storage',
        admin: FakeAdmin(hasStorage: false),
      );
      expect(find.textContaining('10.10 or later'), findsOneWidget);
    });
  });

  group('logs', () {
    testWidgets('a file opens on its lines, and filters to problems',
        (tester) async {
      await pumpAdmin(tester, '/admin/logs');

      await tester.tap(find.text('log_20261110.log'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Server started'), findsOneWidget);
      expect(find.textContaining('Playback failed'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilterChip, 'Warnings and errors'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Server started'), findsNothing);
      expect(find.textContaining('Disk is getting full'), findsOneWidget);
      expect(find.textContaining('Playback failed'), findsOneWidget);
    });

    testWidgets('typing narrows the lines', (tester) async {
      await pumpAdmin(tester, '/admin/logs/view?name=log_20261110.log');

      await tester.enterText(find.byType(TextField), 'disk');
      await tester.pumpAndSettle();

      expect(find.textContaining('Disk is getting full'), findsOneWidget);
      expect(find.textContaining('Playback failed'), findsNothing);
    });
  });

  group('the activity log, a page at a time', () {
    testWidgets('Load more asks for the next page and stops at the end',
        (tester) async {
      final admin = await pumpAdmin(tester, '/admin/activity');
      expect(admin!.activityAsks, <String>['0:false:false']);

      for (var page = 1; page <= 2; page++) {
        await tester.scrollUntilVisible(
          find.text('Load more'),
          400,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('Load more'));
        await tester.pumpAndSettle();
      }

      expect(admin.activityAsks, <String>[
        '0:false:false',
        '50:false:false',
        '100:false:false',
      ]);
      // The third page was short: there is nothing more to load.
      expect(find.text('Load more'), findsNothing);
    });

    testWidgets('the filters start over with what they ask', (tester) async {
      final admin = await pumpAdmin(tester, '/admin/activity');

      await tester.tap(find.widgetWithText(FilterChip, 'Warnings and errors'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Last 24 hours'));
      await tester.pumpAndSettle();

      expect(admin!.activityAsks, <String>[
        '0:false:false',
        '0:true:false',
        '0:true:true',
      ]);
    });
  });

  group('API keys', () {
    testWidgets('a key is masked, never shown whole', (tester) async {
      await pumpAdmin(tester, '/admin/keys');

      expect(find.text('Sonarr'), findsOneWidget);
      expect(find.textContaining('abcd••••5678'), findsOneWidget);
      expect(find.textContaining('abcd1234efgh5678'), findsNothing);
    });

    testWidgets('a new key is made for a named app', (tester) async {
      final admin = await pumpAdmin(tester, '/admin/keys');

      await tester.tap(find.text('New key'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Home Assistant');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Create'));
      await tester.pumpAndSettle();

      expect(admin!.calls, <String>['createKey:Home Assistant']);
      expect(find.text('Home Assistant'), findsOneWidget);
    });

    testWidgets('revoking asks first', (tester) async {
      final admin = await pumpAdmin(tester, '/admin/keys');

      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Revoke the key for Sonarr?'), findsOneWidget);
      expect(admin!.calls, isEmpty);

      await tester.tap(find.widgetWithText(FilledButton, 'Revoke'));
      await tester.pumpAndSettle();
      expect(admin.calls, <String>['revokeKey:abcd1234efgh5678']);
    });
  });

  group('task triggers', () {
    testWidgets('each task says when it runs by itself', (tester) async {
      await pumpAdmin(tester, '/admin/tasks');

      expect(find.text('Daily at 03:00 · When the server starts'),
          findsOneWidget);
      expect(find.text('Only when run by hand'), findsOneWidget);
    });
  });

  group('adding a library', () {
    /// Walks the fake server disk down to /media/films (or only /media)
    /// and picks it.
    Future<void> pickFilms(WidgetTester tester, {bool deep = true}) async {
      await tester.tap(find.text('Add folder'));
      await tester.pumpAndSettle();
      expect(find.text('Choose a folder on the server'), findsOneWidget);

      // A drive list is not a folder: nothing to use yet.
      final use = find.byType(FilledButton);
      expect(tester.widget<FilledButton>(use).onPressed, isNull);

      await tester.tap(find.text('/'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('media'));
      await tester.pumpAndSettle();
      if (deep) {
        await tester.tap(find.text('films'));
        await tester.pumpAndSettle();
      }

      await tester.tap(find.text('Use this folder'));
      await tester.pumpAndSettle();
    }

    testWidgets('the FAB opens the form, and Create waits for a folder',
        (tester) async {
      await pumpAdmin(tester, '/admin/libraries');

      await tester.tap(find.text('Add library'));
      await tester.pumpAndSettle();

      // The name follows the kind until it is typed over.
      expect(find.widgetWithText(TextField, 'Movies'), findsOneWidget);
      final create = find.widgetWithText(FilledButton, 'Create');
      expect(tester.widget<FilledButton>(create).onPressed, isNull);
    });

    testWidgets('a folder picked on the server makes the library',
        (tester) async {
      final admin = await pumpAdmin(tester, '/admin/libraries/new');

      await tester.tap(find.text('Shows'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Shows'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Add folder'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await pickFilms(tester);
      expect(find.text('/media/films'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Create'));
      await tester.pumpAndSettle();

      expect(admin!.calls, <String>['addLibrary:Shows:tvshows:/media/films']);
      // Back on the list once it is made.
      expect(find.text('Add library'), findsOneWidget);
    });

    testWidgets('Up walks back towards the drives', (tester) async {
      await pumpAdmin(tester, '/admin/libraries/new');
      await tester.scrollUntilVisible(
        find.text('Add folder'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Add folder'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('/'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('media'));
      await tester.pumpAndSettle();
      expect(find.text('films'), findsOneWidget);

      await tester.tap(find.text('Up one level'));
      await tester.pumpAndSettle();
      expect(find.text('media'), findsOneWidget);
    });

    testWidgets('a typed path that does not exist fails in the picker',
        (tester) async {
      await pumpAdmin(tester, '/admin/libraries/new');
      await tester.scrollUntilVisible(
        find.text('Add folder'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Add folder'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '/nope');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.textContaining('does not exist'), findsOneWidget);
    });

    testWidgets('an existing library gains and loses folders',
        (tester) async {
      final admin = await pumpAdmin(tester, '/admin/libraries');

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Folders'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline_rounded).last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Remove folder'));
      await tester.pumpAndSettle();
      expect(admin!.calls, <String>['removePath:Films:/media/films']);

      // A folder the library already reads is not added twice; another is.
      await pickFilms(tester, deep: false);
      expect(admin.calls.last, 'addPath:Films:/media');
    });
  });
}
