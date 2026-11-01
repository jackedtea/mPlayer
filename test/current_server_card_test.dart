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
import 'package:mplayer/features/servers/servers_list_page.dart';
import 'package:mplayer/servers/media_library_source.dart';
import 'package:mplayer/servers/server_registry.dart';

/// Answers Quick Connect approvals with [answer], and keeps the codes.
class _QuickConnectServer extends FakeLibrarySource {
  _QuickConnectServer();

  QuickConnectApproval answer = QuickConnectApproval.approved;
  final List<String> codes = <String>[];

  @override
  Future<QuickConnectApproval> authorizeQuickConnect(String code) async {
    codes.add(code);
    return answer;
  }
}

final _server = _QuickConnectServer();

/// Signed in already, without the keychain the real registry reads.
class _SignedInRegistry extends ServerRegistry {
  @override
  ServerRegistryState build() => ServerRegistryState(
        profiles: const [fakeServerProfile],
        activeId: 'p1',
        source: _server,
        loading: false,
      );
}

Future<GoRouter> _pump(WidgetTester tester, Size size) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);

  final router = buildRouter();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [serverRegistryProvider.overrideWith(_SignedInRegistry.new)],
      child: MPlayerApp(router: router),
    ),
  );
  await tester.pumpAndSettle();
  router.go('/settings');
  await tester.pumpAndSettle();
  return router;
}

void main() {
  for (final Size size in const <Size>[Size(360, 800), Size(1400, 900)]) {
    testWidgets('names the server at the top at ${size.width.toInt()}px',
        (tester) async {
      await _pump(tester, size);

      expect(tester.takeException(), isNull);
      expect(find.text('Home'), findsWidgets);
      expect(find.text('media.home.lan'), findsOneWidget);
      expect(find.text('nam'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Edit server'), findsOneWidget);

      // Above the first section, which is the point of putting it there.
      expect(
        tester.getTopLeft(find.text('media.home.lan')).dy,
        lessThan(tester.getTopLeft(find.text('App settings')).dy),
      );
    });
  }

  testWidgets('switching goes back to the server list on Home',
      (tester) async {
    await _pump(tester, const Size(400, 900));

    await tester.tap(find.text('Switch server'));
    await tester.pumpAndSettle();

    expect(find.byType(ServersListPage), findsOneWidget);
  });

  testWidgets('edit opens the server sheet on this server', (tester) async {
    await _pump(tester, const Size(400, 900));

    await tester.tap(find.widgetWithText(OutlinedButton, 'Edit server'));
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(TextField, 'Server address'),
      findsOneWidget,
    );
    expect(find.text('https://media.home.lan'), findsOneWidget);
  });

  group('Quick Connect', () {
    setUp(() {
      _server.answer = QuickConnectApproval.approved;
      _server.codes.clear();
    });

    testWidgets('approving a code signs the other device in', (tester) async {
      await _pump(tester, const Size(400, 900));

      await tester.tap(find.text('Quick Connect'));
      await tester.pumpAndSettle();

      final approve = find.widgetWithText(FilledButton, 'Approve');
      // Six digits or nothing to send.
      await tester.enterText(find.byType(TextField), '12a34');
      await tester.pump();
      expect(tester.widget<FilledButton>(approve).onPressed, isNull);

      await tester.enterText(find.byType(TextField), '123456');
      await tester.pump();
      await tester.tap(approve);
      await tester.pumpAndSettle();

      expect(_server.codes, <String>['123456']);
      expect(find.text('Device signed in.'), findsOneWidget);
    });

    testWidgets('an unknown code says so and keeps the dialog open',
        (tester) async {
      _server.answer = QuickConnectApproval.unknownCode;
      await _pump(tester, const Size(400, 900));

      await tester.tap(find.text('Quick Connect'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '654321');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Approve'));
      await tester.pumpAndSettle();

      expect(find.textContaining('No device is waiting'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
    });
  });

  testWidgets('renaming without admin rights names it on this device only',
      (tester) async {
    await _pump(tester, const Size(360, 800));

    await tester.tap(find.widgetWithText(OutlinedButton, 'Rename server'));
    await tester.pumpAndSettle();

    // Said before Save, so the web app not changing is no surprise.
    expect(find.textContaining('Only on this device'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Living room');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Living room'), findsOneWidget);
  });
}
