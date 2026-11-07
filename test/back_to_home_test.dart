// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_library_source.dart';

import 'package:mplayer/app/app.dart';
import 'package:mplayer/app/router.dart';
import 'package:mplayer/features/servers/server_library.dart';
import 'package:mplayer/servers/media_library_source.dart';

class _Server extends FakeLibrarySource {
  const _Server();

  @override
  Future<List<LibraryView>> views() async => const <LibraryView>[
    LibraryView(id: 'v1', name: 'Films', kind: 'movies'),
  ];
}

Future<GoRouter> _pump(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(400, 800);
  addTearDown(tester.view.reset);

  final router = buildRouter();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [activeServerProvider.overrideWithValue(const _Server())],
      child: MPlayerApp(router: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

Future<void> _tapTab(WidgetTester tester, IconData icon) async {
  await tester.tap(
    find.descendant(of: find.byType(NavigationBar), matching: find.byIcon(icon)),
  );
  await tester.pumpAndSettle();
}

/// Presses the system back button; true when the app handled it, false when
/// the press would have gone on to close the app.
Future<bool> _systemBack(WidgetTester tester, GoRouter router) async {
  final handled = await router.routerDelegate.popRoute();
  await tester.pumpAndSettle();
  return handled;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('back from Libraries goes Home instead of leaving', (
    tester,
  ) async {
    final router = await _pump(tester);
    await _tapTab(tester, Icons.video_library_outlined);
    expect(router.state.uri.path, '/libraries');

    expect(await _systemBack(tester, router), isTrue);
    expect(router.state.uri.path, '/home');
  });

  testWidgets('back on Home still leaves', (tester) async {
    final router = await _pump(tester);
    expect(await _systemBack(tester, router), isFalse);
    expect(router.state.uri.path, '/home');
  });

  testWidgets('back inside a tab walks out of it before going Home', (
    tester,
  ) async {
    final router = await _pump(tester);
    await _tapTab(tester, Icons.settings_outlined);
    router.push('/settings/general');
    await tester.pumpAndSettle();

    expect(await _systemBack(tester, router), isTrue);
    expect(router.state.uri.path, '/settings');

    expect(await _systemBack(tester, router), isTrue);
    expect(router.state.uri.path, '/home');
  });

  testWidgets('predictive back keeps the press with Flutter off Home', (
    tester,
  ) async {
    // The last thing the framework told the platform, which on Android 16 is
    // what decides whether a press reaches Flutter at all.
    bool? frameworkHandlesBack;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemNavigator.setFrameworkHandlesBack') {
          frameworkHandlesBack = call.arguments as bool;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    final previous = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = previous);

    // A window that is not up yet tells the platform nothing.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

    final router = await _pump(tester);
    await _tapTab(tester, Icons.video_library_outlined);
    expect(frameworkHandlesBack, isTrue);

    await _systemBack(tester, router);
    expect(router.state.uri.path, '/home');
    expect(frameworkHandlesBack, isFalse);

    debugDefaultTargetPlatformOverride = previous;
  });

  testWidgets('the mouse goes back to Home and forward to the tab again', (
    tester,
  ) async {
    final router = await _pump(tester);
    await _tapTab(tester, Icons.video_library_outlined);

    Future<void> press(int button) async {
      final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
        buttons: button,
      );
      await gesture.down(const Offset(200, 300));
      await gesture.up();
      await tester.pumpAndSettle();
    }

    await press(kBackMouseButton);
    expect(router.state.uri.path, '/home');

    await press(kForwardMouseButton);
    expect(router.state.uri.path, '/libraries');
    expect(find.byType(NavigationBar), findsOneWidget);

    await press(kBackMouseButton);
    expect(router.state.uri.path, '/home');
    expect(tester.takeException(), isNull);
  });
}
