// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mplayer/servers/auto_connect.dart';
import 'package:mplayer/servers/server_registry.dart';

import 'fake_library_source.dart';

/// A registry that has already signed the last profile back in, without the
/// keychain and preferences the real one reads.
class _SignedInRegistry extends ServerRegistry {
  @override
  ServerRegistryState build() => const ServerRegistryState(
        profiles: [fakeServerProfile],
        activeId: 'p1',
        source: FakeLibrarySource(),
        loading: false,
      );
}

ProviderContainer _launch() {
  final container = ProviderContainer(
    overrides: [serverRegistryProvider.overrideWith(_SignedInRegistry.new)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('opening the last server is on by default', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(autoConnectProvider);
    await container.read(autoConnectProvider.notifier).ready;
    expect(container.read(autoConnectProvider), isTrue);
  });

  test('a stored "off" is read back before anything decides', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'auto_connect_last_server': false,
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(autoConnectProvider);
    await container.read(autoConnectProvider.notifier).ready;
    expect(container.read(autoConnectProvider), isFalse);
  });

  test('turning it off persists', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(autoConnectProvider.notifier).setEnabled(false);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('auto_connect_last_server'), isFalse);
  });

  group('a launch', () {
    test('goes into the last server when the option is on', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final container = _launch();

      container.read(serverSessionProvider);
      await container.read(autoConnectProvider.notifier).ready;
      await Future<void>.delayed(Duration.zero);

      expect(container.read(serverSessionProvider), isTrue);
    });

    test('stops at the server list when it is off', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'auto_connect_last_server': false,
      });
      final container = _launch();

      container.read(serverSessionProvider);
      await container.read(autoConnectProvider.notifier).ready;
      await Future<void>.delayed(Duration.zero);

      expect(container.read(serverSessionProvider), isFalse);

      // A tap on the list is what goes in, and "Switch server" comes back.
      container.read(serverSessionProvider.notifier).enter();
      expect(container.read(serverSessionProvider), isTrue);
      container.read(serverSessionProvider.notifier).leave();
      expect(container.read(serverSessionProvider), isFalse);
    });
  });
}
