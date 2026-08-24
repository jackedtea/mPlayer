// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mplayer/servers/jellyfin_source.dart';
import 'package:mplayer/servers/server_profile.dart';
import 'package:mplayer/servers/server_registry.dart';

import 'fake_keychain.dart';

const _info = ServerInfo(
  uri: 'https://media.home.lan',
  name: 'Home',
  version: '10.9',
  serverId: 'srv1',
  kind: ServerKind.jellyfin,
);

const _auth = AuthResult(
  token: 'tok123',
  userId: 'u9',
  username: 'nam',
  serverId: 'srv1',
);

/// A container whose registry reads the mocked preferences and keychain.
ProviderContainer containerWith(ServerRepository repository) {
  final container = ProviderContainer(
    overrides: [serverRepositoryProvider.overrideWithValue(repository)],
  );
  addTearDown(container.dispose);
  return container;
}

Future<ServerRegistry> registryOf(ProviderContainer container) async {
  container.read(serverRegistryProvider);
  // The registry loads behind the first frame, the way the app does.
  await Future<void>.delayed(Duration.zero);
  return container.read(serverRegistryProvider.notifier);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, String> keychain;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    keychain = installFakeKeychain();
  });

  group('storage split', () {
    test('the token goes to the keychain and never to preferences', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = containerWith(ServerRepository(prefs: prefs));
      final registry = await registryOf(container);

      final profile = await registry.add(info: _info, auth: _auth);

      // The one rule this whole class exists to keep.
      expect(keychain[profile.credentialKey], 'tok123');

      final stored = prefs.getStringList('configured_servers_v1')!;
      expect(stored, hasLength(1));
      expect(stored.single, isNot(contains('tok123')));

      final json = jsonDecode(stored.single) as Map<String, dynamic>;
      expect(json['uri'], 'https://media.home.lan');
      expect(json['userId'], 'u9');
      expect(json.containsKey('token'), isFalse);
    });

    test('a signed-in server survives a restart', () async {
      final prefs = await SharedPreferences.getInstance();
      final first = containerWith(ServerRepository(prefs: prefs));
      await (await registryOf(first)).add(info: _info, auth: _auth);

      // A second container stands in for the next launch.
      final restarted = containerWith(ServerRepository(prefs: prefs));
      await registryOf(restarted);
      await Future<void>.delayed(Duration.zero);

      final state = restarted.read(serverRegistryProvider);
      expect(state.profiles, hasLength(1));
      expect(state.active?.name, 'Home');
      // A profile whose token is still in the keychain comes back signed in.
      expect(state.source, isNotNull);
      expect(state.signedOutId, isNull);
    });

    test('a profile whose token is gone asks for a password, not an error',
        () async {
      final prefs = await SharedPreferences.getInstance();
      final container = containerWith(ServerRepository(prefs: prefs));
      final registry = await registryOf(container);
      final profile = await registry.add(info: _info, auth: _auth);

      // What a cleared keychain looks like: the profile is still there.
      keychain.remove(profile.credentialKey);
      await registry.activate(profile.id);

      final state = container.read(serverRegistryProvider);
      expect(state.signedOutId, profile.id);
      expect(state.source, isNull);
      expect(state.profiles, hasLength(1));
    });

    test('one unreadable profile does not hide the rest', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'configured_servers_v1': <String>[
          'not json at all',
          jsonEncode(<String, dynamic>{
            'id': 'p2',
            'kind': 'jellyfin',
            'name': 'Good',
            'uri': 'https://ok.lan',
            'userId': 'u',
            'username': 'nam',
          }),
        ],
      });

      final prefs = await SharedPreferences.getInstance();
      final profiles = await ServerRepository(prefs: prefs).loadProfiles();

      expect(profiles, hasLength(1));
      expect(profiles.single.name, 'Good');
    });
  });

  group('device id', () {
    test('is generated once and kept', () async {
      // Jellyfin files sessions and tokens under it, so a new one per launch
      // orphans the token that was issued to the last.
      final prefs = await SharedPreferences.getInstance();
      final repository = ServerRepository(prefs: prefs);

      final first = await repository.deviceId();
      final second = await repository.deviceId();

      expect(first, second);
      expect(first, hasLength(32));
      expect(await ServerRepository(prefs: prefs).deviceId(), first);
    });

    test('differs between installations', () async {
      final a = await ServerRepository(
        prefs: await SharedPreferences.getInstance(),
      ).deviceId();

      SharedPreferences.setMockInitialValues(<String, Object>{});
      final b = await ServerRepository(
        prefs: await SharedPreferences.getInstance(),
      ).deviceId();

      expect(a, isNot(b));
    });
  });

  group('managing servers', () {
    test('removing a server deletes its token first', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = containerWith(ServerRepository(prefs: prefs));
      final registry = await registryOf(container);
      final profile = await registry.add(info: _info, auth: _auth);

      await registry.remove(profile.id);

      // A secret left behind with nothing pointing at it is the failure
      // worth testing for.
      expect(keychain.containsKey(profile.credentialKey), isFalse);
      expect(container.read(serverRegistryProvider).profiles, isEmpty);
      expect(container.read(serverRegistryProvider).activeId, isNull);
    });

    test('removing the active server falls back to another', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = containerWith(ServerRepository(prefs: prefs));
      final registry = await registryOf(container);

      final first = await registry.add(info: _info, auth: _auth);
      final second = await registry.add(
        info: const ServerInfo(
          uri: 'https://other.lan',
          name: 'Other',
          version: '10.9',
          serverId: 'srv2',
          kind: ServerKind.jellyfin,
        ),
        auth: _auth,
      );

      expect(container.read(serverRegistryProvider).activeId, second.id);

      await registry.remove(second.id);

      expect(container.read(serverRegistryProvider).activeId, first.id);
      expect(container.read(serverRegistryProvider).source, isNotNull);
    });

    test('renaming keeps the id, so the token is not orphaned', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = containerWith(ServerRepository(prefs: prefs));
      final registry = await registryOf(container);
      final profile = await registry.add(info: _info, auth: _auth);

      await registry.rename(profile.id, 'Living room');

      final renamed = container.read(serverRegistryProvider).profiles.single;
      expect(renamed.name, 'Living room');
      expect(renamed.id, profile.id);
      expect(keychain[renamed.credentialKey], 'tok123');
    });

    test('signing in again replaces the token and clears the prompt',
        () async {
      final prefs = await SharedPreferences.getInstance();
      final container = containerWith(ServerRepository(prefs: prefs));
      final registry = await registryOf(container);
      final profile = await registry.add(info: _info, auth: _auth);

      keychain.remove(profile.credentialKey);
      await registry.activate(profile.id);
      expect(container.read(serverRegistryProvider).signedOutId, profile.id);

      await registry.refreshToken(
        profile.id,
        const AuthResult(
          token: 'fresh',
          userId: 'u9',
          username: 'nam',
          serverId: 'srv1',
        ),
      );

      expect(keychain[profile.credentialKey], 'fresh');
      expect(container.read(serverRegistryProvider).signedOutId, isNull);
      expect(container.read(serverRegistryProvider).source, isNotNull);
    });
  });
}
