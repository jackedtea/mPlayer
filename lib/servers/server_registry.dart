// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math' show Random;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'jellyfin_source.dart';
import 'media_library_source.dart';
import 'server_profile.dart';

/// Where signed-in servers are persisted.
///
/// The same two-store split `SourceRepository` uses, and for the same reason:
/// the profile list goes in ordinary preferences where it can be inspected,
/// and the access token goes in the platform keychain. Nothing writes a token
/// into preferences.
class ServerRepository {
  /// [prefs] and [secure] are injectable so tests need no platform channel.
  ServerRepository({
    SharedPreferences? prefs,
    FlutterSecureStorage? secure,
  })  :
        // A private field cannot be an initializing formal: Dart forbids
        // named parameters starting with an underscore.
        // ignore: prefer_initializing_formals
        _prefs = prefs,
        _secure = secure ?? const FlutterSecureStorage();

  static const _prefsKey = 'configured_servers_v1';
  static const _deviceIdKey = 'client_device_id_v1';

  SharedPreferences? _prefs;
  final FlutterSecureStorage _secure;

  Future<SharedPreferences> get _store async =>
      _prefs ??= await SharedPreferences.getInstance();

  Future<List<ServerProfile>> loadProfiles() async {
    final store = await _store;
    final raw = store.getStringList(_prefsKey) ?? const <String>[];

    final profiles = <ServerProfile>[];
    for (final String entry in raw) {
      try {
        profiles.add(
          ServerProfile.fromJson(jsonDecode(entry) as Map<String, dynamic>),
        );
      } catch (e) {
        // One corrupt entry must not hide every other server.
        debugPrint('Skipping unreadable server profile: $e');
      }
    }
    return profiles;
  }

  Future<void> saveProfiles(List<ServerProfile> profiles) async {
    final store = await _store;
    await store.setStringList(
      _prefsKey,
      profiles.map((p) => jsonEncode(p.toJson())).toList(),
    );
  }

  Future<String?> readToken(ServerProfile profile) async {
    try {
      return await _secure.read(key: profile.credentialKey);
    } catch (e) {
      // A locked keychain means "signed out", not a crash.
      debugPrint('Could not read the token for ${profile.id}: $e');
      return null;
    }
  }

  Future<void> writeToken(ServerProfile profile, String? token) async {
    try {
      if (token == null || token.isEmpty) {
        await _secure.delete(key: profile.credentialKey);
      } else {
        await _secure.write(key: profile.credentialKey, value: token);
      }
    } catch (e) {
      debugPrint('Could not store the token for ${profile.id}: $e');
    }
  }

  /// This installation's device id, generated once and kept.
  ///
  /// Jellyfin files sessions, playback history and tokens under it, so a new
  /// one every launch litters the server's dashboard with dead devices and
  /// orphans the token that was issued to the last one. In preferences rather
  /// than the keychain: it is an identifier, not a secret, and losing it to a
  /// locked keychain would be worse than exposing it.
  Future<String> deviceId() async {
    final store = await _store;
    final existing = store.getString(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final generated = _generateDeviceId();
    await store.setString(_deviceIdKey, generated);
    return generated;
  }

  /// 32 hex characters from the platform's secure random.
  ///
  /// Not a UUID package: this needs to be unique per installation and nothing
  /// more, and `Random.secure` is already in the SDK.
  static String _generateDeviceId() {
    final random = Random.secure();
    return List<String>.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }
}

final serverRepositoryProvider =
    Provider<ServerRepository>((ref) => ServerRepository());

/// Signed-in servers, and the live client for the one in use.
@immutable
class ServerRegistryState {
  const ServerRegistryState({
    this.profiles = const <ServerProfile>[],
    this.activeId,
    this.source,
    this.loading = true,
    this.signedOutId,
  });

  final List<ServerProfile> profiles;

  /// Which profile the library screens are showing.
  final String? activeId;

  /// The client for [activeId], or null while nothing is signed in.
  final MediaLibrarySource? source;

  final bool loading;

  /// Set when a server rejected the stored token, which is answered by asking
  /// for the password again rather than by an error message.
  final String? signedOutId;

  bool get hasServer => profiles.isNotEmpty;

  ServerProfile? get active {
    for (final ServerProfile p in profiles) {
      if (p.id == activeId) return p;
    }
    return null;
  }

