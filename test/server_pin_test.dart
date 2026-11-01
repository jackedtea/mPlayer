// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_library_source.dart';

import 'package:mplayer/app/app.dart';
import 'package:mplayer/features/home/home_page.dart';
import 'package:mplayer/features/servers/pin_lock.dart';
import 'package:mplayer/features/servers/servers_list_page.dart';
import 'package:mplayer/servers/server_pin.dart';
import 'package:mplayer/servers/server_profile.dart';
import 'package:mplayer/servers/server_registry.dart';

/// Signed in to one server, with the PIN held in memory rather than in a
/// keychain and checked by the real hash.
class _PinRegistry extends ServerRegistry {
  _PinRegistry({String? pin}) : _hash = pin == null ? null : hashPin(pin);

  String? _hash;
  final List<String?> set = <String?>[];

  @override
  ServerRegistryState build() => ServerRegistryState(
        profiles: <ServerProfile>[
          fakeServerProfile.copyWith(pinProtected: _hash != null),
        ],
        activeId: 'p1',
        source: const FakeLibrarySource(),
        loading: false,
      );

  @override
  Future<bool> verifyPinFor(String profileId, String pin) async =>
      _hash != null && verifyPin(pin, _hash!);

  @override
  Future<void> setPin(String profileId, String? pin) async {
    set.add(pin);
    _hash = pin == null ? null : hashPin(pin);
    state = state.copyWith(
      profiles: <ServerProfile>[
        state.profiles.single.copyWith(pinProtected: pin != null),
      ],
    );
  }
}

Future<void> _launch(WidgetTester tester, _PinRegistry registry) async {
  // Launches go straight into the last server, which is the case a PIN has
  // to stand in front of.
  SharedPreferences.setMockInitialValues(<String, Object>{});
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(400, 900);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [serverRegistryProvider.overrideWith(() => registry)],
      child: const MPlayerApp(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester, String pin) async {
  await tester.enterText(find.byType(PinField), pin);
  await tester.pump();
  await tester.tap(find.widgetWithText(FilledButton, 'Unlock'));
  await tester.pumpAndSettle();
}

void main() {
  group('the hash', () {
    test('opens with the PIN it was made from and nothing else', () {
      final stored = hashPin('2468');

      expect(verifyPin('2468', stored), isTrue);
      expect(verifyPin('2469', stored), isFalse);
      expect(verifyPin('24680', stored), isFalse);
      // The digits themselves are not in what is kept.
      expect(stored, isNot(contains('2468')));
    });

    test('is salted, so one PIN on two servers is stored two ways', () {
      expect(hashPin('2468'), isNot(hashPin('2468')));
    });

    test('anything unreadable locks rather than opens', () {
      expect(verifyPin('2468', ''), isFalse);
      expect(verifyPin('2468', 'v1:not base64:!!'), isFalse);
      expect(verifyPin('2468', 'v2:${hashPin('2468').substring(3)}'), isFalse);
    });

    test('a PIN is four to eight digits', () {
      expect(isValidPin('123'), isFalse);
      expect(isValidPin('1234'), isTrue);
      expect(isValidPin('12345678'), isTrue);
      expect(isValidPin('123456789'), isFalse);
      expect(isValidPin('12a4'), isFalse);
    });
  });

  group('a guarded server', () {
    testWidgets('asks for the PIN before anything of it is shown',
        (tester) async {
      await _launch(tester, _PinRegistry(pin: '2468'));

      expect(find.byType(PinLockPage), findsOneWidget);
      expect(find.byType(HomePage), findsNothing);
      // Nothing to tap around it: the other tabs would browse the server.
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('a wrong PIN says so; the right one opens it',
        (tester) async {
      await _launch(tester, _PinRegistry(pin: '2468'));

      await _enter(tester, '1111');
      expect(find.text('That PIN is not right.'), findsOneWidget);
      expect(find.byType(PinLockPage), findsOneWidget);

      await _enter(tester, '2468');
      expect(find.byType(HomePage), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('five wrong tries pause the lock', (tester) async {
      await _launch(tester, _PinRegistry(pin: '2468'));

      for (var i = 0; i < 5; i++) {
        await _enter(tester, '0000');
      }
      expect(find.textContaining('Too many wrong tries'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).enabled,
        isFalse,
      );

      await tester.pump(const Duration(seconds: 31));
      expect(
        tester.widget<TextField>(find.byType(TextField)).enabled,
        isTrue,
      );
    });

    testWidgets('switching server goes back to the list, locked again',
        (tester) async {
      await _launch(tester, _PinRegistry(pin: '2468'));

      await tester.tap(find.text('Switch server'));
      await tester.pumpAndSettle();
      expect(find.byType(ServersListPage), findsOneWidget);
      // The lock shows before the tap.
      expect(find.byIcon(Icons.lock_rounded), findsOneWidget);

      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      expect(find.byType(PinLockPage), findsOneWidget);
    });
  });

  group('Settings', () {
    Future<void> openSettings(WidgetTester tester) async {
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
    }

    testWidgets('sets a PIN, asked for twice', (tester) async {
      final registry = _PinRegistry();
      await _launch(tester, registry);
      await openSettings(tester);

      await tester.tap(find.text('PIN lock'));
      await tester.pumpAndSettle();

      final fields = find.byType(PinField);
      await tester.enterText(fields.at(0), '1357');
      await tester.enterText(fields.at(1), '1350');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(find.text('The two PINs are not the same.'), findsOneWidget);
      expect(registry.set, isEmpty);

      await tester.enterText(fields.at(1), '1357');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(registry.set, <String?>['1357']);
      // Setting it does not lock the person who just set it out.
      expect(find.byType(PinLockPage), findsNothing);
      expect(find.textContaining('On — asked'), findsOneWidget);
    });

    testWidgets('turning it off needs the current PIN', (tester) async {
      final registry = _PinRegistry(pin: '2468');
      await _launch(tester, registry);
      await _enter(tester, '2468');
      await openSettings(tester);

      await tester.tap(find.text('PIN lock'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Turn off PIN'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(PinField), '9999');
      await tester.tap(find.widgetWithText(FilledButton, 'Unlock'));
      await tester.pumpAndSettle();
      expect(find.text('That PIN is not right.'), findsOneWidget);
      expect(registry.set, isEmpty);

      await tester.enterText(find.byType(PinField), '2468');
      await tester.tap(find.widgetWithText(FilledButton, 'Unlock'));
      await tester.pumpAndSettle();

      expect(registry.set, <String?>[null]);
      expect(find.textContaining('Off — anyone'), findsOneWidget);
    });
  });
}
