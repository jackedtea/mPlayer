// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:mplayer/app/app.dart';
import 'package:mplayer/app/router.dart';
import 'package:mplayer/app/system_ui.dart';

/// Every screen has to keep its content clear of the system bars.
///
/// Android 15 draws every app edge to edge whether it asks to or not, so the
/// bars sit *over* the app and each screen has to inset itself. The catch is
/// that a scroll view insets itself against them **only while its own
/// `padding` is null** — passing any padding silently turns that off, and
/// every list here passes one.
///
/// The default test view has no padding at all, so the whole suite ran green
/// while the app on a real phone had its last settings row under the
/// navigation bar. These tests state the insets a phone actually has.
const _statusBar = 48.0;
const _navigationBar = 56.0;

void main() {
  // `/browse` is left out: it needs the directory-listing stub that
  // `screens_test.dart` installs, and its inset behaviour is a list like any
  // other here.

  Future<GoRouter> pumpWithBars(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(400, 900);
    tester.view.padding = const FakeViewPadding(
      top: _statusBar,
      bottom: _navigationBar,
    );
    tester.view.viewPadding = const FakeViewPadding(
      top: _statusBar,
      bottom: _navigationBar,
    );
    addTearDown(tester.view.reset);

    final router = buildRouter();
    await tester.pumpWidget(ProviderScope(child: MPlayerApp(router: router)));
    await tester.pumpAndSettle();
    return router;
  }

  group('the app sits between the system bars', () {
    /// The topmost and bottommost pixel anything paints on.
    (double, double) contentBounds(WidgetTester tester) {
      var top = double.infinity;
      var bottom = double.negativeInfinity;

      for (final Element element in find.byType(Scaffold).evaluate()) {
        final box = element.renderObject as RenderBox?;
        if (box == null || !box.hasSize) continue;
        final y = box.localToGlobal(Offset.zero).dy;
        top = y < top ? y : top;
        bottom = y + box.size.height > bottom ? y + box.size.height : bottom;
      }
      return (top, bottom);
    }

    for (final String route in <String>[
      '/files',
      '/servers',
      '/search',
      '/settings',
      '/library',
      '/servers/home',
      '/downloads',
    ]) {
      testWidgets('$route is inset from both bars', (tester) async {
        final router = await pumpWithBars(tester);
        router.go(route);
        await tester.pumpAndSettle();

        final size = tester.view.physicalSize / tester.view.devicePixelRatio;
        final (top, bottom) = contentBounds(tester);

        // The complaint this exists for, in a screenshot: a series backdrop
        // running to the very top with the clock and the signal bars drawn
        // over it, and an episode row disappearing behind the navigation
        // buttons. Each screen's own padding kept its *text* clear, which is
        // why measuring text found nothing — the artwork and the surface
        // still ran underneath.
        expect(
          top,
          greaterThanOrEqualTo(_statusBar),
          reason: '$route paints into the status bar',
        );
        expect(
          bottom,
          lessThanOrEqualTo(size.height - _navigationBar),
          reason: '$route paints into the navigation bar',
        );
      });
    }

    testWidgets('an app bar starts below the status bar', (tester) async {
      final router = await pumpWithBars(tester);
      router.go('/settings');
      await tester.pumpAndSettle();

      // It used to sit at y=0 and grow by the inset instead, drawing its own
      // colour behind the status bar. Inset from above, it begins where the
      // status bar ends and stands at its nominal height.
      final appBar = tester.getRect(find.byType(AppBar).first);
      expect(appBar.top, _statusBar);
      expect(appBar.height, kToolbarHeight);
    });

    testWidgets('the shell keeps its navigation bar above the system one',
        (tester) async {
      await pumpWithBars(tester);

      final bar = tester.getRect(find.byType(NavigationBar));
      final size = tester.view.physicalSize / tester.view.devicePixelRatio;

      expect(bar.bottom, size.height - _navigationBar);
    });

    testWidgets('the player still gets the whole window', (tester) async {
      // The one exception, and the reason this is a notifier rather than a
      // rule: letterboxing a film to leave room for a navigation bar throws
      // away the part of the screen the user came for.
      final router = await pumpWithBars(tester);
      router.go('/settings');
      await tester.pumpAndSettle();

      expect(contentBounds(tester).$1, _statusBar);

      fullBleedUi.value = true;
      addTearDown(() => fullBleedUi.value = false);
      await tester.pumpAndSettle();

      expect(contentBounds(tester).$1, 0);
    });
  });

  group('leaving the player', () {
    late List<String> modes;
    late List<Object?> overlays;

    setUp(() {
      modes = <String>[];
      overlays = <Object?>[];
      // The suite runs on the desktop VM, where these calls are correctly a
      // no-op. Say otherwise for the duration.
      debugSystemUiApplies = () => true;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        switch (call.method) {
          case 'SystemChrome.setEnabledSystemUIMode':
            modes.add(call.arguments as String);
          case 'SystemChrome.setEnabledSystemUIOverlays':
            overlays.add(call.arguments);
        }
        return null;
      });
    });

    tearDown(() {
      debugSystemUiApplies = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    testWidgets('the bars are shown again, not merely laid out again',
        (tester) async {
      // The bug this exists for: asking for `edgeToEdge` on the way out looks
      // like the mirror image of asking for `immersiveSticky` on the way in,
      // and it is not. Those two go through
      // `SystemChrome.setEnabledSystemUIMode`, which sets *layout* behaviour.
      // Visibility is a different platform method entirely —
      // `setEnabledSystemUIOverlays`, reached only through
      // `SystemUiMode.manual`. Restoring without it left the app back on its
      // own screens with sticky immersion still in force: the navigation bar
      // kept sliding away by itself, and while it was briefly out it was
      // drawn over the app rather than beside it.
      await enterImmersiveUi();
      await tester.pump();

      expect(modes.single, contains('immersiveSticky'));

      modes.clear();
      await restoreAppSystemUi();
      await tester.pump();

      expect(
        overlays,
        isNotEmpty,
        reason: 'the bars have to be told to show, not just to lay out',
      );
      expect(modes, contains(contains('edgeToEdge')));
    });

    testWidgets('restoring is free when nothing hid anything', (tester) async {
      // The shell calls this on every build so that returning from a player
      // whose teardown went wrong still fixes the bars. That is only
      // affordable if it costs nothing the rest of the time.
      await restoreAppSystemUi();
      await tester.pump();

      expect(modes, isEmpty);
      expect(overlays, isEmpty);
    });
  });
}
