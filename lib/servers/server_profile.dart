// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/foundation.dart';

/// Which media server this is. Jellyfin and Emby share an ancestor and most
/// of an API, but they have diverged enough that the differences have to be
/// named rather than guessed at.
enum ServerKind {
  jellyfin('Jellyfin'),
  emby('Emby');

  const ServerKind(this.label);

  final String label;
}

/// A server the user has signed in to.
///
/// Holds **no token**, for the same reason [SourceConfig] holds no password:
/// this is the half that is safe to serialise into ordinary preferences. The
/// access token lives in `flutter_secure_storage` under [credentialKey].
@immutable
class ServerProfile {
  const ServerProfile({
    required this.id,
    required this.kind,
    required this.name,
    required this.uri,
    required this.userId,
    required this.username,
    this.serverId = '',
    this.lastUsed,
    this.isAdministrator = false,
  });

  factory ServerProfile.fromJson(Map<String, dynamic> json) {
    return ServerProfile(
      id: json['id'] as String,
      kind: ServerKind.values.firstWhere(
        (k) => k.name == json['kind'],
        // A profile written by a newer build must not stop the app starting.
        orElse: () => ServerKind.jellyfin,
      ),
      name: json['name'] as String? ?? '',
      uri: json['uri'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      username: json['username'] as String? ?? '',
      serverId: json['serverId'] as String? ?? '',
      isAdministrator: json['isAdministrator'] as bool? ?? false,
      lastUsed: switch (json['lastUsed']) {
        final int ms => DateTime.fromMillisecondsSinceEpoch(ms),
        _ => null,
      },
    );
  }

  /// Ours, not the server's, and stable across edits — it is what the token
  /// is filed under, so renaming a server must not orphan its credentials.
  final String id;

  final ServerKind kind;

  /// What the server calls itself, or what the user renamed it to.
  final String name;

  /// Base URL, normalised: scheme, host, port, and any path prefix the server
  /// sits behind. Never a trailing slash — see [normaliseServerUrl].
  final String uri;

  /// The authenticated user's id, which most endpoints are scoped by.
  final String userId;

  final String username;

  /// The server's own id. Two profiles with the same one are the same server
  /// reached by two addresses (LAN and WAN), which is worth knowing before
  /// listing it twice.
  final String serverId;

  final DateTime? lastUsed;

  /// Whether this account may use the administration screens.
  ///
  /// Cached from the last sign-in or token validation so the Settings list can
  /// be drawn before any request lands. Re-read on every validate — an
  /// administrator can be demoted, and a stale `true` here is a section whose
  /// every screen answers 403.
  final bool isAdministrator;

  String get credentialKey => 'server_token_$id';

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'kind': kind.name,
        'name': name,
        'uri': uri,
        'userId': userId,
        'username': username,
        'serverId': serverId,
        'isAdministrator': isAdministrator,
        'lastUsed': lastUsed?.millisecondsSinceEpoch,
      };

  ServerProfile copyWith({
    ServerKind? kind,
    String? name,
    String? uri,
    String? userId,
    String? username,
    String? serverId,
    DateTime? lastUsed,
    bool? isAdministrator,
  }) {
    return ServerProfile(
      id: id,
      // Editable: a server reached at a new address may turn out to be an
      // Emby where a Jellyfin used to be, and the dialect decides which
      // routes the client calls.
      kind: kind ?? this.kind,
      name: name ?? this.name,
      uri: uri ?? this.uri,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      serverId: serverId ?? this.serverId,
      isAdministrator: isAdministrator ?? this.isAdministrator,
      lastUsed: lastUsed ?? this.lastUsed,
    );
  }

  @override
  bool operator ==(Object other) => other is ServerProfile && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Turns what a user types into a base URL that can be requested.
///
/// People type `192.168.1.10:8096`, `jellyfin.home.lan/`, or paste the whole
/// `https://host/web/index.html#!/home.html` out of a browser. All three have
/// to reach the same server, so the rules are:
///
/// - a bare host gets `http://`, since a server on a LAN rarely has TLS
/// - a trailing slash is dropped, because every path is joined with one
/// - the web client's own path is stripped: `/web/index.html` is the UI, not
///   the API root
///
/// Returns null when there is nothing usable left.
String? normaliseServerUrl(String raw) {
  var text = raw.trim();
  if (text.isEmpty) return null;

  if (!text.contains('://')) text = 'http://$text';

  final uri = Uri.tryParse(text);
  if (uri == null || uri.host.isEmpty) return null;
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;

  var path = uri.path;
  // Everything from the web client's entry point onward belongs to the
  // browser UI. A reverse proxy prefix before it does not, and is kept.
  final web = path.indexOf('/web/');
  if (web >= 0) {
    path = path.substring(0, web);
  } else if (path.endsWith('/web')) {
    path = path.substring(0, path.length - 4);
  }

  while (path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }

  // Built from parts rather than with `replace`: passing null to that means
  // "keep what is there", so a pasted `#!/home.html` would survive it.
  return Uri(
    scheme: uri.scheme,
    userInfo: uri.userInfo.isEmpty ? null : uri.userInfo,
    host: uri.host,
    port: uri.hasPort ? uri.port : null,
    path: path,
  ).toString();
}
