// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// One side of a pairing: who is on the other end, and the secret both kept.
@immutable
class RemotePeer {
  const RemotePeer({required this.id, required this.name, required this.secret});

  final String id;
  final String name;
  final List<int> secret;
}

/// The pairings this installation has made, in the keychain.
///
/// Two lists, because an installation can be both ends: a receiver keeps the
/// phones allowed to control it, and a phone keeps the receivers it has
/// paired with. Local by nature — a pairing is between two devices, and there
/// is nothing about it a Jellyfin server could usefully hold.
class RemoteTrustStore {
  RemoteTrustStore({FlutterSecureStorage? secure})
      : _secure = secure ?? const FlutterSecureStorage();

  static const _phonesKey = 'remote_paired_phones_v1';
  static const _receiversKey = 'remote_paired_receivers_v1';

  final FlutterSecureStorage _secure;

  /// Phones allowed to control this receiver.
  Future<Map<String, RemotePeer>> phones() => _read(_phonesKey);

  /// Receivers this phone has paired with.
  Future<Map<String, RemotePeer>> receivers() => _read(_receiversKey);

  Future<void> addPhone(RemotePeer peer) => _add(_phonesKey, peer);

  Future<void> addReceiver(RemotePeer peer) => _add(_receiversKey, peer);

  /// Revokes every phone at once — what "Forget paired phones" does.
  Future<void> forgetPhones() => _write(_phonesKey, const <String, RemotePeer>{});

  Future<void> forgetReceiver(String id) async {
    final all = await _read(_receiversKey)..remove(id);
    await _write(_receiversKey, all);
  }

  Future<Map<String, RemotePeer>> _read(String key) async {
    try {
      final raw = await _secure.read(key: key);
      if (raw == null || raw.isEmpty) return <String, RemotePeer>{};
      final decoded = jsonDecode(raw) as Map<String, Object?>;
      return <String, RemotePeer>{
        for (final MapEntry<String, Object?> e in decoded.entries)
          if (e.value case {'name': final String name, 'secret': final String s})
            e.key: RemotePeer(id: e.key, name: name, secret: base64Decode(s)),
      };
    } catch (e) {
      // A locked or corrupt keychain means "not paired", not a crash: the
      // worst it costs is typing a PIN again.
      debugPrint('Remote: could not read $key: $e');
      return <String, RemotePeer>{};
    }
  }

  Future<void> _add(String key, RemotePeer peer) async {
    final all = await _read(key);
    all[peer.id] = peer;
    await _write(key, all);
  }

  Future<void> _write(String key, Map<String, RemotePeer> peers) async {
    try {
      await _secure.write(
        key: key,
        value: jsonEncode(<String, Object?>{
          for (final RemotePeer p in peers.values)
            p.id: <String, Object?>{'name': p.name, 'secret': base64Encode(p.secret)},
        }),
      );
    } catch (e) {
      debugPrint('Remote: could not store $key: $e');
    }
  }
}
