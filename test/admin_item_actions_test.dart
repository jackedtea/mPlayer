// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'admin_screens_test.dart' show FakeAdmin;
import 'fake_library_source.dart';

import 'package:mplayer/app/app.dart';
import 'package:mplayer/app/router.dart';
import 'package:mplayer/features/admin/admin_providers.dart';
import 'package:mplayer/features/servers/server_library.dart';
import 'package:mplayer/servers/media_library_source.dart';

class _Movie extends FakeLibrarySource {
  const _Movie();

  @override
  Future<ServerItem> item(String itemId) async => const ServerItem(
        id: 'm1',
        title: 'Royal Tramp II',
        kind: ServerItemKind.movie,
        year: 1992,
      );
}

/// Opens the film's page from Home, so there is a screen to go back to.
Future<FakeAdmin> _open(WidgetTester tester, {required bool admin}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(1400, 900);
  addTearDown(tester.view.reset);

  final fake = FakeAdmin();
  final router = buildRouter();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        activeServerProvider.overrideWithValue(const _Movie()),
        serverAdminProvider.overrideWith((ref) async => admin ? fake : null),
        isAdministratorProvider.overrideWithValue(admin),
      ],
      child: MPlayerApp(router: router),
    ),
  );
  await tester.pumpAndSettle();
  router.push('/library/movie', extra: 'm1');
  await tester.pumpAndSettle();
  return fake;
}

Future<void> _openOverflow(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.more_vert_rounded).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a viewer is offered none of it', (tester) async {
    await _open(tester, admin: false);

    final overflow = find.byIcon(Icons.more_vert_rounded);
    if (overflow.evaluate().isNotEmpty) await _openOverflow(tester);

    expect(find.text('Refresh metadata'), findsNothing);
    expect(find.text('Edit metadata'), findsNothing);
    expect(find.text('Delete from server'), findsNothing);
  });

  testWidgets('an administrator finds all three in the overflow',
      (tester) async {
    await _open(tester, admin: true);
    await _openOverflow(tester);

    expect(find.text('Refresh metadata'), findsOneWidget);
    expect(find.text('Edit metadata'), findsOneWidget);
    expect(find.text('Delete from server'), findsOneWidget);
  });

  testWidgets('deleting asks, then leaves the page that showed it',
      (tester) async {
    final admin = await _open(tester, admin: true);
    await _openOverflow(tester);

    await tester.tap(find.text('Delete from server'));
    await tester.pumpAndSettle();

    expect(find.text('Delete Royal Tramp II?'), findsOneWidget);
    expect(admin.calls, isEmpty);

    await tester.tap(find.widgetWithText(FilledButton, 'Delete from server'));
    await tester.pumpAndSettle();

    expect(admin.calls, <String>['deleteItem:m1']);
    expect(find.text('Royal Tramp II'), findsNothing);
  });

  testWidgets('a refresh of the item goes to the item', (tester) async {
    final admin = await _open(tester, admin: true);
    await _openOverflow(tester);

    await tester.tap(find.text('Refresh metadata'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Search for missing metadata'));
    await tester.pumpAndSettle();

    expect(admin.calls, <String>['refresh:m1:missing']);
  });
}
