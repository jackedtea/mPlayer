// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'jellyfin_dto.dart';
import 'media_library_source.dart';
import 'server_profile.dart';

/// What a server sees this app as.
///
/// The device id has to be **stable across launches**: Jellyfin files
/// sessions and playback history under it, so a new one every start litters
/// the server's dashboard with dead devices.
@immutable
class ClientIdentity {
  const ClientIdentity({
    required this.deviceId,
    required this.deviceName,
    this.client = 'mPlayer',
    this.version = '1.0.0',
  });

  final String deviceId;
  final String deviceName;
  final String client;
  final String version;
}

/// Jellyfin, over its REST API.
///
/// Written against `dio` by hand rather than through a generated SDK: this
/// client uses perhaps fifteen endpoints out of several hundred, and the
/// official Dart bindings would be a dependency an order of magnitude larger
/// than the code that calls them.
///
/// Every method turns a failure into a [ServerException] carrying a sentence
/// for the user. A 401 is marked as such, because it has an answer nothing
/// else does: ask for the password again.
class JellyfinSource implements MediaLibrarySource {
  JellyfinSource({
    required ServerProfile profile,
    required String token,
    required this.identity,
    Dio? client,
  })  : _profile = profile,
        // Not an initialising formal, whatever the lint says: `this._token`
        // as a *named* parameter is a compile error in Dart — there are no
        // private named parameters — and the field has no business being
        // public.
        // ignore: prefer_initializing_formals
        _token = token,
        _base = Uri.parse(profile.uri),
        _dio = client ?? _defaultClient();

