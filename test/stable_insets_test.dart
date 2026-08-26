// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mplayer/features/player/stable_insets.dart';

/// The player runs in sticky immersion: the navigation bar slides in on a
/// swipe and slides out by itself, and Android reports the bottom inset going
/// to its full height and back each time. Anything laid out against that
/// inset moves with it — which is what threw the Skip intro pill up the
/// screen and dropped it back.
void main() {
  Widget harness(EdgeInsets padding, GlobalKey key) {
    return MediaQuery(
      data: MediaQueryData(padding: padding, viewPadding: padding),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: StableInsets(
          child: Builder(
            builder: (context) => SizedBox(key: key, height: 10),
          ),
        ),
      ),
    );
  }

  testWidgets('a bar that comes and goes does not move the controls',
      (tester) async {
    final key = GlobalKey();
    EdgeInsets seen(WidgetTester t) =>
        MediaQuery.of(key.currentContext!).padding;

    // Opened with the bars showing, which is how the player is reached.
    await tester.pumpWidget(harness(const EdgeInsets.only(bottom: 56), key));
    expect(seen(tester).bottom, 56);

    // Immersion hides them: Android reports no inset at all.
    await tester.pumpWidget(harness(EdgeInsets.zero, key));
    expect(
      seen(tester).bottom,
      56,
      reason: 'the space the bar occupies when shown has not changed, so '
          'neither may the layout',
    );

    // And back, without a second settle.
    await tester.pumpWidget(harness(const EdgeInsets.only(bottom: 56), key));
    expect(seen(tester).bottom, 56);
  });

  testWidgets('a taller bar is taken as the new truth', (tester) async {
    // Rotating, or a device that reports a larger inset in one orientation.
    final key = GlobalKey();
    await tester.pumpWidget(harness(const EdgeInsets.only(bottom: 24), key));
    await tester.pumpWidget(harness(const EdgeInsets.only(bottom: 56), key));

    expect(MediaQuery.of(key.currentContext!).padding.bottom, 56);
  });
}
