// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/foundation.dart';

import '../core/models/media_models.dart';

/// A network location the user has configured.
///
/// Deliberately holds **no password**. Credentials live in
/// `flutter_secure_storage` under [credentialKey]; this object is the part
/// that is safe to serialise into ordinary preferences.
@immutable
class SourceConfig {
  const SourceConfig({
    required this.id,
    required this.kind,
    required this.name,
    required this.uri,
    this.username = '',
  });

  factory SourceConfig.fromJson(Map<String, dynamic> json) {
    return SourceConfig(
      id: json['id'] as String,
      kind: SourceKind.values.firstWhere(
        (k) => k.name == json['kind'],
        // A config written by a newer build naming an unknown kind must not
        // crash startup; it degrades to WebDAV rather than taking the app out.
        orElse: () => SourceKind.webdav,
      ),
      name: json['name'] as String? ?? '',
      uri: json['uri'] as String? ?? '',
      username: json['username'] as String? ?? '',
    );
  }

  /// Stable across edits; also the key credentials are stored under.
  final String id;

  final SourceKind kind;

  /// Display name — "NAS", "Nextcloud".
  final String name;

  /// Base location: `https://dav.home.lan/remote.php/dav/files/minh` or
  /// `smb://192.168.1.10/media`.
  final String uri;

  final String username;

  bool get needsAuth => username.isNotEmpty;

  String get credentialKey => 'source_password_$id';

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'kind': kind.name,
        'name': name,
        'uri': uri,
        'username': username,
      };

  SourceConfig copyWith({
    String? name,
    String? uri,
    String? username,
  }) {
    return SourceConfig(
      id: id,
      kind: kind,
      name: name ?? this.name,
      uri: uri ?? this.uri,
      username: username ?? this.username,
    );
  }

  @override
  bool operator ==(Object other) => other is SourceConfig && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
