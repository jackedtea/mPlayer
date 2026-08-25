// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mplayer/app/app.dart';
import 'package:mplayer/app/theme.dart';
import 'package:mplayer/app/tokens.dart';
import 'package:mplayer/core/models/media_models.dart';
import 'package:mplayer/core/resume_repository.dart';
import 'package:mplayer/widgets/gradient_art.dart';

/// Smallest image the card can actually decode, for the still it draws.
const onePixelPng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAE'
    'hQGAhKmMIQAAAABJRU5ErkJggg==';

/// Seeds the Continue-watching shelf.
///
/// It is built from real resume points now, so a test that asserts about the
/// shelf has to put something in it — an empty shelf renders nothing at all,
/// which is the correct behaviour and would silently pass a geometry test.
void seedResumePoints(int count, {String? thumbnailPath}) {
  final now = DateTime(2026, 2, 10);
  SharedPreferences.setMockInitialValues(<String, Object>{
    'resume_points_v1': <String>[
      for (var i = 0; i < count; i++)
        jsonEncode(
          ResumePoint(
            sourceId: 'device',
            itemId: '/media/clip$i.mkv',
            title: 'Clip $i',
            kind: SourceKind.device,
            position: const Duration(minutes: 10),
            duration: const Duration(minutes: 100),
            updatedAt: now.subtract(Duration(minutes: i)),
            thumbnailPath: thumbnailPath,
          ).toJson(),
        ),
    ],
  });
}

/// Pumps the real app at a specific logical window size.
///
/// The design fixes behaviour at three widths, so every shell test states the
/// width it is asserting about rather than relying on the default 800x600.
Future<void> pumpAppAt(WidgetTester tester, Size size) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(const ProviderScope(child: MPlayerApp()));
  await tester.pumpAndSettle();
}

