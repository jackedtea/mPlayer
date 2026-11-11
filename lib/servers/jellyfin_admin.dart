// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:convert';

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
  }) : _profile = profile,
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
    final policy = await _serverPolicy(userId);
    await _post('/Users/$userId/Policy', <String, dynamic>{
      ...policy.cast<String, dynamic>(),
      'IsDisabled': disabled,
    });
  }

  @override
  Future<AdminUserDetail> user(String userId) async {
    final detail = adminUserDetailFromJson(await _getMap('/Users/$userId'));
    if (detail == null) throw const ServerException(_undescribed);
    return detail;
  }

  @override
  Future<void> setUserPolicy(String userId, UserPolicy policy) async {
    // Read *now*, not the copy the editor opened with: another administrator
    // may have changed a field this screen does not show in the meantime, and
    // writing the old copy back would quietly undo it.
    final server = await _serverPolicy(userId);
    await _post('/Users/$userId/Policy', applyUserPolicy(server, policy));
  }

  /// The account's policy exactly as the server holds it.
  ///
  /// Refuses rather than guessing when the server will not say: a write built
  /// on a guessed policy is a write that resets the account.
  Future<Map<Object?, Object?>> _serverPolicy(String userId) async {
    final user = await _getMap('/Users/$userId');
    final policy = user['Policy'];
    if (policy is! Map) throw const ServerException(_undescribed);
    return policy;
  }

  static const _undescribed =
      'The server did not describe that account, so nothing was changed.';

  @override
  Future<AdminUser> createUser(String name, String password) async {
    final response = await _send(
      () => _dio.postUri<dynamic>(
        _url('/Users/New'),
        data: <String, dynamic>{
          'Name': name.trim(),
          // Absent rather than empty: the server only sets a password when one
          // is given, and an empty one is no password either way.
          if (password.isNotEmpty) 'Password': password,
        },
        options: Options(headers: _headers),
      ),
    );

    final data = response.data;
    if (data is Map<String, dynamic>) return adminUserFromJson(data);
    // Made, but answered with nothing readable: the list will show it.
    return AdminUser(id: '', name: name.trim());
  }

  @override
  Future<void> deleteUser(String userId) => _delete('/Users/$userId');

  @override
  Future<void> setUserPassword(String userId, String password) {
    // The `{userId}/Password` spelling, not `Password?userId=`: the second
    // only exists from 10.10, and the first is still served beside it. With a
    // userId that is not the caller's own, an administrator is not asked for
    // the current password — which is the point of doing this from here.
    return _post('/Users/$userId/Password', <String, dynamic>{
      'CurrentPw': '',
      'NewPw': password,
    });
  }

  @override
  Future<List<AdminLibrary>> libraries() async {
    final list = await _getList('/Library/MediaFolders', <String, String>{
      'isHidden': 'false',
    });

    return <AdminLibrary>[
      for (final Object? entry in list)
        if (entry is Map<String, dynamic>)
          if (adminLibraryFromJson(entry) case final AdminLibrary l
              when l.id.isNotEmpty)
            l,
    ];
  }

  @override
  Future<List<ParentalRatingOption>> parentalRatings() async =>
      parentalRatingsFromJson(await _getList('/Localization/ParentalRatings'));

  @override
  Future<List<AdminDevice>> devices({String? userId}) async {
    final json = await _getMap(
      '/Devices',
      userId == null ? null : <String, String>{'userId': userId},
    );
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
  Future<List<ActivityEntry>> activity({
    int limit = 50,
    ({String id, String name})? user,
  }) async {
    final json = await _getMap('/System/ActivityLog/Entries', <String, String>{
      'startIndex': '0',
      'limit': '$limit',
      if (user != null) ...<String, String>{
        'hasUserId': 'true',
        // 10.11's filter. Matched on the name, so the id check below is what
        // makes it exact — and what filters at all on an older server.
        'username': user.name,
      },
    });

    final items = json['Items'];
    if (items is! List) return const <ActivityEntry>[];

    return <ActivityEntry>[
      for (final Object? entry in items)
        if (entry is Map<String, dynamic>)
          if (activityEntryFromJson(entry) case final ActivityEntry e
              when user == null || _sameId(e.userId, user.id))
            e,
    ];
  }

  /// Jellyfin writes the same id with and without dashes on different routes.
  static bool _sameId(String a, String b) =>
      a.replaceAll('-', '').toLowerCase() ==
      b.replaceAll('-', '').toLowerCase();

  // ---------------------------------------------------- libraries and items

  @override
  Future<List<AdminLibraryFolder>> libraryFolders() async {
    final list = await _getList('/Library/VirtualFolders');
    final folders = <AdminLibraryFolder>[
      for (final Object? entry in list)
        if (entry is Map<String, dynamic>)
          if (adminLibraryFolderFromJson(entry) case final AdminLibraryFolder f
              when f.name.isNotEmpty)
            f,
    ];
    folders.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return folders;
  }

  @override
  Future<void> refreshItem(String itemId, MetadataRefresh mode) async {
    await _send(
      () => _dio.postUri<dynamic>(
        _url('/Items/$itemId/Refresh', refreshQuery(mode)),
        options: Options(headers: _headers),
      ),
    );
  }

  @override
  Future<void> renameLibrary(String name, String newName) async {
    await _send(
      () => _dio.postUri<dynamic>(
        _url('/Library/VirtualFolders/Name', <String, String>{
          'name': name,
          'newName': newName.trim(),
          // A rename moves the library's folder in the server's config
          // directory; nothing on disk changes, so there is nothing to scan.
          'refreshLibrary': 'false',
        }),
        options: Options(headers: _headers),
      ),
    );
  }

  @override
  Future<void> deleteLibrary(String name) => _delete(
    '/Library/VirtualFolders',
    <String, String>{'name': name, 'refreshLibrary': 'true'},
  );

  @override
  Future<void> addLibrary({
    required String name,
    required String? kind,
    required List<String> paths,
  }) async {
    // The paths go comma-separated in the query, which a path holding a
    // comma would split in two. Those are added one by one afterwards
    // instead, through the route that takes a path in its body.
    final plain = <String>[for (final p in paths) if (!p.contains(',')) p];
    final awkward = <String>[for (final p in paths) if (p.contains(',')) p];

    await _send(
      () => _dio.postUri<dynamic>(
        _url('/Library/VirtualFolders', <String, String>{
          'name': name.trim(),
          'collectionType': ?kind,
          if (plain.isNotEmpty) 'paths': plain.join(','),
          // Scanned once everything is in, not once per folder.
          'refreshLibrary': '${awkward.isEmpty}',
        }),
        options: Options(headers: _headers),
      ),
    );

    for (final (int i, String path) in awkward.indexed) {
      await _addPath(name.trim(), path, refresh: i == awkward.length - 1);
    }
  }

  @override
  Future<void> addLibraryPath(String name, String path) =>
      _addPath(name, path, refresh: true);

  Future<void> _addPath(String name, String path, {required bool refresh}) {
    return _send(
      () => _dio.postUri<dynamic>(
        _url('/Library/VirtualFolders/Paths', <String, String>{
          'refreshLibrary': '$refresh',
        }),
        data: <String, dynamic>{
          'Name': name,
          'PathInfo': <String, dynamic>{'Path': path},
        },
        options: Options(headers: _headers),
      ),
    );
  }

  @override
  Future<void> removeLibraryPath(String name, String path) => _delete(
        '/Library/VirtualFolders/Paths',
        <String, String>{'name': name, 'path': path, 'refreshLibrary': 'true'},
      );

  @override
  Future<List<ServerFolder>> drives() async {
    final list = await _getList('/Environment/Drives');
    return _foldersFrom(list, sort: false);
  }

  @override
  Future<List<ServerFolder>> folders(String path) async {
    final list = await _getList('/Environment/DirectoryContents', <String, String>{
      'path': path,
      'includeDirectories': 'true',
      'includeFiles': 'false',
    });
    return _foldersFrom(list, sort: true);
  }

  List<ServerFolder> _foldersFrom(List<Object?> list, {required bool sort}) {
    final folders = <ServerFolder>[
      for (final Object? entry in list)
        if (entry is Map<String, dynamic>)
          if (serverFolderFromJson(entry) case final ServerFolder f) f,
    ];
    if (sort) {
      folders.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    }
    return folders;
  }

  @override
  Future<String?> parentFolder(String path) async {
    final response = await _send(
      () => _dio.getUri<dynamic>(
        _url('/Environment/ParentPath', <String, String>{'path': path}),
        // A bare JSON string — or nothing at all, at a root.
        options: Options(headers: _headers, responseType: ResponseType.plain),
      ),
    );
    var text = (response.data as String? ?? '').trim();
    if (text.length >= 2 && text.startsWith('"') && text.endsWith('"')) {
      text = jsonDecode(text) as String;
    }
    return text.isEmpty || text == 'null' ? null : text;
  }

  @override
  Future<void> deleteItem(String itemId) => _delete('/Items/$itemId');

  @override
  Future<ItemMetadata> itemMetadata(String itemId) async =>
      itemMetadataFromJson(await _rawItem(itemId));

  @override
  Future<void> setItemMetadata(String itemId, ItemMetadata metadata) async {
    // Read at save time, for the reason the user policy is: the route clears
    // every field it is not sent, and the copy the editor opened with may be
    // older than a refresh that ran meanwhile.
    final server = await _rawItem(itemId);
    await _post('/Items/$itemId', applyItemMetadata(server, metadata));
  }

  /// The item exactly as the server describes it — every field, since a
  /// single-item read is not trimmed by a field list.
  Future<Map<String, dynamic>> _rawItem(String itemId) =>
      _getMap('/Items/$itemId', <String, String>{'userId': _profile.userId});

  @override
  Future<ActivityPage> activityPage({
    int startIndex = 0,
    int limit = 50,
    bool problemsOnly = false,
    DateTime? since,
  }) async {
    final json = await _getMap('/System/ActivityLog/Entries', <String, String>{
      'startIndex': '$startIndex',
      'limit': '$limit',
      if (since != null) 'minDate': since.toUtc().toIso8601String(),
      // 10.11 only; an older server sends everything and the filter below
      // does the work.
      if (problemsOnly) 'severity': 'Warning',
    });

    final items = json['Items'];
    final raw = <ActivityEntry>[
      if (items is List)
        for (final Object? entry in items)
          if (entry is Map<String, dynamic>) activityEntryFromJson(entry),
    ];

    return ActivityPage(
      entries: problemsOnly ? raw.where(isProblem).toList() : raw,
      fetched: raw.length,
      total: (json['TotalRecordCount'] as num?)?.toInt(),
    );
  }

  // --------------------------------------------------------------- logs

  @override
  Future<List<ServerLogFile>> logFiles() async {
    final list = await _getList('/System/Logs');
    final files = <ServerLogFile>[
      for (final Object? entry in list)
        if (entry is Map<String, dynamic>)
          if (serverLogFileFromJson(entry) case final ServerLogFile f
              when f.name.isNotEmpty)
            f,
    ];
    files.sort((a, b) {
      final at = a.modified;
      final bt = b.modified;
      if (at == null || bt == null) return b.name.compareTo(a.name);
      return bt.compareTo(at);
    });
    return files;
  }

  @override
  Future<String> logText(String name, {int maxBytes = 512 * 1024}) async {
    final response = await _send(
      () => _dio.getUri<String>(
        _url('/System/Logs/Log', <String, String>{'name': name}),
        // A log is text, whatever content type the server labels it with —
        // and parsing a JSON-looking line as JSON would lose the file.
        options: Options(headers: _headers, responseType: ResponseType.plain),
      ),
    );
    return logTail(response.data as String? ?? '', maxBytes);
  }

  // ------------------------------------------------------------ storage

  @override
  Future<ServerStorage?> storage() async {
    try {
      return serverStorageFromJson(await _getMap('/System/Info/Storage'));
    } on ServerException catch (e) {
      // Before 10.10 the route does not exist. That is "cannot say", which
      // the dashboard draws as nothing, not as an error.
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  // ----------------------------------------------------------- API keys

  @override
  Future<List<ServerApiKey>> apiKeys() async {
    final list = await _getList('/Auth/Keys');
    final keys = <ServerApiKey>[
      for (final Object? entry in list)
        if (entry is Map<String, dynamic>)
          if (serverApiKeyFromJson(entry) case final ServerApiKey k) k,
    ];
    keys.sort((a, b) {
      final at = a.created;
      final bt = b.created;
      if (at == null || bt == null) return 0;
      return bt.compareTo(at);
    });
    return keys;
  }

  @override
  Future<void> createApiKey(String appName) async {
    await _send(
      () => _dio.postUri<dynamic>(
        _url('/Auth/Keys', <String, String>{'app': appName.trim()}),
        options: Options(headers: _headers),
      ),
    );
  }

  @override
  Future<void> revokeApiKey(String token) => _delete('/Auth/Keys/$token');

  // ------------------------------------------------------------ plugins

  @override
  Future<List<ServerPlugin>> plugins() async {
    final list = await _getList('/Plugins');

    final plugins = <ServerPlugin>[
      for (final Object? entry in list)
        if (entry is Map<String, dynamic>) serverPluginFromJson(entry),
    ];

    plugins.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
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
  Future<Map<String, dynamic>> configuration([String? key]) =>
      _getMap(key == null ? '/System/Configuration' : '/System/Configuration/$key');

  @override
  Future<void> updateConfiguration(
    Map<String, dynamic> changes, [
    String? key,
  ]) async {
    final path =
        key == null ? '/System/Configuration' : '/System/Configuration/$key';
    final server = await _getMap(path);
    await _post(path, mergeConfiguration(server, changes));
  }

  @override
  Future<void> deleteTuner(String id) =>
      _delete('/LiveTv/TunerHosts', <String, String>{'id': id});

  @override
  Future<void> deleteGuideProvider(String id) =>
      _delete('/LiveTv/ListingProviders', <String, String>{'id': id});

  @override
  Future<List<ConfigOption>> cultures() async => configOptionsFromJson(
        await _getList('/Localization/Cultures'),
        'TwoLetterISOLanguageName',
      );

  @override
  Future<List<ConfigOption>> countries() async => configOptionsFromJson(
        await _getList('/Localization/Countries'),
        'TwoLetterISORegionName',
      );

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
      throw ServerException(switch (e.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.connectionError =>
          '${_profile.name} did not answer. Check it is on and reachable '
              'from this network.',
        DioExceptionType.receiveTimeout =>
          '${_profile.name} took too long to answer.',
        _ => 'Could not reach ${_profile.name}.',
      });
    }

    final status = response.statusCode ?? 0;

    if (status == 401) {
      throw ServerException(
        'Your session on ${_profile.name} has expired. Sign in again.',
        isUnauthorised: true,
      );
    }
    // A refusal the server explained is passed on in its words. The policy
    // route answers 403 for "there must be at least one administrator" and
    // "administrators cannot be disabled" — reading those as "you are not an
    // administrator" would tell an administrator something false.
    final reason = _refusalReason(response.data);

    if (status == 403) {
      throw ServerException(
        reason ?? 'Your account on ${_profile.name} is not an administrator.',
      );
    }
    // A restart or a shutdown kills the connection *because it worked*. The
    // server accepts the request, answers 204, and is gone before the socket
    // closes; a client treating the dropped response as a failure would tell
    // the user nothing happened when the server is already going down.
    if (status < 200 || status >= 300) {
      throw ServerException(
        reason ?? '${_profile.name} refused the request ($status).',
        statusCode: status,
      );
    }

    return response;
  }

  /// The sentence a refusal carried, if it carried one.
  ///
  /// Jellyfin answers some refusals with a bare string and others with
  /// problem details; an HTML error page or a stack trace is not a sentence
  /// and is not passed on.
  static String? _refusalReason(Object? data) {
    final text = switch (data) {
      final String s => s,
      {'detail': final String s} => s,
      {'title': final String s} when !s.startsWith('One or more') => s,
      _ => null,
    };
    final trimmed = text?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    if (trimmed.length > 200 || trimmed.startsWith('<')) return null;
    return trimmed;
  }
}
