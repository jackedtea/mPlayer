// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'server_registry.dart';

/// Whether a launch opens straight onto the most recently used server's home
/// rather than stopping at the server list. On by default: most people have
/// one server, and the list in front of it is a tap that does nothing for
/// them.
final autoConnectProvider =
    NotifierProvider<AutoConnectController, bool>(AutoConnectController.new);

class AutoConnectController extends Notifier<bool> {
  static const _prefsKey = 'auto_connect_last_server';

  final Completer<void> _restored = Completer<void>();

  /// Completes once the stored choice has been read.
  ///
  /// The default is `true`, so deciding before this lands would carry a user
  /// who turned the option off into their server anyway on every launch.
  Future<void> get ready => _restored.future;

  @override
  bool build() {
    Future<void>.microtask(_restore);
    return true;
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getBool(_prefsKey);
      if (stored != null) state = stored;
    } finally {
      if (!_restored.isCompleted) _restored.complete();
    }
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, enabled);
  }
}

/// Whether this launch has gone past the server list into a server.
///
/// The Home tab reads this to choose its face rather than navigating: with
/// [autoConnectProvider] on, it turns true by itself once the registry has
/// signed the most recent profile back in; otherwise it waits for a tap on
/// the list. "Switch server" turns it false again, which puts the list back
/// in the same tab without a route of its own.
final serverSessionProvider =
    NotifierProvider<ServerSessionController, bool>(ServerSessionController.new);

class ServerSessionController extends Notifier<bool> {
  ProviderSubscription<ServerRegistryState>? _registry;

  @override
  bool build() {
    ref.onDispose(() => _registry?.close());
    unawaited(_autoEnter());
    return false;
  }

  Future<void> _autoEnter() async {
    final auto = ref.read(autoConnectProvider.notifier);
    // The default is on, so deciding before the stored choice lands would
    // carry a user who turned it off into their server anyway.
    ref.read(autoConnectProvider);
    await auto.ready;
    if (!ref.mounted || !ref.read(autoConnectProvider)) return;

    _registry = ref.listen<ServerRegistryState>(
      serverRegistryProvider,
      (_, next) => _onRegistry(next),
      fireImmediately: true,
    );
  }

  /// Decides once, after the registry has finished activating the most recent
  /// profile — which it does on its own at launch.
  void _onRegistry(ServerRegistryState registry) {
    if (registry.loading || registry.activeId == null) return;

    _registry?.close();
    _registry = null;

    // No client means the stored token is gone: that needs a password, which
    // starts from the list, not from a home screen with nothing behind it.
    if (registry.source != null) state = true;
  }

  /// Goes into whichever server is active now.
  void enter() {
    _registry?.close();
    _registry = null;
    state = true;
  }

  /// Back to the server list.
  void leave() {
    _registry?.close();
    _registry = null;
    state = false;
  }
}