void main() {
  group('theme', () {
    test('light scheme matches the design tokens', () {
      final scheme = buildTheme(Brightness.light).colorScheme;

      expect(scheme.brightness, Brightness.light);
      expect(scheme.primary, const Color(0xFF00658F));
      expect(scheme.primaryContainer, const Color(0xFFC7E7FF));
      expect(scheme.surface, const Color(0xFFF6FAFE));
      expect(scheme.onSurfaceVariant, const Color(0xFF41484D));
      expect(scheme.outline, const Color(0xFF71787E));
    });

    test('dark scheme matches the design tokens', () {
      final scheme = buildTheme(Brightness.dark).colorScheme;

      expect(scheme.brightness, Brightness.dark);
      expect(scheme.primary, const Color(0xFF82CFFF));
      expect(scheme.primaryContainer, const Color(0xFF004C6D));
      expect(scheme.surface, const Color(0xFF0F1417));
      expect(scheme.surfaceContainer, const Color(0xFF1A2125));
    });

    test('both brightnesses carry the token extensions', () {
      for (final brightness in Brightness.values) {
        final theme = buildTheme(brightness);
        expect(theme.extension<AppSpacing>(), isNotNull);
        expect(theme.extension<AppRadii>(), isNotNull);
        expect(theme.extension<AppSemanticColors>(), isNotNull);
      }
    });
  });

  group('window size classes', () {
    test('boundaries follow the adaptive-layout table', () {
      expect(WindowSize.fromWidth(599), WindowSize.compact);
      expect(WindowSize.fromWidth(600), WindowSize.medium);
      expect(WindowSize.fromWidth(1239), WindowSize.medium);
      expect(WindowSize.fromWidth(1240), WindowSize.large);
    });

    test('screen padding is 16 except on desktop, where it is 24', () {
      const spacing = AppSpacing();
      expect(spacing.screenHorizontal(WindowSize.compact), 16);
      expect(spacing.screenHorizontal(WindowSize.medium), 16);
      expect(spacing.screenHorizontal(WindowSize.large), 24);
    });
  });

  group('adaptive shell', () {
    testWidgets('phone width uses a NavigationBar', (tester) async {
      await pumpAppAt(tester, const Size(400, 800));

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.byType(NavigationDrawer), findsNothing);
    });

    testWidgets('tablet width uses a NavigationRail', (tester) async {
      await pumpAppAt(tester, const Size(900, 1000));

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('desktop width uses a NavigationDrawer', (tester) async {
      await pumpAppAt(tester, const Size(1400, 900));

      expect(find.byType(NavigationDrawer), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(NavigationRail), findsNothing);
    });
  });

  group('startup', () {
    testWidgets('opens on Files with no server gate', (tester) async {
      seedResumePoints(2);
      await pumpAppAt(tester, const Size(400, 800));

      // The Files app bar title, not a login screen.
      expect(find.widgetWithText(AppBar, 'Files'), findsOneWidget);
      expect(find.text('Continue watching'), findsOneWidget);
      expect(find.text('This device'), findsOneWidget);
    });

    testWidgets('Server tab is an opt-in empty state, not a login wall', (
      tester,
    ) async {
      await pumpAppAt(tester, const Size(400, 800));

      await tester.tap(find.text('Servers'));
      await tester.pumpAndSettle();

      expect(find.text('No media server yet'), findsOneWidget);
      expect(find.text('Add Jellyfin server'), findsOneWidget);
      // Network scanning was dropped, so the button that promised it is gone
      // rather than left reporting that it does nothing.
      expect(find.text('Scan this network'), findsNothing);
    });

    testWidgets('add-server sheet asks for an address before anything else', (
      tester,
    ) async {
      await pumpAppAt(tester, const Size(400, 900));

      await tester.tap(find.text('Servers'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add Jellyfin server'));
      await tester.pumpAndSettle();

      // The heading is translated now, so it reads as the ARB spells it.
      expect(find.text('Add server'), findsOneWidget);
      expect(find.text('Enter an address to detect the server'), findsOneWidget);

      // Username and password are the path that always works, so they are
      // what the sheet opens on.
      expect(find.widgetWithText(TextField, 'Username'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Password'), findsOneWidget);

      // Quick Connect is *not* offered yet: nothing is known about the
      // server, and Emby answers 404 to every Quick Connect route while a
      // Jellyfin administrator can switch the feature off. Offering it before
      // asking would be a switch that sometimes cannot work.
      expect(find.byType(SwitchListTile), findsNothing);

      // Connect stays disabled until an address has been detected.
      final connect = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Connect'),
      );
      expect(connect.onPressed, isNull);
    });
  });

  group('clearing Continue watching', () {
    testWidgets('the action only appears when there is something to clear',
        (tester) async {
      // Reset explicitly: the preference mock is global, so a shelf seeded by
      // an earlier test would still be there.
      SharedPreferences.setMockInitialValues(<String, Object>{});

      // The whole section is absent on an empty shelf, and so is its button.
      await pumpAppAt(tester, const Size(400, 800));

      expect(find.text('Continue watching'), findsNothing);
      expect(find.widgetWithText(TextButton, 'Clear'), findsNothing);
    });

    testWidgets('clearing asks first, and says what it does not touch',
        (tester) async {
      seedResumePoints(2);
      await pumpAppAt(tester, const Size(400, 800));

      expect(find.text('Clip 0'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Clear'));
      await tester.pumpAndSettle();

      // "Clear" beside a shelf of films is easy to read as "delete the
      // films", so the dialog has to say what stays.
      expect(find.text('Clear Continue watching?'), findsOneWidget);
      expect(
        find.textContaining('Nothing is deleted from your shares'),
        findsOneWidget,
      );

      // Cancelling leaves the shelf alone.
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Clip 0'), findsOneWidget);
    });

    testWidgets('confirming empties the shelf', (tester) async {
      seedResumePoints(2);
      await pumpAppAt(tester, const Size(400, 800));

      await tester.tap(find.widgetWithText(TextButton, 'Clear'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Clear'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);

      // `path_provider` has no mock here, so the still-sweep's directory
      // lookup runs to its timeout rather than answering. That bound is the
      // point — before it existed, this hung for ever and the button looked
      // like it did nothing — so the test waits it out.
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();

      expect(find.text('Continue watching cleared'), findsOneWidget);
      expect(find.text('Clip 0'), findsNothing);
      // The section takes itself down with its last card.
      expect(find.text('Continue watching'), findsNothing);
    });
  });

  group('continue-watching shelf geometry', () {
    testWidgets('artwork lands on the 16pt margin and 12pt card gap', (
      tester,
    ) async {
      seedResumePoints(2);
      await pumpAppAt(tester, const Size(400, 800));

      // The ink ring around each card is drawn outside the artwork, so the
      // shelf has to compensate. Measure the artwork itself, not the card.
      final art = find.byType(GradientArt);
      expect(art, findsWidgets);

      final first = tester.getRect(art.first);
      expect(first.left, 16, reason: 'artwork must start at the screen margin');
      expect(first.width, 200);
      expect(first.height, 112);

      final second = tester.getRect(art.at(1));
      expect(
        second.left - first.right,
        12,
        reason: 'design fixes the card gap at 12',
      );
    });

    testWidgets('press highlight is inset from the artwork and caption', (
      tester,
    ) async {
      seedResumePoints(2);
      await pumpAppAt(tester, const Size(400, 800));

      final inkWell = find
          .ancestor(
            of: find.byType(GradientArt).first,
            matching: find.byType(InkWell),
          )
          .first;

      final inkRect = tester.getRect(inkWell);
      final artRect = tester.getRect(find.byType(GradientArt).first);

      expect(
        artRect.left - inkRect.left,
        greaterThan(0),
        reason: 'ink must not sit flush against the content',
      );
      expect(artRect.top - inkRect.top, artRect.left - inkRect.left);
    });

    testWidgets('a captured frame is drawn over the gradient', (tester) async {
      TestWidgetsFlutterBinding.ensureInitialized();

      // A real 1x1 PNG: the card decodes the file, so bytes that are not an
      // image would land in the error builder and pass for the wrong reason.
      final dir = Directory.systemTemp.createTempSync('mplayer_shelf');
      addTearDown(() => dir.deleteSync(recursive: true));
      final still = File(p.join(dir.path, 'frame.png'))
        ..writeAsBytesSync(base64Decode(onePixelPng));

      seedResumePoints(1, thumbnailPath: still.path);
      await pumpAppAt(tester, const Size(400, 800));

      final images = tester
          .widgetList<Image>(find.byType(Image))
          .map((i) => i.image)
          .whereType<ResizeImage>()
          .map((i) => i.imageProvider)
          .whereType<FileImage>()
          .toList();

      expect(
        images.map((i) => i.file.path),
        contains(still.path),
        reason: 'the shelf must draw the frame that was captured',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('an entry with no frame draws no image at all', (tester) async {
      seedResumePoints(1);
      await pumpAppAt(tester, const Size(400, 800));

      expect(
        tester
            .widgetList<Image>(find.byType(Image))
            .where((i) => i.image is ResizeImage || i.image is FileImage),
        isEmpty,
      );
      expect(find.byType(GradientArt), findsWidgets);
    });

    testWidgets('shelf grows with the text scale instead of overflowing', (
      tester,
    ) async {
      TestWidgetsFlutterBinding.ensureInitialized();
      seedResumePoints(2);
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(400, 800);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const ProviderScope(
          child: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: MPlayerApp(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // A RenderFlex overflow would have been recorded as an exception here.
      expect(tester.takeException(), isNull);
      expect(find.byType(GradientArt), findsWidgets);
    });
  });

  group('search scoping', () {
    testWidgets('offline sources are listed, unchecked and not selectable', (
      tester,
    ) async {
      await pumpAppAt(tester, const Size(400, 900));

      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();

      expect(find.text('Where to look'), findsOneWidget);

      // Nextcloud is offline in the sample data: shown, but skipped.
      final offlineTile = find.ancestor(
        of: find.text('Offline — will be skipped'),
        matching: find.byType(Checkbox),
      );
      expect(offlineTile, findsNothing);

      final checkboxes = tester
          .widgetList<Checkbox>(find.byType(Checkbox))
          .toList();
      expect(checkboxes.length, 4);
      expect(
        checkboxes.where((c) => c.onChanged == null).length,
        1,
        reason: 'the single offline source must be inert',
      );
      expect(checkboxes.where((c) => c.value == true).length, 3);
    });
  });
}
