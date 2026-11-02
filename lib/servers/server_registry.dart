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

import 'jellyfin_admin.dart';
import 'jellyfin_source.dart';
import 'media_library_source.dart';
import 'jellyfin_media_source.dart';
import 'server_admin.dart';
import 'server_pin.dart';
import 'server_profile.dart';
import 'stream_preferences.dart';
import '../downloads/downloads_controller.dart';
import '../downloads/offline_media_source.dart';
import '../sources/media_source.dart';

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

  /// The stored hash of the PIN guarding [profile], or null for none.
  Future<String?> readPinHash(ServerProfile profile) async {
    try {
      return await _secure.read(key: profile.pinKey);
    } catch (e) {
      debugPrint('Could not read the PIN for ${profile.id}: $e');
      return null;
    }
  }

  /// Stores [hash], or removes the PIN when it is null.
  Future<void> writePinHash(ServerProfile profile, String? hash) async {
    try {
      if (hash == null) {
        await _secure.delete(key: profile.pinKey);
      } else {
        await _secure.write(key: profile.pinKey, value: hash);
      }
    } catch (e) {
      debugPrint('Could not store the PIN for ${profile.id}: $e');
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

/// The live server as something the player can open, or null while nothing
/// is signed in.
///
/// A provider of its own so that the map below can rebuild without this:
/// [JellyfinMediaSource] keeps the play session of each item it resolved,
/// and a fresh one would file the next progress report against none.
final onlineMediaSourceProvider = Provider<JellyfinMediaSource?>((ref) {
  final library = ref.watch(serverRegistryProvider).source;
  if (library == null) return null;

  return JellyfinMediaSource(
    library,
    // Read through a callback rather than captured: the source is built
    // once and resolves many times, and a quality picked in the player has
    // to reach the *next* file without rebuilding this provider.
    preferences: () => StreamPreferences(
      quality: ref.read(streamQualityProvider),
      trackChoice: ref.read(trackChoiceProvider),
    ),
  );
});

/// Every source the player can resolve against, keyed by id.
///
/// One entry per profile: the signed-in server, wrapped so that an item
/// with a whole copy on the device plays from the file, plus one for each
/// other profile that has copies, which plays those and nothing else. With
/// nothing signed in and nothing downloaded, the map is empty.
///
/// **Still a map, deliberately.** `PlaybackController` looks a source up by
/// `mediaRef.sourceId`, and a resume point or a queue entry carries the
/// profile id it was made against. Collapsing this to a single value would
/// make every one of those lookups silently resolve to "the current server",
/// which is wrong the moment a second server can be signed in.
final mediaSourcesProvider = Provider<Map<String, MediaSource>>((ref) {
  final online = ref.watch(onlineMediaSourceProvider);
  final offline = ref.watch(downloadedProfilesProvider);
  final downloads = ref.read(downloadsProvider.notifier);

  return <String, MediaSource>{
    if (online != null)
      online.id: OfflineMediaSource(
        profileId: online.id,
        downloads: downloads,
        online: online,
      ),
    for (final String id in offline)
      if (id != online?.id)
        id: OfflineMediaSource(profileId: id, downloads: downloads),
  };
});

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
      name: info.name,
      uri: info.uri,
      userId: auth.userId,
      username: auth.username,
      serverId: auth.serverId,
      isAdministrator: auth.isAdministrator,
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
  ///
  /// [name] is what the user typed for it in the same sheet. Empty, or the
  /// server's own name, hands the name back to the server; anything else is
  /// kept on this device. Null leaves the name as it was.
  Future<void> updateProfile(
    String profileId, {
    required ServerInfo info,
    required AuthResult auth,
    String? name,
  }) async {
    final profile = state.profiles.where((p) => p.id == profileId).firstOrNull;
    if (profile == null) return;

    final typed = name?.trim();
    final custom = typed == null
        ? profile.nameIsCustom
        : typed.isNotEmpty && typed != info.name;
    final updated = profile.copyWith(
      // A name given on this device outlives the server's: editing the
      // address must not quietly undo a rename.
      name: !custom ? info.name : (typed ?? profile.name),
      nameIsCustom: custom,
      uri: info.uri,
      userId: auth.userId,
      username: auth.username,
      serverId: auth.serverId,
      isAdministrator: auth.isAdministrator,
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
      // Re-read every time rather than kept: an administrator can be demoted
      // between one sign-in and the next, and a stale `true` here is an admin
      // section whose every screen answers 403.
      isAdministrator: auth.isAdministrator,
      lastUsed: DateTime.now(),
    );

    await _repository.writeToken(updated, auth.token);
    await _replace(updated);
    await activate(updated.id);
  }

  /// Renames a profile. [custom] says the name was given on this device
  /// rather than set on the server, so re-reading the server keeps it.
  Future<void> rename(
    String profileId,
    String name, {
    bool custom = true,
  }) async {
    final profile = state.profiles.where((p) => p.id == profileId).firstOrNull;
    if (profile == null || name.trim().isEmpty) return;

    await _replace(
      profile.copyWith(name: name.trim(), nameIsCustom: custom),
    );
  }

  /// Forgets a server and its token.
  Future<void> remove(String profileId) async {
    final profile = state.profiles.where((p) => p.id == profileId).firstOrNull;
    if (profile == null) return;

    // The secrets first: a profile removed while its token or PIN survives
    // leaves something behind with nothing left pointing at it.
    await _repository.writeToken(profile, null);
    await _repository.writePinHash(profile, null);

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
  /// Guards [profileId] with [pin], or removes its PIN when [pin] is null.
  ///
  /// The hash is stretched on a background isolate: twenty thousand rounds
  /// of SHA-256 on the UI thread is a visible stutter on a slow phone.
  Future<void> setPin(String profileId, String? pin) async {
    final profile = state.profiles.where((p) => p.id == profileId).firstOrNull;
    if (profile == null) return;

    final hash = pin == null ? null : await compute(hashPin, pin);
    await _repository.writePinHash(profile, hash);

    final profiles = <ServerProfile>[
      for (final ServerProfile p in state.profiles)
        p.id == profileId ? p.copyWith(pinProtected: hash != null) : p,
    ];
    await _repository.saveProfiles(profiles);
    state = state.copyWith(profiles: profiles);
  }

  /// Whether [pin] opens [profileId].
  ///
  /// A profile flagged as guarded whose hash is missing — a keychain wiped
  /// under it — answers false: it stays locked, and removing and re-adding
  /// the server is the way back in, which needs its password anyway.
  Future<bool> verifyPinFor(String profileId, String pin) async {
    final profile = state.profiles.where((p) => p.id == profileId).firstOrNull;
    if (profile == null) return false;

    final stored = await _repository.readPinHash(profile);
    if (stored == null) return false;
    return compute(_verify, (pin, stored));
  }

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

  /// An administration client for the active server, or null.
  ///
  /// Null covers three different situations and all three mean the same thing
  /// to a caller: nothing is signed in, the token cannot be read, or the
  /// account is not an administrator. Built on demand rather than kept in
  /// state — the admin screens are opened rarely, and holding a second HTTP
  /// client open for every session that never visits them is waste.
  Future<ServerAdmin?> admin() async {
    final profile = state.active;
    if (profile == null || !profile.isAdministrator) return null;

    final token = await _repository.readToken(profile);
    if (token == null || token.isEmpty) return null;

    return JellyfinAdmin(
      profile: profile,
      token: token,
      identity: await identity(),
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

/// [verifyPin] with one argument, which is what `compute` hands over.
bool _verify((String, String) args) => verifyPin(args.$1, args.$2);
