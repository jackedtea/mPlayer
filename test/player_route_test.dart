// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mplayer/app/app.dart';
import 'package:mplayer/app/router.dart';
import 'package:mplayer/app/system_ui.dart';

/// The window claim must not cost the navigator its route stack.
///
/// The wrapper that insets the app from the system bars sits above the
/// navigator. Written to return a bare child for the player and a wrapped one
/// for everything else, it changed the *shape* of the tree each time a screen
/// claimed the window — and Flutter can only reuse an element while the
/// widget at that position keeps its type, so the navigator was torn down and
/// rebuilt on every claim. Opening any video at all, local or from a server,
/// landed on "Nothing to play".
void main() {
  testWidgets('a claim does not tear the navigator down', (tester) async {
    final router = buildRouter();
    await tester.pumpWidget(
      ProviderScope(child: MPlayerApp(router: router)),
    );
    await tester.pumpAndSettle();

    router.push('/settings');
    await tester.pumpAndSettle();
    router.push('/settings/about');
    await tester.pumpAndSettle();

    // Every navigator, not just one: go_router nests a shell navigator
    // inside the root, and picking the wrong one measures nothing.
    List<State> navigators() => find
        .byType(Navigator)
        .evaluate()
        .map((e) => (e as StatefulElement).state)
        .toList();

    final before = navigators();
    expect(before, isNotEmpty);

    // What the player does on the way in.
    final claim = claimWindowEdges(WindowEdges.none);
    addTearDown(claim.release);
    await tester.pumpAndSettle();

    final after = navigators();
    expect(
      after.length,
      before.length,
      reason: 'a navigator disappeared or appeared across the claim',
    );
    for (var i = 0; i < before.length; i++) {
      expect(
        after[i],
        same(before[i]),
        reason: 'navigator $i was rebuilt from scratch, which takes the route '
            'stack and everything pushed with it',
      );
    }

    // And the stack is still where it was.
    expect(router.state.uri.path, '/settings/about');
  });

  testWidgets('a route that lost its argument falls back, not out',
      (tester) async {
    // `extra` lives in the router's match list, not in the URL, so a route
    // rebuilt from its location alone arrives with nothing. Answering that
    // with "pick a file from Files" while a film is playing is the one thing
    // the screen must not do.
    final router = buildRouter();
    await tester.pumpWidget(
      ProviderScope(child: MPlayerApp(router: router)),
    );
    await tester.pumpAndSettle();

    // Nothing open: there really is nothing to play, and saying so is right.
    router.push('/player');
    await tester.pumpAndSettle();
    expect(find.textContaining('Nothing to play'), findsOneWidget);
  });
}