  ServerRegistryState copyWith({
    List<ServerProfile>? profiles,
    String? activeId,
    bool clearActive = false,
    MediaLibrarySource? source,
    bool clearSource = false,
    bool? loading,
    String? signedOutId,
    bool clearSignedOut = false,
  }) {
    return ServerRegistryState(
      profiles: profiles ?? this.profiles,
      activeId: clearActive ? null : activeId ?? this.activeId,
      source: clearSource ? null : source ?? this.source,
      loading: loading ?? this.loading,
      signedOutId: clearSignedOut ? null : signedOutId ?? this.signedOutId,
    );
  }
}

final serverRegistryProvider =
    NotifierProvider<ServerRegistry, ServerRegistryState>(ServerRegistry.new);

/// The signed-in servers, and which one the library is looking at.
class ServerRegistry extends Notifier<ServerRegistryState> {
  /// The live client, held here as well as in the state.
  ///
  /// Riverpod forbids reading `state` from an `onDispose` callback, and the
  /// HTTP client still has to be closed when the provider goes — so teardown
  /// reads this field instead, the way `PlaybackController` keeps `_player`.
  MediaLibrarySource? _live;

  @override
  ServerRegistryState build() {
    // Loads behind the first frame: the Server tab renders its empty state
    // instantly and fills in, the way Storage does with shares.
    Future<void>.microtask(reload);

    ref.onDispose(() {
      final live = _live;
      _live = null;
      unawaited(live?.dispose());
    });
    return const ServerRegistryState();
  }

  /// Swaps the live client, closing whatever it replaces.
  Future<void> _setLive(MediaLibrarySource? source) async {
    final previous = _live;
    _live = source;
    await previous?.dispose();
  }

  ServerRepository get _repository => ref.read(serverRepositoryProvider);

  Future<void> reload() async {
    final profiles = await _repository.loadProfiles();
    state = state.copyWith(profiles: profiles, loading: false);

    // Most recently used first, so a single-server user always lands on
    // theirs and a multi-server one lands where they left off.
    final mostRecent = _mostRecent(profiles);
    if (mostRecent != null) await activate(mostRecent.id);
  }

  /// Builds the client for [profileId] and makes it the one in use.
  Future<void> activate(String profileId) async {
    final profile = state.profiles.where((p) => p.id == profileId).firstOrNull;
    if (profile == null) return;

    final token = await _repository.readToken(profile);
    if (token == null || token.isEmpty) {
      // The profile is there but its token is not: the keychain was cleared,
      // or the user signed out on the server. Either way it needs a password,
      // not an error.
      await _setLive(null);
      state = state.copyWith(
        activeId: profile.id,
        clearSource: true,
        signedOutId: profile.id,
      );
      return;
    }

    final client = await _clientFor(profile, token);
    await _setLive(client);

    state = state.copyWith(
      activeId: profile.id,
      source: client,
      clearSignedOut: true,
    );

    await _touch(profile);
  }

  /// Stores a freshly signed-in server and switches to it.
  Future<ServerProfile> add({
    required ServerInfo info,
    required AuthResult auth,
  }) async {
    final profile = ServerProfile(
      // Ours, and stable: the token is filed under it, so it must not be the
      // server's own id — the same server reached by two addresses would then
      // share one token entry.
      id: 'server-${DateTime.now().microsecondsSinceEpoch}',
      kind: info.kind,
      name: info.name,
      uri: info.uri,
      userId: auth.userId,
      username: auth.username,
      serverId: auth.serverId,
      lastUsed: DateTime.now(),
    );

    await _repository.writeToken(profile, auth.token);

    final profiles = <ServerProfile>[...state.profiles, profile];
    await _repository.saveProfiles(profiles);
    state = state.copyWith(profiles: profiles);

    await activate(profile.id);
    return profile;
  }

  /// The stored token for a profile, or null when there is none.
  ///
  /// Exposed so the edit form can try the session already held before asking
  /// for a password again.
  Future<String?> tokenFor(String profileId) async {
    final profile = state.profiles.where((p) => p.id == profileId).firstOrNull;
    if (profile == null) return null;
    return _repository.readToken(profile);
  }