  static Dio _defaultClient() => Dio(
        BaseOptions(
          // A server on the far side of a VPN is slow to answer but does
          // answer; one that is off does not answer at all.
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 20),
          validateStatus: (_) => true,
        ),
      );

  final ServerProfile _profile;
  final String _token;
  final Uri _base;
  final Dio _dio;
  final ClientIdentity identity;

  @override
  ServerProfile get profile => _profile;

  Map<String, String> get _headers => <String, String>{
        'Authorization': authorizationHeader(
          client: identity.client,
          device: identity.deviceName,
          deviceId: identity.deviceId,
          version: identity.version,
          token: _token,
        ),
        'Accept': 'application/json',
      };

  // ------------------------------------------------------------ library

  @override
  Future<List<LibraryView>> views() async {
    final json = await _get('/UserViews', <String, String>{
      'userId': _profile.userId,
    });

    return _itemsOf(json).map(libraryViewFromJson).toList();
  }

  @override
  Future<List<ServerItem>> items(
    String viewId, {
    int startIndex = 0,
    int limit = 100,
    ServerSort sort = ServerSort.name,
  }) async {
    final json = await _get('/Items', <String, String>{
      'userId': _profile.userId,
      'parentId': viewId,
      // Without this a library returns its folders rather than its films.
      'recursive': 'true',
      // BoxSet is here for the Collections library, whose entries are box
      // sets rather than films. Jellyfin happens to return them anyway, but
      // Emby honours the filter, and without it that library comes back empty.
      'includeItemTypes': 'Movie,Series,Video,BoxSet',
      'sortBy': sortByFor(sort),
      'sortOrder': sortOrderFor(sort),
      'startIndex': '$startIndex',
      'limit': '$limit',
      'fields': _fields,
      'imageTypeLimit': '1',
      'enableImageTypes': 'Primary',
    });

    return _itemsOf(json).map(serverItemFromJson).toList();
  }

  @override
  Future<ServerItem> item(String itemId) async {
    final json = await _get('/Items/$itemId', <String, String>{
      'userId': _profile.userId,
      'fields': _fields,
    });

    return serverItemFromJson(json);
  }

  @override
  Future<List<ServerItem>> episodes(String seriesId, {String? seasonId}) async {
    final json = await _get('/Shows/$seriesId/Episodes', <String, String>{
      'userId': _profile.userId,
      'seasonId': ?seasonId,
      'fields': _fields,
    });

    return _itemsOf(json).map(serverItemFromJson).toList();
  }

  @override
  Future<List<ServerItem>> resumable({int limit = 12}) async {
    final json = await _get('/UserItems/Resume', <String, String>{
      'userId': _profile.userId,
      'limit': '$limit',
      'mediaTypes': 'Video',
      'fields': _fields,
    });

    return _itemsOf(json).map(serverItemFromJson).toList();
  }

  @override
  Future<List<ServerItem>> nextUp({int limit = 12}) async {
    final json = await _get('/Shows/NextUp', <String, String>{
      'userId': _profile.userId,
      'limit': '$limit',
      'fields': _fields,
    });

    return _itemsOf(json).map(serverItemFromJson).toList();
  }

  @override
  Future<List<ServerItem>> search(String query, {int limit = 40}) async {
    final json = await _get('/Items', <String, String>{
      'userId': _profile.userId,
      'searchTerm': query,
      'recursive': 'true',
      'includeItemTypes': 'Movie,Series,Episode',
      'limit': '$limit',
      'fields': _fields,
    });

    return _itemsOf(json).map(serverItemFromJson).toList();
  }

  @override
  Future<List<ServerItem>> similar(String itemId, {int limit = 12}) async {
    final json = await _get('/Items/$itemId/Similar', <String, String>{
      'userId': _profile.userId,
      'limit': '$limit',
      'fields': _fields,
    });

    return _itemsOf(json).map(serverItemFromJson).toList();
  }

  @override
  Uri? imageUrl(ServerItem item, {int? maxWidth}) =>
      imageUrlFor(item, base: _base, maxWidth: maxWidth);

  @override
  Uri? personImageUrl(ServerPerson person, {int? maxWidth}) =>
      personImageUrlFor(person, base: _base, maxWidth: maxWidth);

  // ----------------------------------------------------------- playback

  @override
  Future<ServerPlayback> playback(
    String itemId,
    PlaybackCapabilities caps,
  ) async {
    final json = await _get('/Items/$itemId/PlaybackInfo', <String, String>{
      'userId': _profile.userId,
      // Asked for rather than assumed: the server decides between handing the
      // file over and re-encoding it, and these are what it decides from.
      'maxStreamingBitrate': ?caps.maxBitrate?.toString(),
      'startTimeTicks': '0',
    });

    final playback = playbackFromJson(
      json,
      base: _base,
      itemId: itemId,
      token: _token,
    );

    if (playback == null) {
      throw const ServerException(
        'The server did not offer a way to play this.',
      );
    }
    return playback;
  }

  @override
  Future<void> reportProgress(
    String itemId, {
    required Duration position,
    required bool isPaused,
    String? playSessionId,
  }) {
    return _post('/Sessions/Playing/Progress', <String, dynamic>{
      'ItemId': itemId,
      'PositionTicks': durationToTicks(position),
      'IsPaused': isPaused,
      'PlaySessionId': playSessionId,
      'CanSeek': true,
    });
  }

  @override
  Future<void> reportStopped(
    String itemId, {
    required Duration position,
    String? playSessionId,
  }) {
    // Also what tells the server to tear down a transcode; skipping it leaves
    // ffmpeg running on the far end until it times out.
    return _post('/Sessions/Playing/Stopped', <String, dynamic>{
      'ItemId': itemId,
      'PositionTicks': durationToTicks(position),
      'PlaySessionId': playSessionId,
    });
  }

  @override
  Future<void> setPlayed(String itemId, {required bool played}) {
    final path = '/UserPlayedItems/$itemId';
    final query = <String, String>{'userId': _profile.userId};

    return played
        ? _post(path, const <String, dynamic>{}, query: query)
        : _delete(path, query);
  }

  @override
  Future<void> setFavourite(String itemId, {required bool favourite}) {
    final path = '/UserFavoriteItems/$itemId';
    final query = <String, String>{'userId': _profile.userId};

    return favourite
        ? _post(path, const <String, dynamic>{}, query: query)
        : _delete(path, query);
  }

  @override
  Future<void> dispose() async => _dio.close(force: true);

  // ------------------------------------------------------------ plumbing

  /// The extra properties the screens need and the server omits by default.
  ///
  /// Asked for on every request rather than only on the detail screen: the
  /// list endpoint is one round trip either way, and a second fetch to fill
  /// in an overview is a visible flicker on the card that already showed.
  static const _fields = 'Overview,ProductionYear,Genres,People,ChildCount,'
      'PrimaryImageAspectRatio,Tags,Studios,Status,EndDate';

  Uri _url(String path, [Map<String, String>? query]) {
    return _base.replace(
      pathSegments: <String>[
        ...(_base.pathSegments.where((s) => s.isNotEmpty)),
        ...path.split('/').where((s) => s.isNotEmpty),
      ],
      queryParameters: query == null || query.isEmpty ? null : query,
    );
  }

  Future<Map<String, dynamic>> _get(
    String path,
    Map<String, String> query,
  ) async {
    final response = await _send(
      () => _dio.getUri<dynamic>(
        _url(path, query),
        options: Options(headers: _headers),
      ),
    );

    final data = response.data;
    if (data is Map<String, dynamic>) return data;
    // `/Items/{id}` answers with a bare object; a list endpoint wraps one.
    if (data is List) return <String, dynamic>{'Items': data};

    throw const ServerException('The server sent something unreadable.');
  }

  Future<void> _post(
    String path,
    Map<String, dynamic> body, {
    Map<String, String>? query,
  }) async {
    await _send(
      () => _dio.postUri<dynamic>(
        _url(path, query),
        data: body,
        options: Options(headers: _headers),
      ),
    );
  }

  Future<void> _delete(String path, Map<String, String> query) async {
    await _send(
      () => _dio.deleteUri<dynamic>(
        _url(path, query),
        options: Options(headers: _headers),
      ),
    );
  }

  /// One place where every transport and status failure becomes a sentence.
  Future<Response<dynamic>> _send(
    Future<Response<dynamic>> Function() request,
  ) async {
    final Response<dynamic> response;
    try {
      response = await request();
    } on DioException catch (e) {
      throw ServerException(
        switch (e.type) {
          DioExceptionType.connectionTimeout ||
          DioExceptionType.connectionError =>
            '${_profile.name} did not answer. Check it is on and reachable '
                'from this network.',
          DioExceptionType.receiveTimeout =>
            '${_profile.name} took too long to answer.',
          _ => 'Could not reach ${_profile.name}.',
        },
      );
    }

    final status = response.statusCode ?? 0;
    if (status == 401 || status == 403) {
      throw ServerException(
        'Your session on ${_profile.name} has expired. Sign in again.',
        isUnauthorised: true,
      );
    }
    if (status < 200 || status >= 300) {
      throw ServerException('${_profile.name} refused the request ($status).');
    }

    return response;
  }

  static List<Map<String, dynamic>> _itemsOf(Map<String, dynamic> json) {
    final items = json['Items'];
    if (items is! List) return const <Map<String, dynamic>>[];

    return items.whereType<Map<String, dynamic>>().toList();
  }
}

