// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/models/media_models.dart';
import 'local_source.dart';
import 'media_source.dart';
import 'media_store_source.dart';
import 'media_proxy_server.dart';
import 'saf_source.dart';
import 'smb_source.dart';
import 'source_config.dart';
import 'webdav_source.dart';
import '../servers/jellyfin_media_source.dart';
import '../servers/server_registry.dart';

/// Where configured shares are persisted.
///
/// Two stores on purpose: the config list goes in ordinary preferences so it
/// can be read synchronously-ish and inspected, while passwords go in the
/// platform keychain. Nothing writes a password into preferences.
class SourceRepository {
  /// [prefs] and [secure] are injectable so tests can drive the repository
  /// without a platform channel.
  SourceRepository({
    SharedPreferences? prefs,
    FlutterSecureStorage? secure,
  })  :
        // A private field cannot be an initializing formal: Dart forbids
        // named parameters starting with an underscore.
        // ignore: prefer_initializing_formals
        _prefs = prefs,
        _secure = secure ?? const FlutterSecureStorage();

  static const _prefsKey = 'configured_sources_v1';

  SharedPreferences? _prefs;
  final FlutterSecureStorage _secure;

  Future<SharedPreferences> get _store async =>
      _prefs ??= await SharedPreferences.getInstance();

  Future<List<SourceConfig>> loadConfigs() async {
    final store = await _store;
    final raw = store.getStringList(_prefsKey) ?? const <String>[];

    final configs = <SourceConfig>[];
    for (final String entry in raw) {
      try {
        configs.add(
          SourceConfig.fromJson(jsonDecode(entry) as Map<String, dynamic>),
        );
      } catch (e) {
        // One corrupt entry must not hide every other configured share.
        debugPrint('Skipping unreadable source config: $e');
      }
    }
    return configs;
  }

  Future<void> saveConfigs(List<SourceConfig> configs) async {
    final store = await _store;
    await store.setStringList(
      _prefsKey,
      configs.map((c) => jsonEncode(c.toJson())).toList(),
    );
  }

  Future<String?> readPassword(SourceConfig config) async {
    try {
      return await _secure.read(key: config.credentialKey);
    } catch (e) {
      // A locked or unavailable keychain means "no password", not a crash.
      debugPrint('Could not read credentials for ${config.id}: $e');
      return null;
    }
  }

  Future<void> writePassword(SourceConfig config, String? password) async {
    try {
      if (password == null || password.isEmpty) {
        await _secure.delete(key: config.credentialKey);
      } else {
        await _secure.write(key: config.credentialKey, value: password);
      }
    } catch (e) {
      debugPrint('Could not store credentials for ${config.id}: $e');
    }
  }
}

final sourceRepositoryProvider =
    Provider<SourceRepository>((ref) => SourceRepository());

/// Configured sources plus their live drivers.
@immutable
class SourceRegistryState {
  const SourceRegistryState({
    this.configs = const <SourceConfig>[],
    this.drivers = const <String, MediaSource>{},
    this.loading = true,
  });

  /// Network shares only — the device is always present and is not
  /// configurable, so it never appears here.
  final List<SourceConfig> configs;

  /// Every usable source, including the device.
  final Map<String, MediaSource> drivers;

  final bool loading;

  SourceRegistryState copyWith({
    List<SourceConfig>? configs,
    Map<String, MediaSource>? drivers,
    bool? loading,
  }) {
    return SourceRegistryState(
      configs: configs ?? this.configs,
      drivers: drivers ?? this.drivers,
      loading: loading ?? this.loading,
    );
  }
}

final sourceRegistryProvider =
    NotifierProvider<SourceRegistry, SourceRegistryState>(SourceRegistry.new);

/// The map [PlaybackController] resolves against.
///
/// Derived so playback keeps a synchronous lookup even though configured
/// shares load asynchronously — the device is available from the first frame.
///
/// The signed-in server is folded in here rather than kept apart: once it is
/// one more entry in this map, the player, the folder queue, resume points
/// and casting all work against it without knowing what it is.
final mediaSourcesProvider = Provider<Map<String, MediaSource>>(
  (ref) {
    final drivers = <String, MediaSource>{
      ...ref.watch(sourceRegistryProvider).drivers,
    };

    final library = ref.watch(serverRegistryProvider).source;
    if (library != null) {
      drivers[library.profile.id] = JellyfinMediaSource(library);
    }
    return drivers;
  },
);

