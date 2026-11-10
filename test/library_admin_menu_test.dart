// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'admin_screens_test.dart' show FakeAdmin;
import 'fake_library_source.dart';

import 'package:mplayer/app/app.dart';
import 'package:mplayer/app/router.dart';
import 'package:mplayer/features/admin/admin_item_page.dart';
import 'package:mplayer/features/admin/admin_providers.dart';
import 'package:mplayer/features/servers/server_library.dart';
import 'package:mplayer/servers/media_library_source.dart';

class _Films extends FakeLibrarySource {
  const _Films();

  @override
  Future<List<LibraryView>> views() async => const <LibraryView>[
        LibraryView(id: 'films', name: 'Films', kind: 'movies'),
      ];
}

Future<FakeAdmin> _open(WidgetTester tester, {required bool admin}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(900, 1000);
  addTearDown(tester.view.reset);

  final fake = FakeAdmin();
  final router = buildRouter();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        activeServerProvider.overrideWithValue(const _Films()),
        serverAdminProvider.overrideWith((ref) async => admin ? fake : null),
        isAdministratorProvider.overrideWithValue(admin),
      ],
      child: MPlayerApp(router: router),
    ),
  );
  await tester.pumpAndSettle();
  router.go('/libraries');
  await tester.pumpAndSettle();
  return fake;
}

/// The ⋮ in the library's own app bar, not one inside the grid.
Finder get _menu => find.descendant(
      of: find.byType(AppBar),
      matching: find.byIcon(Icons.more_vert_rounded),
    );

void main() {
  testWidgets('a viewer gets no menu', (tester) async {
    await _open(tester, admin: false);
    expect(_menu, findsNothing);
  });

  testWidgets('an administrator gets scan, refresh and edit', (tester) async {
    await _open(tester, admin: true);

    await tester.tap(_menu);
    await tester.pumpAndSettle();

    expect(find.text('Scan library'), findsOneWidget);
    expect(find.text('Refresh metadata'), findsOneWidget);
    expect(find.text('Edit metadata'), findsOneWidget);
  });

  testWidgets('scan goes to this library', (tester) async {
    final admin = await _open(tester, admin: true);

    await tester.tap(_menu);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Scan library'));
    await tester.pumpAndSettle();

    expect(admin.calls, <String>['refresh:films:scan']);
  });

  testWidgets('refresh asks how deep, like the web client', (tester) async {
    final admin = await _open(tester, admin: true);

    await tester.tap(_menu);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Refresh metadata'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Search for missing metadata'));
    await tester.pumpAndSettle();

    expect(admin.calls, <String>['refresh:films:missing']);
  });

  testWidgets('edit opens the metadata editor on the library',
      (tester) async {
    await _open(tester, admin: true);

    await tester.tap(_menu);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit metadata'));
    await tester.pumpAndSettle();

    final page = tester.widget<AdminItemPage>(find.byType(AdminItemPage));
    expect(page.itemId, 'films');
  });
}
