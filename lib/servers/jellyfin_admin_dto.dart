// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

/// Reading what the administration routes send.
///
/// Pure, and separate from the client that calls them, for the same reason
/// `jellyfin_dto.dart` is: the whole shape of these responses can then be
/// tested against captured JSON with no server to break.
library;

import 'jellyfin_dto.dart' show ticksToDuration, ticksToPosition;
import 'server_admin.dart';

ServerSystemInfo systemInfoFromJson(Map<String, dynamic> json) {
  return ServerSystemInfo(
    name: json['ServerName'] as String? ?? '',
    version: json['Version'] as String? ?? '',
    operatingSystem: json['OperatingSystem'] as String? ?? '',
    // Jellyfin 10.9 renamed this; both spellings are in the wild and neither
    // is worth losing the line over.
    architecture:
        json['SystemArchitecture'] as String? ??
        json['Architecture'] as String? ??
        '',
    canRestart: json['CanSelfRestart'] as bool? ?? false,
    // Removed from the payload in 10.9, where every server that can restart
    // can also stop. Defaulting to the restart answer keeps the button
    // present where it works instead of hiding it on every modern server.
    canShutdown:
        json['CanSelfShutdown'] as bool? ??
        json['CanSelfRestart'] as bool? ??
        false,
    startupWizardCompleted: json['StartupWizardCompleted'] as bool? ?? true,
    hasPendingRestart: json['HasPendingRestart'] as bool? ?? false,
  );
}

/// One entry of `/Sessions`.
///
/// Returns null for a session with no id, which cannot be acted on and would
/// draw a row whose buttons all fail.
AdminSession? adminSessionFromJson(Map<String, dynamic> json) {
  final id = json['Id'] as String?;
  if (id == null || id.isEmpty) return null;

  final nowPlaying = json['NowPlayingItem'];
  final playState = json['PlayState'];

  return AdminSession(
    id: id,
    username: json['UserName'] as String? ?? '',
    // `DeviceName` is what the device calls itself and `Client` is the app on
    // it. Both are shown, because "Chrome" and "Jellyfin Web" answer
    // different questions.
    deviceName: json['DeviceName'] as String? ?? '',
    client: json['Client'] as String? ?? '',
    nowPlaying: nowPlaying is Map ? _nowPlayingTitle(nowPlaying) : null,
    position: playState is Map
        ? ticksToPosition(playState['PositionTicks'])
        : null,
    runtime: nowPlaying is Map
        ? ticksToPosition(nowPlaying['RunTimeTicks'])
        : null,
    isPaused: playState is Map && playState['IsPaused'] == true,
    supportsRemoteControl: json['SupportsRemoteControl'] as bool? ?? false,
    lastActivity: DateTime.tryParse(json['LastActivityDate'] as String? ?? ''),
    playMethod: nowPlaying is Map && playState is Map
        ? PlayMethod.fromWire(playState['PlayMethod'])
        : null,
    transcoding: switch (json['TranscodingInfo']) {
      final Map<String, dynamic> t => sessionTranscodingFromJson(t),
      _ => null,
    },
    clientVersion: json['ApplicationVersion'] as String? ?? '',
    remoteAddress: json['RemoteEndPoint'] as String? ?? '',
  );
}

SessionTranscoding sessionTranscodingFromJson(Map<String, dynamic> json) {
  return SessionTranscoding(
    isVideoDirect: json['IsVideoDirect'] as bool? ?? true,
    isAudioDirect: json['IsAudioDirect'] as bool? ?? true,
    videoCodec: json['VideoCodec'] as String? ?? '',
    audioCodec: json['AudioCodec'] as String? ?? '',
    container: json['Container'] as String? ?? '',
    bitrate: (json['Bitrate'] as num?)?.toInt(),
    width: (json['Width'] as num?)?.toInt(),
    height: (json['Height'] as num?)?.toInt(),
    framerate: (json['Framerate'] as num?)?.toDouble(),
    audioChannels: (json['AudioChannels'] as num?)?.toInt(),
    hardwareAcceleration: switch (json['HardwareAccelerationType']) {
      final String s when s != 'none' => s,
      _ => '',
    },
    completion: (json['CompletionPercentage'] as num?)?.toDouble(),
    reasons: transcodeReasonsFromJson(json['TranscodeReasons']),
  );
}