/// Which of the two servers answered.
///
/// `ProductName` is the obvious signal and Jellyfin sets it — but **Emby 4.9
/// omits it entirely**, so a client that only looks there files every modern
/// Emby as Jellyfin and then calls routes it does not have. Emby is the only
/// one of the two that returns `RemoteAddresses`, which is the fallback.
ServerKind dialectFromPublicInfo(Map<Object?, Object?> json) {
  final productName = json['ProductName'];
  if (productName is String && productName.isNotEmpty) {
    final normalised = productName.toLowerCase();
    if (normalised.contains('jellyfin')) return ServerKind.jellyfin;
    if (normalised.contains('emby')) return ServerKind.emby;
  }
  if (json.containsKey('RemoteAddresses')) return ServerKind.emby;

  // Neither signal: assume the one this client actually implements.
  return ServerKind.jellyfin;
}

/// Where the probe ended up, which is not always where it was sent.
String _effectiveBaseUrl(String requested, Response<dynamic> response) {
  final finalUri = response.realUri;
  if (finalUri.toString().isEmpty) return requested;

  // Strip the endpoint back off; what is wanted is the server root.
  const suffix = '/System/Info/Public';
  final text = finalUri.toString();
  if (!text.endsWith(suffix)) return requested;

  return normaliseServerUrl(text.substring(0, text.length - suffix.length)) ??
      requested;
}

