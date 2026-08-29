// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mplayer/features/player/stable_insets.dart';

/// The player must not move when the system bars do.
///
/// It runs in sticky immersion: the navigation bar slides in on a swipe and
/// slides out again by itself, and Android reports the inset going from its
/// full height to nothing and back each time. Every `SafeArea` under that
/// grows and shrinks with it, and everything laid out against one moves.
void main() {
  setUp(debugResetKnownSystemInsets);
  tearDown(debugResetKnownSystemInsets);

  Widget harness(GlobalKey key, {bool underASafeArea = false}) {
    final Widget child = StableInsets(
      child: Builder(builder: (context) => SizedBox(key: key, height: 10)),
    );

    return Directionality(
      textDirection: TextDirection.ltr,
      // What `_InsetFromSystemBars` puts above every screen but the player.
      child: underASafeArea ? SafeArea(top: false, child: child) : child,
    );
  }

  void setBars(WidgetTester tester, double bottom) {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(400, 900);
    tester.view.padding = FakeViewPadding(bottom: bottom);
    tester.view.viewPadding = FakeViewPadding(bottom: bottom);
  }

  testWidgets('a bar that comes and goes does not move the controls',
      (tester) async {
    final key = GlobalKey();
    addTearDown(tester.view.reset);

    // Opened with the bars showing, which is how the player is reached.
    setBars(tester, 56);
    await tester.pumpWidget(harness(key));
    expect(MediaQuery.of(key.currentContext!).padding.bottom, 56);

    // Immersion hides them: Android reports no inset at all.
    setBars(tester, 0);
    await tester.pumpWidget(harness(key));
    expect(
      MediaQuery.of(key.currentContext!).padding.bottom,
      56,
      reason: 'the space the bar occupies when shown has not changed, so '
          'neither may the layout',
    );

    // And back, without a second settle.
    setBars(tester, 56);
    await tester.pumpWidget(harness(key));
    expect(MediaQuery.of(key.currentContext!).padding.bottom, 56);
  });

  testWidgets('an ancestor that already ate the inset cannot hide it',
      (tester) async {
    // The one that made two rounds of fixes look like they had done nothing.
    // The player claims the whole window from `initState`, which is deferred
    // to after the frame — so on its *first* build the app-wide wrapper is
    // still insetting, its `SafeArea` has already consumed the bottom, and a
    // media query read here answers zero. Recording that zero as the truth
    // meant the real inset arrived a frame later and moved everything, and
    // every later toggle could move it again.
    final key = GlobalKey();
    addTearDown(tester.view.reset);

    setBars(tester, 56);
    await tester.pumpWidget(harness(key, underASafeArea: true));

    expect(
      MediaQuery.of(key.currentContext!).padding.bottom,
      56,
      reason: 'read from the view, which no ancestor widget can mask',
    );
  });

  testWidgets('a taller bar is taken as the new truth', (tester) async {
    final key = GlobalKey();
    addTearDown(tester.view.reset);

    setBars(tester, 24);
    await tester.pumpWidget(harness(key));
    setBars(tester, 56);
    await tester.pumpWidget(harness(key));

    expect(MediaQuery.of(key.currentContext!).padding.bottom, 56);
  });

  testWidgets('what the app saw before the player opened still counts',
      (tester) async {
    // A film opened after immersion has already begun reports no inset at
    // all. The bars have not changed size — the app measured them on every
    // screen before this one.
    final key = GlobalKey();
    addTearDown(tester.view.reset);

    recordSystemInsets(const EdgeInsets.only(bottom: 56));

    setBars(tester, 0);
    await tester.pumpWidget(harness(key));

    expect(MediaQuery.of(key.currentContext!).padding.bottom, 56);
  });
}