/// A flags enum the server writes as a list of names on current versions and
/// as one comma-separated string on older ones.
List<String> transcodeReasonsFromJson(Object? value) {
  final parts = switch (value) {
    final List<Object?> list => <String>[
      for (final v in list)
        if (v is String) v,
    ],
    final String s => s.split(','),
    _ => const <String>[],
  };
  return <String>[
    for (final String p in parts)
      if (p.trim().isNotEmpty) p.trim(),
  ];
}

/// "Westworld · S1E10 · The Bicameral Mind", or just the film's name.
///
/// An episode's own title says nothing about what is being watched, which is
/// the one thing this row exists to say.
String _nowPlayingTitle(Map<Object?, Object?> item) {
  final name = (item['Name'] as String?)?.trim() ?? '';
  final series = (item['SeriesName'] as String?)?.trim();
  if (series == null || series.isEmpty) return name;

  final season = item['ParentIndexNumber'];
  final episode = item['IndexNumber'];
  final code = season is int && episode is int ? 'S${season}E$episode' : '';

  return <String>[series, code, name].where((s) => s.isNotEmpty).join(' · ');
}

ScheduledTask scheduledTaskFromJson(Map<String, dynamic> json) {
  final lastResult = json['LastExecutionResult'];

  return ScheduledTask(
    id: json['Id'] as String? ?? '',
    name: json['Name'] as String? ?? '',
    description: json['Description'] as String? ?? '',
    state: TaskState.fromWire(json['State'] as String?),
    // Present only while running, and the server sends it as a double.
    progress: (json['CurrentProgressPercentage'] as num?)?.toDouble(),
    lastEndedAt: lastResult is Map
        ? DateTime.tryParse(lastResult['EndTimeUtc'] as String? ?? '')
        : null,
    // "Completed" is the only good outcome; Failed, Cancelled and Aborted are
    // all worth colouring, and an absent result is a task that has never run.
    lastFailed:
        lastResult is Map &&
        lastResult['Status'] != null &&
        lastResult['Status'] != 'Completed',
    triggers: switch (json['Triggers']) {
      final List<Object?> list => <TaskTrigger>[
        for (final Object? t in list)
          if (t is Map) taskTriggerFromJson(t),
      ],
      _ => const <TaskTrigger>[],
    },
  );
}

TaskTrigger taskTriggerFromJson(Map<Object?, Object?> json) {
  return TaskTrigger(
    kind: TaskTriggerKind.fromWire(json['Type']),
    timeOfDay: ticksToPosition(json['TimeOfDayTicks']),
    interval: ticksToDuration(json['IntervalTicks']),
    dayOfWeek: json['DayOfWeek'] as String? ?? '',
  );
}

AdminUser adminUserFromJson(Map<String, dynamic> json) {
  final policy = json['Policy'];
  final imageTags = json['PrimaryImageTag'];

  return AdminUser(
    id: json['Id'] as String? ?? '',
    name: json['Name'] as String? ?? '',
    isAdministrator: policy is Map && policy['IsAdministrator'] == true,
    isDisabled: policy is Map && policy['IsDisabled'] == true,
    isHidden: policy is Map && policy['IsHidden'] == true,
    lastActivity: DateTime.tryParse(json['LastActivityDate'] as String? ?? ''),
    imageTag: imageTags is String ? imageTags : null,
  );
}

AdminDevice adminDeviceFromJson(Map<String, dynamic> json) {
  return AdminDevice(
    id: json['Id'] as String? ?? '',
    name: json['Name'] as String? ?? '',
    appName: json['AppName'] as String? ?? '',
    appVersion: json['AppVersion'] as String? ?? '',
    username: json['LastUserName'] as String? ?? '',
    lastSeen: DateTime.tryParse(json['DateLastActivity'] as String? ?? ''),
  );
}

