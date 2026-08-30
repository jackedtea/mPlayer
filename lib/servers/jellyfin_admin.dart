// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:dio/dio.dart';

import 'jellyfin_admin_dto.dart';
import 'jellyfin_dto.dart' show authorizationHeader;
import 'jellyfin_source.dart' show ClientIdentity;
import 'media_library_source.dart' show ServerException;
import 'server_admin.dart';
import 'server_profile.dart';

/// The administration routes, over the same REST API the catalogue uses.
///
/// A client of its own rather than more methods on `JellyfinSource`, and its
/// own small HTTP plumbing rather than that one's, because **403 means
/// something here that it means nowhere else**: not "sign in again" but "this
/// account is not an administrator". Sharing the catalogue's error mapping
/// would send a user who is merely not an admin to a password prompt that
/// cannot help them.
class JellyfinAdmin implements ServerAdmin {
  JellyfinAdmin({
    required ServerProfile profile,
    required String token,
    required this.identity,
    Dio? client,
  })  : _profile = profile,
        // ignore: prefer_initializing_formals
        _token = token,
        _base = Uri.parse(profile.uri),
        _dio = client ?? _defaultClient();

  static Dio _defaultClient() => Dio(
        BaseOptions(
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

  // ------------------------------------------------------------- server

  @override
  Future<ServerSystemInfo> systemInfo() async {
    final json = await _getMap('/System/Info');
    return systemInfoFromJson(json);
  }

  @override
  Future<void> setServerName(String name) async {
    // Read, change, write **whole**. The route replaces the configuration
    // rather than patching it, so posting `{ServerName: …}` alone would reset
    // every other setting on the server to its default — which is a far
    // larger accident than a rename.
    final config = await _getMap('/System/Configuration');
    await _post('/System/Configuration', <String, dynamic>{
      ...config,
      'ServerName': name.trim(),
    });
  }

  @override
  Future<void> restartServer() => _postEmpty('/System/Restart');

  @override
  Future<void> shutdownServer() => _postEmpty('/System/Shutdown');

  // ----------------------------------------------------------- sessions

  @override
  Future<List<AdminSession>> sessions() async {
    final list = await _getList('/Sessions');

    final sessions = <AdminSession>[
      for (final Object? entry in list)
        if (entry is Map<String, dynamic>)
          if (adminSessionFromJson(entry) case final AdminSession s) s,
    ];

    // What is playing first, then the rest by how recently they were seen: an
    // administrator opening this is looking for who is watching, and a list
    // ordered by the server's own whim buries that under idle devices.
    sessions.sort((a, b) {
      if (a.isPlaying != b.isPlaying) return a.isPlaying ? -1 : 1;
      final at = a.lastActivity;
      final bt = b.lastActivity;
      if (at == null || bt == null) return 0;
      return bt.compareTo(at);
    });

    return sessions;
  }

  @override
  Future<void> stopSession(String sessionId) =>
      _postEmpty('/Sessions/$sessionId/Playing/Stop');

  @override
  Future<void> messageSession(
    String sessionId, {
    required String header,
    required String text,
  }) {
    return _post('/Sessions/$sessionId/Message', <String, dynamic>{
      'Header': header,
      'Text': text,
      // Without a timeout some clients leave the message on screen until it
      // is dismissed, which on a television nobody is sitting at means for
      // ever.
      'TimeoutMs': 8000,
    });
  }

  // -------------------------------------------------------------- tasks

  @override
  Future<List<ScheduledTask>> tasks() async {
    final list = await _getList('/ScheduledTasks');

    final tasks = <ScheduledTask>[
      for (final Object? entry in list)
        if (entry is Map<String, dynamic>) scheduledTaskFromJson(entry),
    ];

    // Running first — that is the one the reader came to look at — then by
    // name, because the server's order is registration order and means
    // nothing to anyone.
    tasks.sort((a, b) {
      if (a.isRunning != b.isRunning) return a.isRunning ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return tasks;
  }

  @override
  Future<void> runTask(String taskId) =>
      _postEmpty('/ScheduledTasks/Running/$taskId');

  @override
  Future<void> stopTask(String taskId) =>
      _delete('/ScheduledTasks/Running/$taskId');

  @override
  Future<void> scanLibraries() => _postEmpty('/Library/Refresh');

  // -------------------------------------------------- users and devices

  @override
  Future<List<AdminUser>> users() async {
    final list = await _getList('/Users');

    final users = <AdminUser>[
      for (final Object? entry in list)
        if (entry is Map<String, dynamic>) adminUserFromJson(entry),
    ];

    users.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return users;
  }

  @override
  Future<void> setUserDisabled(String userId, {required bool disabled}) async {
    // The same read-change-write rule the rename follows, and for a sharper
    // reason: this object *is* the account's permissions, and posting one
    // field would strip every library grant and parental limit it has.
    final user = await _getMap('/Users/$userId');
    final policy = user['Policy'];
    if (policy is! Map) {
      throw const ServerException(
        'The server did not describe that account, so nothing was changed.',
      );
    }

    await _post('/Users/$userId/Policy', <String, dynamic>{
      ...policy.cast<String, dynamic>(),
      'IsDisabled': disabled,
    });
  }

  @override
  Future<List<AdminDevice>> devices() async {
    final json = await _getMap('/Devices');
    final items = json['Items'];
    if (items is! List) return const <AdminDevice>[];

    final devices = <AdminDevice>[
      for (final Object? entry in items)
        if (entry is Map<String, dynamic>) adminDeviceFromJson(entry),
    ];

    devices.sort((a, b) {
      final at = a.lastSeen;
      final bt = b.lastSeen;
      if (at == null || bt == null) return 0;
      return bt.compareTo(at);
    });

    return devices;
  }

  @override
  Future<void> deleteDevice(String deviceId) =>
      _delete('/Devices', <String, String>{'id': deviceId});

  // ------------------------------------------------------------ history

  @override
  Future<List<ActivityEntry>> activity({int limit = 50}) async {
    final json = await _getMap('/System/ActivityLog/Entries', <String, String>{
      'startIndex': '0',
      'limit': '$limit',
    });

    final items = json['Items'];
    if (items is! List) return const <ActivityEntry>[];

    return <ActivityEntry>[
      for (final Object? entry in items)
        if (entry is Map<String, dynamic>) activityEntryFromJson(entry),
    ];
  }

  // ------------------------------------------------------------ plugins

  @override
  Future<List<ServerPlugin>> plugins() async {
    final list = await _getList('/Plugins');

    final plugins = <ServerPlugin>[
      for (final Object? entry in list)
        if (entry is Map<String, dynamic>) serverPluginFromJson(entry),
    ];

    plugins.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return plugins;
  }

  @override
  Future<void> setPluginEnabled(
    String pluginId,
    String version, {
    required bool enabled,
  }) {
    // Addressed by id *and* version, because a server can hold two versions
    // of one plugin and only one of them is meant to change.
    return _postEmpty(
      '/Plugins/$pluginId/$version/${enabled ? 'Enable' : 'Disable'}',
    );
  }

  @override
  Future<void> uninstallPlugin(String pluginId, String version) =>
      _delete('/Plugins/$pluginId/$version');

  @override
  Future<void> dispose() async => _dio.close(force: true);

  // ----------------------------------------------------------- plumbing

  Uri _url(String path, [Map<String, String>? query]) {
    return _base.replace(
      pathSegments: <String>[
        ...(_base.pathSegments.where((s) => s.isNotEmpty)),
        ...path.split('/').where((s) => s.isNotEmpty),
      ],
      queryParameters: query == null || query.isEmpty ? null : query,
    );
  }

  Future<Map<String, dynamic>> _getMap(
    String path, [
    Map<String, String>? query,
  ]) async {
    final response = await _send(
      () => _dio.getUri<dynamic>(
        _url(path, query),
        options: Options(headers: _headers),
      ),
    );

    final data = response.data;
    if (data is Map<String, dynamic>) return data;

    throw const ServerException('The server sent something unreadable.');
  }

  /// For the several admin routes that answer with a bare array.
  Future<List<Object?>> _getList(
    String path, [
    Map<String, String>? query,
  ]) async {
    final response = await _send(
      () => _dio.getUri<dynamic>(
        _url(path, query),
        options: Options(headers: _headers),
      ),
    );

    final data = response.data;
    if (data is List) return data;
    // A few of these are paged on some versions and bare on others.
    if (data is Map && data['Items'] is List) return data['Items'] as List;

    throw const ServerException('The server sent something unreadable.');
  }

  Future<void> _post(String path, Map<String, dynamic> body) async {
    await _send(
      () => _dio.postUri<dynamic>(
        _url(path),
        data: body,
        options: Options(headers: _headers),
      ),
    );
  }

  Future<void> _postEmpty(String path) async {
    await _send(
      () => _dio.postUri<dynamic>(
        _url(path),
        options: Options(headers: _headers),
      ),
    );
  }

  Future<void> _delete(String path, [Map<String, String>? query]) async {
    await _send(
      () => _dio.deleteUri<dynamic>(
        _url(path, query),
        options: Options(headers: _headers),
      ),
    );
  }

  /// Every transport and status failure, turned into a sentence.
  ///
  /// The difference from the catalogue client's version is 403, and it
  /// matters: there, every rejection means the session is gone and the answer
  /// is to sign in again. Here, an account that is signed in perfectly well
  /// can still be refused for not being an administrator, and sending that
  /// user to a password prompt would be sending them somewhere that cannot
  /// help.
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

    if (status == 401) {
      throw ServerException(
        'Your session on ${_profile.name} has expired. Sign in again.',
        isUnauthorised: true,
      );
    }
    if (status == 403) {
      throw ServerException(
        'Your account on ${_profile.name} is not an administrator.',
      );
    }
    // A restart or a shutdown kills the connection *because it worked*. The
    // server accepts the request, answers 204, and is gone before the socket
    // closes; a client treating the dropped response as a failure would tell
    // the user nothing happened when the server is already going down.
    if (status < 200 || status >= 300) {
      throw ServerException('${_profile.name} refused the request ($status).');
    }

    return response;
  }
}