  /// Rewrites a server the user has already added, keeping its id.
  ///
  /// The id is what the token is filed under and what every resume point
  /// names, so an edit must not mint a new one — moving a server to a new
  /// address is the same server, and issuing a fresh id would strand its
  /// watch history behind an entry nothing points at any more.
  ///
  /// A re-sign-in is part of the deal rather than an extra step: an address
  /// or a password that changed has to be proved before it is stored, or the
  /// app saves a profile it cannot use.
  Future<void> updateProfile(
    String profileId, {
    required ServerInfo info,
    required AuthResult auth,
  }) async {
    final profile = state.profiles.where((p) => p.id == profileId).firstOrNull;
    if (profile == null) return;

    final updated = profile.copyWith(
      kind: info.kind,
      name: info.name,
      uri: info.uri,
      userId: auth.userId,
      username: auth.username,
      serverId: auth.serverId,
      lastUsed: DateTime.now(),
    );

    await _repository.writeToken(updated, auth.token);
    await _replace(updated);
    await activate(updated.id);
  }

  /// Replaces the token after signing in again, keeping everything else.
  Future<void> refreshToken(String profileId, AuthResult auth) async {
    final profile = state.profiles.where((p) => p.id == profileId).firstOrNull;
    if (profile == null) return;

    final updated = profile.copyWith(
      userId: auth.userId,
      username: auth.username,
      lastUsed: DateTime.now(),
    );

    await _repository.writeToken(updated, auth.token);
    await _replace(updated);
    await activate(updated.id);
  }

  Future<void> rename(String profileId, String name) async {
    final profile = state.profiles.where((p) => p.id == profileId).firstOrNull;
    if (profile == null || name.trim().isEmpty) return;

    await _replace(profile.copyWith(name: name.trim()));
  }

  /// Forgets a server and its token.
  Future<void> remove(String profileId) async {
    final profile = state.profiles.where((p) => p.id == profileId).firstOrNull;
    if (profile == null) return;

    // The token first: a profile removed while its token survives leaves a
    // secret behind with nothing left pointing at it.
    await _repository.writeToken(profile, null);

    final profiles =
        state.profiles.where((p) => p.id != profileId).toList();
    await _repository.saveProfiles(profiles);

    final wasActive = state.activeId == profileId;
    if (wasActive) await _setLive(null);

    state = state.copyWith(
      profiles: profiles,
      clearActive: wasActive,
      clearSource: wasActive,
      clearSignedOut: true,
    );

    final next = _mostRecent(profiles);
    if (wasActive && next != null) await activate(next.id);
  }

  /// What the sign-in screens use before there is a profile.
  Future<JellyfinAuth> auth() async {
    return JellyfinAuth(identity: await identity());
  }

  /// How this installation names itself to a server.
  Future<ClientIdentity> identity() async {
    return ClientIdentity(
      deviceId: await _repository.deviceId(),
      deviceName: _deviceName(),
    );
  }

  Future<MediaLibrarySource> _clientFor(
    ServerProfile profile,
    String token,
  ) async {
    return JellyfinSource(
      profile: profile,
      token: token,
      identity: await identity(),
    );
  }

  Future<void> _replace(ServerProfile updated) async {
    final profiles = <ServerProfile>[
      for (final ServerProfile p in state.profiles)
        if (p.id == updated.id) updated else p,
    ];

    await _repository.saveProfiles(profiles);
    state = state.copyWith(profiles: profiles);
  }

  /// Records that a profile was used, so the next launch opens on it.
  Future<void> _touch(ServerProfile profile) =>
      _replace(profile.copyWith(lastUsed: DateTime.now()));

  static ServerProfile? _mostRecent(List<ServerProfile> profiles) {
    if (profiles.isEmpty) return null;

    final sorted = <ServerProfile>[...profiles]..sort(
        (a, b) => (b.lastUsed ?? DateTime(0)).compareTo(a.lastUsed ?? DateTime(0)),
      );
    return sorted.first;
  }

  /// What the server's device list will show.
  static String _deviceName() {
    if (kIsWeb) return 'Browser';
    return switch (Platform.operatingSystem) {
      'android' => 'Android',
      'ios' => 'iPhone',
      'windows' => 'Windows PC',
      'linux' => 'Linux PC',
      'macos' => 'Mac',
      final other => other,
    };
  }
}