ActivityEntry activityEntryFromJson(Map<String, dynamic> json) {
  return ActivityEntry(
    // The id is an int on this route and a string on every other one.
    id: '${json['Id'] ?? ''}',
    name: json['Name'] as String? ?? '',
    overview:
        json['Overview'] as String? ?? json['ShortOverview'] as String? ?? '',
    type: json['Type'] as String? ?? '',
    severity: ActivitySeverity.fromWire(json['Severity'] as String?),
    at: DateTime.tryParse(json['Date'] as String? ?? ''),
    // Present only on an entry a user caused; a scheduled scan has none.
    userId: json['UserId'] as String? ?? '',
  );
}

ServerPlugin serverPluginFromJson(Map<String, dynamic> json) {
  return ServerPlugin(
    id: json['Id'] as String? ?? '',
    version: json['Version'] as String? ?? '',
    name: json['Name'] as String? ?? '',
    description: json['Description'] as String? ?? '',
    status: PluginStatus.fromWire(json['Status'] as String?),
    canUninstall: json['CanUninstall'] as bool? ?? true,
  );
}

UserPolicy userPolicyFromJson(Map<Object?, Object?> json) {
  bool flag(String key, bool fallback) =>
      json[key] is bool ? json[key]! as bool : fallback;
  int number(String key) => (json[key] as num?)?.toInt() ?? 0;

  final folders = json['EnabledFolders'];

  return UserPolicy(
    isAdministrator: flag('IsAdministrator', false),
    isDisabled: flag('IsDisabled', false),
    isHidden: flag('IsHidden', false),
    enableAllFolders: flag('EnableAllFolders', true),
    enabledFolders: folders is List
        ? <String>[
            for (final Object? id in folders)
              if (id is String) id,
          ]
        : const <String>[],
    enableMediaPlayback: flag('EnableMediaPlayback', true),
    enableVideoTranscoding: flag('EnableVideoPlaybackTranscoding', true),
    enableAudioTranscoding: flag('EnableAudioPlaybackTranscoding', true),
    enableRemuxing: flag('EnablePlaybackRemuxing', true),
    enableContentDownloading: flag('EnableContentDownloading', true),
    enableContentDeletion: flag('EnableContentDeletion', false),
    // 10.9 and later; an older server has no such switch and the account
    // cannot manage collections either way.
    enableCollectionManagement: flag('EnableCollectionManagement', false),
    enableRemoteAccess: flag('EnableRemoteAccess', true),
    remoteBitrateLimit: number('RemoteClientBitrateLimit'),
    maxActiveSessions: number('MaxActiveSessions'),
    maxParentalRating: (json['MaxParentalRating'] as num?)?.toInt(),
    maxParentalSubRating: (json['MaxParentalSubRating'] as num?)?.toInt(),
  );
}

/// [server]'s own policy object with [policy]'s fields laid over it.
///
/// The whole object goes back because the route replaces rather than patches:
/// every key the model does not carry has to be the server's own value, or the
/// write resets it.
Map<String, dynamic> applyUserPolicy(
  Map<Object?, Object?> server,
  UserPolicy policy,
) {
  return <String, dynamic>{
    ...server.cast<String, dynamic>(),
    'IsAdministrator': policy.isAdministrator,
    'IsDisabled': policy.isDisabled,
    'IsHidden': policy.isHidden,
    'EnableAllFolders': policy.enableAllFolders,
    'EnabledFolders': policy.enableAllFolders
        // Jellyfin's own editor sends an empty grant list with "all": a stale
        // list beside it is harmless to the server and confusing to read.
        ? const <String>[]
        : policy.enabledFolders,
    'EnableMediaPlayback': policy.enableMediaPlayback,
    'EnableVideoPlaybackTranscoding': policy.enableVideoTranscoding,
    'EnableAudioPlaybackTranscoding': policy.enableAudioTranscoding,
    'EnablePlaybackRemuxing': policy.enableRemuxing,
    'EnableContentDownloading': policy.enableContentDownloading,
    'EnableContentDeletion': policy.enableContentDeletion,
    // Only written where the server has the switch: sending an unknown key to
    // 10.8 is ignored, but there is no reason to send it.
    if (server.containsKey('EnableCollectionManagement'))
      'EnableCollectionManagement': policy.enableCollectionManagement,
    'EnableRemoteAccess': policy.enableRemoteAccess,
    'RemoteClientBitrateLimit': policy.remoteBitrateLimit,
    'MaxActiveSessions': policy.maxActiveSessions,
    'MaxParentalRating': policy.maxParentalRating,
    if (server.containsKey('MaxParentalSubRating') ||
        policy.maxParentalSubRating != null)
      'MaxParentalSubRating': policy.maxParentalSubRating,
  };
}