/// Signing in, which happens before there is a [JellyfinSource] to do it.
///
/// Separate for that reason: authentication is the one exchange that has no
/// token yet, so it cannot be a method on the thing a token is required to
/// build.
class JellyfinAuth {
  JellyfinAuth({required this.identity, Dio? client})
      : _dio = client ?? JellyfinSource._defaultClient();

  final ClientIdentity identity;
  final Dio _dio;

  /// Asks an address whether a Jellyfin server is there.
  ///
  /// Public information, and deliberately checked before any password is
  /// typed: telling someone their address is wrong is far better than
  /// telling them their password might be.
  Future<ServerInfo> probe(String rawUrl) async {
    final url = normaliseServerUrl(rawUrl);
    if (url == null) {
      throw const ServerException('That does not look like an address.');
    }

    final Response<dynamic> response;
    try {
      response = await _dio.getUri<dynamic>(
        Uri.parse('$url/System/Info/Public'),
        options: Options(
          headers: <String, String>{'Accept': 'application/json'},
          validateStatus: (_) => true,
        ),
      );
    } on DioException {
      throw const ServerException(
        'Nothing answered at that address. Check the host and port.',
      );
    }

    final data = response.data;
    if (response.statusCode != 200 || data is! Map) {
      throw const ServerException(
        'Something answered, but it is not a Jellyfin server.',
      );
    }

    return ServerInfo(
      // Whatever the request finally reached: a server behind a redirect from
      // http to https answers here, and storing the address the user typed
      // would mean paying for that redirect on every later request.
      uri: _effectiveBaseUrl(url, response),
      name: data['ServerName'] as String? ?? url,
      version: data['Version'] as String? ?? '',
      serverId: data['Id'] as String? ?? '',
      kind: dialectFromPublicInfo(data),
    );
  }

  /// Exchanges a password for a token.
  Future<AuthResult> signIn(
    ServerInfo server, {
    required String username,
    required String password,
  }) async {
    final Response<dynamic> response;
    try {
      response = await _dio.postUri<dynamic>(
        Uri.parse('${server.uri}/Users/AuthenticateByName'),
        data: <String, String>{'Username': username, 'Pw': password},
        options: Options(
          headers: <String, String>{
            'Authorization': authorizationHeader(
              client: identity.client,
              device: identity.deviceName,
              deviceId: identity.deviceId,
              version: identity.version,
            ),
            'Content-Type': 'application/json',
          },
          validateStatus: (_) => true,
        ),
      );
    } on DioException {
      throw ServerException('Could not reach ${server.name}.');
    }

    if (response.statusCode == 401) {
      throw const ServerException(
        'That username and password were not accepted.',
        isUnauthorised: true,
      );
    }

    final data = response.data;
    if (response.statusCode != 200 || data is! Map) {
      throw ServerException(
        '${server.name} refused the sign-in (${response.statusCode}).',
      );
    }

    return _authResultFrom(data, fallbackUsername: username, server: server);
  }

  /// Whether the server offers Quick Connect at all.
  ///
  /// **Emby answers 404 to every `/QuickConnect/*` route**, and an
  /// administrator can switch the feature off in Jellyfin, so the switch in
  /// the UI has to be led by this rather than by hope.
  Future<bool> isQuickConnectEnabled(ServerInfo server) async {
    if (server.kind != ServerKind.jellyfin) return false;

    try {
      final response = await _dio.getUri<dynamic>(
        Uri.parse('${server.uri}/QuickConnect/Enabled'),
        options: Options(validateStatus: (_) => true),
      );
      // The body is a bare `true`/`false`.
      return response.statusCode == 200 && response.data == true;
    } catch (e) {
      debugPrint('Could not ask about Quick Connect: $e');
      return false;
    }
  }

