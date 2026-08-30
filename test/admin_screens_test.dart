// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mplayer/app/app.dart';
import 'package:mplayer/app/router.dart';
import 'package:mplayer/features/admin/admin_providers.dart';
import 'package:mplayer/servers/server_admin.dart';

/// A server that answers every administration question.
class FakeAdmin implements ServerAdmin {
  FakeAdmin({this.canRestart = true});

  final bool canRestart;

  final List<String> calls = <String>[];

  @override
  Future<ServerSystemInfo> systemInfo() async => ServerSystemInfo(
        name: 'Home',
        version: '10.10.3',
        operatingSystem: 'Linux',
        architecture: 'X64',
        canRestart: canRestart,
        canShutdown: canRestart,
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
        const ScheduledTask(id: 'idle', name: 'Clean transcode directory'),
      ];

  @override
  Future<List<AdminUser>> users() async => <AdminUser>[
        const AdminUser(id: 'u1', name: 'minh', isAdministrator: true),
        const AdminUser(id: 'u2', name: 'guest', isDisabled: true),
      ];

  @override
  Future<List<AdminDevice>> devices() async => <AdminDevice>[
        const AdminDevice(
          id: 'd1',
          name: 'Living room TV',
          appName: 'Jellyfin Android TV',
          username: 'nam',
        ),
      ];

  @override
  Future<List<ActivityEntry>> activity({int limit = 50}) async =>
      <ActivityEntry>[
        const ActivityEntry(
          id: '1',
          name: 'minh signed in',
          severity: ActivitySeverity.information,
        ),
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

    testWidgets('devices are listed under the accounts', (tester) async {
      await pumpAdmin(tester, '/admin/users');

      expect(find.text('Living room TV'), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
    });

    testWidgets('disabling an account sends the opposite of its current state',
        (tester) async {
      final admin = await pumpAdmin(tester, '/admin/users');

      await tester.tap(find.widgetWithText(TextButton, 'Disable'));
      await tester.pumpAndSettle();

      expect(admin!.calls, contains('disable:u1:true'));
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

      expect(find.text('minh signed in'), findsOneWidget);
      expect(find.text('Playback failed'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
    });
  });
}
