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

  /// The band at the bottom of the window the navigation bar covers.
  Rect navigationBarBand(WidgetTester tester) {
    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    return Rect.fromLTRB(
      0,
      size.height - _navigationBar,
      size.width,
      size.height,
    );
  }

  group('content clears the system bars', () {
    for (final String route in <String>[
      '/files',
      '/servers',
      '/search',
      '/settings',
      '/settings/appearance',
      '/settings/player',
      '/library',
      '/servers/home',
      '/downloads',
      '/settings/about',
      '/settings/diagnostics',
      '/settings/subtitle',
      '/settings/audio',
      '/settings/general',
      '/settings/privacy',
    ]) {
      testWidgets('$route keeps its scrollables out from under them',
          (tester) async {
        final router = await pumpWithBars(tester);
        router.go(route);
        await tester.pumpAndSettle();

        final band = navigationBarBand(tester);

        // Checked against the widget's own padding rather than by dragging
        // to the end: `BoxScrollView` insets itself against the system bars
        // only while `padding` is null, so a list that passes one has to
        // include the inset itself or its last row is unreachable.
        for (final Element element in find.byType(Scrollable).evaluate()) {
          final scrollable = element.widget as Scrollable;
          if (scrollable.axis != Axis.vertical) continue;

          final box = element.renderObject! as RenderBox;
          final bottom = box.localToGlobal(Offset.zero).dy + box.size.height;

          // Only lists that actually reach into the band have anything to
          // prove; a shelf halfway up the screen does not.
          if (bottom <= band.top) continue;

          final owner = find.ancestor(
            of: find.byWidget(scrollable),
            matching: find.byType(BoxScrollView),
          );
          if (owner.evaluate().isEmpty) continue;

          final list = tester.widget<BoxScrollView>(owner.first);
          final padding = list.padding?.resolve(TextDirection.ltr);

          expect(
            padding == null || padding.bottom >= _navigationBar,
            isTrue,
            reason:
                '$route: a list reaching the navigation bar passes '
                'padding ${padding?.bottom ?? "null"}, which does not clear '
                'the ${_navigationBar.toInt()}pt inset',
          );
        }
      });
    }

    testWidgets('the shell grows its navigation bar to fit the system one',
        (tester) async {
      await pumpWithBars(tester);

      // Material's own `NavigationBar` wraps its children in a `SafeArea`, so
      // it should stand taller than its nominal 80 by exactly the inset. If
      // that ever stops being true, every destination label sits on top of
      // the gesture bar.
      final bar = tester.getRect(find.byType(NavigationBar));
      final size = tester.view.physicalSize / tester.view.devicePixelRatio;

      expect(bar.bottom, size.height);
      expect(
        bar.height,
        greaterThanOrEqualTo(80 + _navigationBar),
        reason: 'the bar has to include the system inset, not sit under it',
      );
    });

    testWidgets('an app bar sits below the status bar, not behind it',
        (tester) async {
      final router = await pumpWithBars(tester);
      router.go('/settings');
      await tester.pumpAndSettle();

      // `AppBar` consumes the top inset itself. This is the one the app never
      // had to do by hand, and the test is here so it stays that way.
      final appBar = tester.getRect(find.byType(AppBar).first);
      expect(appBar.top, 0, reason: 'the bar is drawn behind the status bar');
      expect(
        appBar.height,
        greaterThanOrEqualTo(kToolbarHeight + _statusBar),
        reason: 'its content is pushed below the status bar by its own height',
      );
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