/// `/Users/{id}`, or null when the server left the policy out — which it
/// does for nobody an administrator asks about, and which would otherwise
/// draw an editor full of defaults that are not the account's.
AdminUserDetail? adminUserDetailFromJson(Map<String, dynamic> json) {
  final policy = json['Policy'];
  if (policy is! Map) return null;

  return AdminUserDetail(
    user: adminUserFromJson(json),
    policy: userPolicyFromJson(policy),
    // `HasConfiguredPassword` is the one that means it: `HasPassword` is true
    // on some versions for every account, password or not.
    hasPassword:
        json['HasConfiguredPassword'] as bool? ??
        json['HasPassword'] as bool? ??
        true,
  );
}

AdminLibrary adminLibraryFromJson(Map<String, dynamic> json) {
  return AdminLibrary(
    id: json['Id'] as String? ?? '',
    name: json['Name'] as String? ?? '',
    kind: json['CollectionType'] as String? ?? '',
  );
}

/// `/Localization/ParentalRatings`, one option per score.
///
/// A country's list names several ratings at one score ("PG-13" and "TV-14"
/// both sit at 13), and offering both is offering the same limit twice under
/// two names. They are joined the way Jellyfin's own editor joins them.
/// 10.11 moved the number into `RatingScore` and keeps `Value` alongside; a
/// rating with neither is "unrated" and is not a limit anyone can pick.
List<ParentalRatingOption> parentalRatingsFromJson(List<Object?> json) {
  final byScore = <(int, int?), List<String>>{};

  for (final Object? entry in json) {
    if (entry is! Map) continue;
    final name = (entry['Name'] as String?)?.trim() ?? '';
    if (name.isEmpty) continue;

    final scoreObject = entry['RatingScore'];
    final score = scoreObject is Map
        ? (scoreObject['Score'] as num?)?.toInt()
        : (entry['Value'] as num?)?.toInt();
    if (score == null) continue;
    final subScore = scoreObject is Map
        ? (scoreObject['SubScore'] as num?)?.toInt()
        : null;

    final names = byScore.putIfAbsent((score, subScore), () => <String>[]);
    if (!names.contains(name)) names.add(name);
  }

  final keys = byScore.keys.toList()
    ..sort((a, b) {
      final byMain = a.$1.compareTo(b.$1);
      if (byMain != 0) return byMain;
      return (a.$2 ?? -1).compareTo(b.$2 ?? -1);
    });

  return <ParentalRatingOption>[
    for (final (int, int?) key in keys)
      ParentalRatingOption(
        name: byScore[key]!.join(' / '),
        score: key.$1,
        subScore: key.$2,
      ),
  ];
}