  /// Starts a Quick Connect attempt.
  ///
  /// The user reads [QuickConnectRequest.code] out to their own Jellyfin,
  /// approves it there, and the secret is exchanged for a token here — so no
  /// password is ever typed on this device.
  Future<QuickConnectRequest> initiateQuickConnect(ServerInfo server) async {
    final url = Uri.parse('${server.uri}/QuickConnect/Initiate');
    final options = Options(
      headers: <String, String>{'Authorization': _anonymousHeader()},
      validateStatus: (_) => true,
    );

    Response<dynamic> response;
    try {
      // 10.7 and later accept GET; older builds required POST.
      response = await _dio.getUri<dynamic>(url, options: options);
      if (response.statusCode == 405) {
        response = await _dio.postUri<dynamic>(url, options: options);
      }
    } on DioException {
      throw ServerException('Could not reach ${server.name}.');
    }

    final data = response.data;
    if (response.statusCode != 200 || data is! Map) {
      throw const ServerException(
        'This server would not start a Quick Connect request.',
      );
    }

    final code = data['Code'] as String?;
    final secret = data['Secret'] as String?;
    if (code == null || secret == null) {
      throw const ServerException('The server sent an unusable code.');
    }

    return QuickConnectRequest(code: code, secret: secret);
  }

  /// Waits for the user to approve [request] on another device.
  ///
  /// Returns null when [timeout] passes without approval, which is a person
  /// walking away rather than a failure. A 404 mid-poll is terminal: the
  /// secret expired or was revoked on the server.
  Future<AuthResult?> awaitQuickConnect(
    ServerInfo server,
    QuickConnectRequest request, {
    Duration timeout = const Duration(minutes: 3),
    Duration interval = const Duration(seconds: 3),
  }) async {
    final deadline = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(deadline)) {
      final Response<dynamic> response;
      try {
        response = await _dio.getUri<dynamic>(
          Uri.parse('${server.uri}/QuickConnect/Connect')
              .replace(queryParameters: <String, String>{
            'secret': request.secret,
          }),
          options: Options(validateStatus: (_) => true),
        );
      } on DioException {
        // A blip on the way to a server that is otherwise fine; the deadline
        // is the safety net.
        await Future<void>.delayed(interval);
        continue;
      }

      if (response.statusCode == 404) {
        throw const ServerException('That code expired. Start again.');
      }

      final data = response.data;
      if (data is Map && data['Authenticated'] == true) {
        return _exchangeQuickConnect(server, request.secret);
      }

      await Future<void>.delayed(interval);
    }

    return null;
  }

  Future<AuthResult> _exchangeQuickConnect(
    ServerInfo server,
    String secret,
  ) async {
    final response = await _dio.postUri<dynamic>(
      Uri.parse('${server.uri}/Users/AuthenticateWithQuickConnect'),
      data: <String, String>{'Secret': secret},
      options: Options(
        headers: <String, String>{
          'Authorization': _anonymousHeader(),
          'Content-Type': 'application/json',
        },
        validateStatus: (_) => true,
      ),
    );

    final data = response.data;
    if (response.statusCode != 200 || data is! Map) {
      throw const ServerException('The approval was not accepted.');
    }

    return _authResultFrom(data, fallbackUsername: '', server: server);
  }

  /// The header used before there is a token to put in it.
  String _anonymousHeader() => authorizationHeader(
        client: identity.client,
        device: identity.deviceName,
        deviceId: identity.deviceId,
        version: identity.version,
      );

  static AuthResult _authResultFrom(
    Map<Object?, Object?> data, {
    required String fallbackUsername,
    required ServerInfo server,
  }) {
    final token = data['AccessToken'] as String?;
    final user = data['User'];
    if (token == null || user is! Map) {
      throw const ServerException('The server did not return a session.');
    }

    return AuthResult(
      token: token,
      userId: user['Id'] as String? ?? '',
      username: user['Name'] as String? ?? fallbackUsername,
      serverId: data['ServerId'] as String? ?? server.serverId,
    );
  }

  Future<void> dispose() async => _dio.close(force: true);
}

/// A Quick Connect attempt in progress.
@immutable
class QuickConnectRequest {
  const QuickConnectRequest({required this.code, required this.secret});

  /// Shown to the user, who types it into their own Jellyfin.
  final String code;

  /// The opaque handle this device polls and finally exchanges.
  final String secret;
}

@immutable
class ServerInfo {
  const ServerInfo({
    required this.uri,
    required this.name,
    required this.version,
    required this.serverId,
    required this.kind,
  });

  final String uri;
  final String name;
  final String version;
  final String serverId;
  final ServerKind kind;
}

@immutable
class AuthResult {
  const AuthResult({
    required this.token,
    required this.userId,
    required this.username,
    required this.serverId,
  });

  final String token;
  final String userId;
  final String username;
  final String serverId;
}
