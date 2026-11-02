// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:mplayer/app/mouse_navigation.dart';

GoRouter _router() {
  Widget page(String name) => Builder(
    builder: (context) => Scaffold(
      body: Center(
        child: Text('$name ${GoRouterState.of(context).extra ?? ''}'.trim()),
      ),
    ),
  );
  return GoRouter(
    routes: <RouteBase>[
      GoRoute(path: '/', builder: (_, _) => page('home')),
      GoRoute(path: '/a', builder: (_, _) => page('a')),
      GoRoute(path: '/b', builder: (_, _) => page('b')),
    ],
  );
}

Future<void> _press(WidgetTester tester, int button) async {
  final gesture = await tester.createGesture(
    kind: PointerDeviceKind.mouse,
    buttons: button,
  );
  await gesture.down(tester.getCenter(find.byType(Scaffold).last));
  await gesture.up();
  await tester.pumpAndSettle();
}

Future<GoRouter> _pump(WidgetTester tester) async {
  final router = _router();
  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: router,
      builder: (context, child) =>
          MouseNavigation(router: router, child: child!),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  testWidgets('back leaves the screen and forward returns to it, extra and '
      'all', (tester) async {
    final router = await _pump(tester);
    router.push('/a', extra: 'with-extra');
    await tester.pumpAndSettle();
    expect(find.text('a with-extra'), findsOneWidget);

    await _press(tester, kBackMouseButton);
    expect(find.text('home'), findsOneWidget);

    await _press(tester, kForwardMouseButton);
    expect(find.text('a with-extra'), findsOneWidget);

    // And back again: the replayed screen is an ordinary one.
    await _press(tester, kBackMouseButton);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('going somewhere else after back forgets what forward had', (
    tester,
  ) async {
    final router = await _pump(tester);
    router.push('/a');
    await tester.pumpAndSettle();
    await _press(tester, kBackMouseButton);

    router.push('/b');
    await tester.pumpAndSettle();
    await _press(tester, kForwardMouseButton);
    expect(find.text('b'), findsOneWidget);
  });

  testWidgets('back on the first screen does nothing', (tester) async {
    await _pump(tester);
    await _press(tester, kBackMouseButton);
    expect(find.text('home'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