AdminLibraryFolder adminLibraryFolderFromJson(Map<String, dynamic> json) {
  final locations = json['Locations'];
  return AdminLibraryFolder(
    name: json['Name'] as String? ?? '',
    itemId: json['ItemId'] as String? ?? '',
    kind: json['CollectionType'] as String? ?? '',
    paths: locations is List
        ? <String>[
            for (final Object? p in locations)
              if (p is String) p,
          ]
        : const <String>[],
    // Reported only while a scan runs — and as 100 for a while after one
    // finishes on some versions, which reads as "done", not "running".
    refreshProgress: switch ((json['RefreshProgress'] as num?)?.toDouble()) {
      final double p when p < 100 && json['RefreshStatus'] != 'Idle' => p,
      _ => null,
    },
  );
}

/// The query a refresh of [mode] sends — what Jellyfin's own dialog sends.
Map<String, String> refreshQuery(MetadataRefresh mode) {
  final full = mode != MetadataRefresh.scan;
  return <String, String>{
    // Ignored from 10.11, which always walks the children; needed before it.
    'Recursive': 'true',
    'MetadataRefreshMode': full ? 'FullRefresh' : 'Default',
    'ImageRefreshMode': full ? 'FullRefresh' : 'Default',
    'ReplaceAllMetadata': '${mode == MetadataRefresh.replaceAll}',
    'ReplaceAllImages': 'false',
  };
}

ItemMetadata itemMetadataFromJson(Map<String, dynamic> json) {
  List<String> strings(String key) => switch (json[key]) {
    final List<Object?> list => <String>[
      for (final Object? v in list)
        if (v is String && v.trim().isNotEmpty) v.trim(),
    ],
    _ => const <String>[],
  };

  return ItemMetadata(
    name: json['Name'] as String? ?? '',
    originalTitle: json['OriginalTitle'] as String? ?? '',
    // `ForcedSortName` is the one a person set; `SortName` is the server's own
    // derivation, and writing that back would freeze it.
    sortName: json['ForcedSortName'] as String? ?? '',
    year: (json['ProductionYear'] as num?)?.toInt(),
    overview: json['Overview'] as String? ?? '',
    officialRating: json['OfficialRating'] as String? ?? '',
    genres: strings('Genres'),
    tags: strings('Tags'),
    locked: json['LockData'] as bool? ?? false,
  );
}

/// [server]'s item with [metadata] laid over it, for the whole-object write.
Map<String, dynamic> applyItemMetadata(
  Map<String, dynamic> server,
  ItemMetadata metadata,
) {
  String? text(String value) => value.trim().isEmpty ? null : value.trim();

  return <String, dynamic>{
    ...server,
    'Name': metadata.name.trim(),
    'OriginalTitle': text(metadata.originalTitle),
    'ForcedSortName': text(metadata.sortName),
    'ProductionYear': metadata.year,
    'Overview': text(metadata.overview),
    'OfficialRating': text(metadata.officialRating),
    'Genres': metadata.genres,
    'Tags': metadata.tags,
    'LockData': metadata.locked,
  };
}

ServerLogFile serverLogFileFromJson(Map<String, dynamic> json) {
  return ServerLogFile(
    name: json['Name'] as String? ?? '',
    size: (json['Size'] as num?)?.toInt() ?? 0,
    modified: DateTime.tryParse(json['DateModified'] as String? ?? ''),
  );
}

StorageFolder storageFolderFromJson(
  Map<Object?, Object?> json,
  StorageFolderKind kind,
) {
  // The server writes -1 where it could not measure a disk.
  int? bytes(Object? v) => switch (v) {
    final num n when n >= 0 => n.toInt(),
    _ => null,
  };
  return StorageFolder(
    path: json['Path'] as String? ?? '',
    kind: kind,
    free: bytes(json['FreeSpace']),
    used: bytes(json['UsedSpace']),
  );
}