class SourceRegistry extends Notifier<SourceRegistryState> {
  @override
  SourceRegistryState build() {
    // Kick the load off without blocking the first frame: Storage must render
    // instantly with the device source, shares filling in behind it.
    Future<void>.microtask(reload);

    return SourceRegistryState(
      drivers: <String, MediaSource>{
        LocalSource.sourceId: const LocalSource(),
        // Android reads its videos through the system media index; scoped
        // storage forbids listing shared storage directly.
        if (MediaStoreSource.isSupported)
          MediaStoreSource.sourceId: const MediaStoreSource(),
        // Folders the user granted explicitly, for what the media index
        // cannot see.
        if (SafSource.isSupported) SafSource.sourceId: const SafSource(),
      },
    );
  }

  Future<void> reload() async {
    final repo = ref.read(sourceRepositoryProvider);
    final configs = await repo.loadConfigs();

    final drivers = <String, MediaSource>{
      LocalSource.sourceId: const LocalSource(),
      if (MediaStoreSource.isSupported)
        MediaStoreSource.sourceId: const MediaStoreSource(),
      if (SafSource.isSupported) SafSource.sourceId: const SafSource(),
    };
    for (final SourceConfig config in configs) {
      final driver = await _buildDriver(repo, config);
      if (driver != null) drivers[config.id] = driver;
    }

    state = SourceRegistryState(
      configs: configs,
      drivers: drivers,
      loading: false,
    );
  }

  Future<void> add(SourceConfig config, String? password) async {
    final repo = ref.read(sourceRepositoryProvider);
    await repo.writePassword(config, password);

    final configs = <SourceConfig>[
      ...state.configs.where((c) => c.id != config.id),
      config,
    ];
    await repo.saveConfigs(configs);
    await reload();
  }

  /// Replaces a configured share, keeping its position in the list.
  ///
  /// [password] `null` leaves the stored credential untouched — a keychain
  /// that could not be read must not silently wipe a working password. Pass an
  /// empty string to clear it.
  Future<void> update(SourceConfig config, String? password) async {
    if (!state.configs.any((c) => c.id == config.id)) {
      return add(config, password);
    }

    final repo = ref.read(sourceRepositoryProvider);
    if (password != null) await repo.writePassword(config, password);

    await repo.saveConfigs(
      state.configs.map((c) => c.id == config.id ? config : c).toList(),
    );
    await reload();
  }

  /// The stored password, so the edit sheet can show what is actually saved.
  Future<String?> passwordFor(SourceConfig config) =>
      ref.read(sourceRepositoryProvider).readPassword(config);

  Future<void> remove(String id) async {
    final repo = ref.read(sourceRepositoryProvider);
    final removed = state.configs.where((c) => c.id == id);
    for (final SourceConfig c in removed) {
      await repo.writePassword(c, null);
    }

    await repo.saveConfigs(
      state.configs.where((c) => c.id != id).toList(),
    );
    await reload();
  }

  Future<MediaSource?> _buildDriver(
    SourceRepository repo,
    SourceConfig config,
  ) async {
    return switch (config.kind) {
      SourceKind.webdav => WebDavSource(
          config: config,
          password: await repo.readPassword(config),
        ),
      // SMB reads through the loopback proxy: libmpv cannot consume a Dart
      // stream, and the proxy turns Range requests into offset reads so the
      // file stays seekable.
      SourceKind.smb => SmbSource(
          config: config,
          password: await repo.readPassword(config),
          proxy: ref.read(mediaProxyServerProvider),
        ),
      // NFS has no driver yet. The config is still kept and listed so the
      // user's setup is not silently discarded — the tile simply cannot be
      // browsed until the driver lands.
      _ => null,
    };
  }
}