ServerStorage serverStorageFromJson(Map<String, dynamic> json) {
  const keys = <String, StorageFolderKind>{
    'ProgramDataFolder': StorageFolderKind.programData,
    'CacheFolder': StorageFolderKind.cache,
    'ImageCacheFolder': StorageFolderKind.imageCache,
    'InternalMetadataFolder': StorageFolderKind.metadata,
    'TranscodingTempFolder': StorageFolderKind.transcodes,
    'LogFolder': StorageFolderKind.logs,
    'WebFolder': StorageFolderKind.web,
  };

  return ServerStorage(
    folders: <StorageFolder>[
      for (final MapEntry<String, StorageFolderKind> k in keys.entries)
        if (json[k.key] case final Map<Object?, Object?> f)
          storageFolderFromJson(f, k.value),
    ],
    libraries: <({String name, List<StorageFolder> folders})>[
      for (final Object? lib in json['Libraries'] as List? ?? const <Object?>[])
        if (lib is Map)
          (
            name: lib['Name'] as String? ?? '',
            folders: <StorageFolder>[
              for (final Object? f
                  in lib['Folders'] as List? ?? const <Object?>[])
                if (f is Map)
                  storageFolderFromJson(f, StorageFolderKind.library),
            ],
          ),
    ],
  );
}

ServerApiKey? serverApiKeyFromJson(Map<String, dynamic> json) {
  final token = json['AccessToken'] as String?;
  if (token == null || token.isEmpty) return null;
  return ServerApiKey(
    token: token,
    appName: json['AppName'] as String? ?? '',
    created: DateTime.tryParse(json['DateCreated'] as String? ?? ''),
  );
}

/// The tail of a log: the last [maxBytes] characters, starting on a line.
String logTail(String text, int maxBytes) {
  if (text.length <= maxBytes) return text;
  final cut = text.substring(text.length - maxBytes);
  final firstBreak = cut.indexOf('\n');
  return firstBreak < 0 ? cut : cut.substring(firstBreak + 1);
}

/// The server's minimum severity for "problems only".
bool isProblem(ActivityEntry e) => e.severity != ActivitySeverity.information;

/// One entry of `/Environment/DirectoryContents` or `/Environment/Drives`, or
/// null for a file or an entry with no path.
ServerFolder? serverFolderFromJson(Map<String, dynamic> json) {
  final path = json['Path'] as String?;
  if (path == null || path.isEmpty) return null;
  // Drives carry no Type; a listing asked for folders only still says so.
  final type = json['Type'];
  if (type != null && type != 'Directory' && type != 1) return null;
  final name = (json['Name'] as String?)?.trim() ?? '';
  return ServerFolder(name: name.isEmpty ? path : name, path: path);
}

/// The library kinds a person can make, in the order Jellyfin's own dialog
/// lists them. Null is mixed content, which the server is sent as no type.
const List<String?> libraryKinds = <String?>[
  'movies',
  'tvshows',
  'music',
  'musicvideos',
  'homevideos',
  'books',
  null,
];

/// [server] with [changes] laid over it. A map inside [changes] merges into
/// the map at the same key rather than replacing it, so `{TrickplayOptions:
/// {Interval: 5000}}` changes one field of that object and keeps the rest.
Map<String, dynamic> mergeConfiguration(
  Map<String, dynamic> server,
  Map<String, dynamic> changes,
) {
  final merged = <String, dynamic>{...server};
  for (final MapEntry<String, dynamic> change in changes.entries) {
    final current = merged[change.key];
    final next = change.value;
    merged[change.key] = current is Map && next is Map
        ? mergeConfiguration(
            current.cast<String, dynamic>(),
            next.cast<String, dynamic>(),
          )
        : next;
  }
  return merged;
}

/// `/Localization/Cultures` or `/Localization/Countries`, by [codeKey],
/// sorted by name, one per code.
List<ConfigOption> configOptionsFromJson(List<Object?> json, String codeKey) {
  final seen = <String>{};
  final options = <ConfigOption>[
    for (final Object? entry in json)
      if (entry is Map)
        if (entry[codeKey] case final String code
            when code.isNotEmpty && seen.add(code.toLowerCase()))
          ConfigOption(
            value: code,
            label: (entry['DisplayName'] as String?)?.trim().isNotEmpty ?? false
                ? (entry['DisplayName'] as String).trim()
                : code,
          ),
  ];
  options.sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
  return options;
}
