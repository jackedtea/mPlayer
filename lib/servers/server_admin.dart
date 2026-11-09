// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

/// Running a server, as opposed to watching what is on it.
///
/// Kept apart from [MediaLibrarySource] because it is a different concern with
/// a different audience and a different failure: a catalogue call that fails
/// costs the user a shelf, and an admin call that fails may have been a
/// **restart that did not happen** — or one that did. Nothing here is reached
/// by a viewer, and every route behind it answers 403 to anyone who is not an
/// administrator.
library;

import 'package:flutter/foundation.dart';

/// What the server says about itself.
@immutable
class ServerSystemInfo {
  const ServerSystemInfo({
    required this.name,
    required this.version,
    this.operatingSystem = '',
    this.architecture = '',
    this.canRestart = false,
    this.canShutdown = false,
    this.startupWizardCompleted = true,
  });

  final String name;
  final String version;

  /// Empty on a server that declines to say — Jellyfin dropped
  /// `OperatingSystem` from the public info for a while, and a blank line
  /// beats inventing "Linux".
  final String operatingSystem;
  final String architecture;

  /// Whether this build can restart or stop itself at all.
  ///
  /// A server in a container usually cannot: the process is the container, and
  /// stopping it is the orchestrator's job. Offering the button anyway is
  /// offering one that does nothing — or, worse, one that takes the server
  /// away and does not bring it back.
  final bool canRestart;
  final bool canShutdown;

  final bool startupWizardCompleted;
}

/// Somebody watching something right now.
@immutable
class AdminSession {
  const AdminSession({
    required this.id,
    required this.username,
    required this.deviceName,
    this.client = '',
    this.nowPlaying,
    this.position,
    this.runtime,
    this.isPaused = false,
    this.supportsRemoteControl = false,
    this.lastActivity,
  });

  final String id;
  final String username;
  final String deviceName;

  /// The app on the far end — "Jellyfin Web", "mPlayer", "Infuse".
  final String client;

  /// What is on screen, or null for a session that is merely connected.
  ///
  /// An idle session is still worth listing: it is a device signed in, which
  /// is what an administrator looking for "who is using this" wants to see.
  final String? nowPlaying;

  final Duration? position;
  final Duration? runtime;
  final bool isPaused;

  /// Whether this client accepts being stopped or messaged.
  ///
  /// A session that does not is listed without the buttons rather than with
  /// buttons that quietly do nothing — most web players accept both, and a
  /// DLNA renderer accepts neither.
  final bool supportsRemoteControl;

  final DateTime? lastActivity;

  bool get isPlaying => nowPlaying != null;

  /// 0..1 through whatever is playing, or null when there is nothing to
  /// measure against.
  double? get progress {
    final at = position;
    final total = runtime;
    if (at == null || total == null || total <= Duration.zero) return null;
    return (at.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
  }
}

/// One of the server's maintenance jobs.
@immutable
class ScheduledTask {
  const ScheduledTask({
    required this.id,
    required this.name,
    this.description = '',
    this.state = TaskState.idle,
    this.progress,
    this.lastEndedAt,
    this.lastFailed = false,
  });

  final String id;
  final String name;
  final String description;
  final TaskState state;

  /// 0..100 while running, and null the rest of the time — a task that has
  /// not started is not at zero per cent, it is simply not running.
  final double? progress;

  final DateTime? lastEndedAt;

  /// Whether the last run ended in failure, which is the one thing about a
  /// finished task worth colouring.
  final bool lastFailed;

  bool get isRunning => state != TaskState.idle;
}

enum TaskState {
  idle,
  cancelling,
  running;

  static TaskState fromWire(String? name) => switch (name) {
    'Running' => TaskState.running,
    'Cancelling' => TaskState.cancelling,
    _ => TaskState.idle,
  };
}

/// An account on the server.
@immutable
class AdminUser {
  const AdminUser({
    required this.id,
    required this.name,
    this.isAdministrator = false,
    this.isDisabled = false,
    this.isHidden = false,
    this.lastActivity,
    this.imageTag,
  });

  final String id;
  final String name;
  final bool isAdministrator;
  final bool isDisabled;
  final bool isHidden;
  final DateTime? lastActivity;
  final String? imageTag;
}

/// The part of an account's policy these screens edit.
///
/// **Not the whole policy**, and that is deliberate: Jellyfin's has some forty
/// fields — access schedules, blocked tags, channel grants, SyncPlay — and a
/// phone is not where those get set well. The client reads the server's own
/// object fresh before every write and lays these fields over it, so anything
/// not modelled here survives untouched rather than being reset to a default.
@immutable
class UserPolicy {
  const UserPolicy({
    this.isAdministrator = false,
    this.isDisabled = false,
    this.isHidden = false,
    this.enableAllFolders = true,
    this.enabledFolders = const <String>[],
    this.enableMediaPlayback = true,
    this.enableVideoTranscoding = true,
    this.enableAudioTranscoding = true,
    this.enableRemuxing = true,
    this.enableContentDownloading = true,
    this.enableContentDeletion = false,
    this.enableCollectionManagement = false,
    this.enableRemoteAccess = true,
    this.remoteBitrateLimit = 0,
    this.maxActiveSessions = 0,
    this.maxParentalRating,
    this.maxParentalSubRating,
  });

  final bool isAdministrator;
  final bool isDisabled;

  /// Kept off the sign-in screen's list of faces.
  final bool isHidden;

  /// Every library, including ones added later — not the same as ticking
  /// every library there is today, which would leave a new one out.
  final bool enableAllFolders;

  /// Library ids, consulted only while [enableAllFolders] is false.
  final List<String> enabledFolders;

  final bool enableMediaPlayback;
  final bool enableVideoTranscoding;
  final bool enableAudioTranscoding;
  final bool enableRemuxing;
  final bool enableContentDownloading;
  final bool enableContentDeletion;
  final bool enableCollectionManagement;
  final bool enableRemoteAccess;

  /// Bits per second for a client outside the LAN. Zero is no limit.
  final int remoteBitrateLimit;

  /// Zero is no limit.
  final int maxActiveSessions;

  /// The highest rating score the account may see, or null for everything.
  final int? maxParentalRating;

  /// 10.11's finer step inside one score (a country's "12A" beside "12").
  /// Cleared whenever the rating is picked from here.
  final int? maxParentalSubRating;

  UserPolicy copyWith({
    bool? isAdministrator,
    bool? isDisabled,
    bool? isHidden,
    bool? enableAllFolders,
    List<String>? enabledFolders,
    bool? enableMediaPlayback,
    bool? enableVideoTranscoding,
    bool? enableAudioTranscoding,
    bool? enableRemuxing,
    bool? enableContentDownloading,
    bool? enableContentDeletion,
    bool? enableCollectionManagement,
    bool? enableRemoteAccess,
    int? remoteBitrateLimit,
    int? maxActiveSessions,
    // A rating can be set back to "no limit", which a plain nullable cannot
    // say, so the two travel as one optional record.
    ({int? score, int? subScore})? parentalRating,
  }) {
    return UserPolicy(
      isAdministrator: isAdministrator ?? this.isAdministrator,
      isDisabled: isDisabled ?? this.isDisabled,
      isHidden: isHidden ?? this.isHidden,
      enableAllFolders: enableAllFolders ?? this.enableAllFolders,
      enabledFolders: enabledFolders ?? this.enabledFolders,
      enableMediaPlayback: enableMediaPlayback ?? this.enableMediaPlayback,
      enableVideoTranscoding:
          enableVideoTranscoding ?? this.enableVideoTranscoding,
      enableAudioTranscoding:
          enableAudioTranscoding ?? this.enableAudioTranscoding,
      enableRemuxing: enableRemuxing ?? this.enableRemuxing,
      enableContentDownloading:
          enableContentDownloading ?? this.enableContentDownloading,
      enableContentDeletion:
          enableContentDeletion ?? this.enableContentDeletion,
      enableCollectionManagement:
          enableCollectionManagement ?? this.enableCollectionManagement,
      enableRemoteAccess: enableRemoteAccess ?? this.enableRemoteAccess,
      remoteBitrateLimit: remoteBitrateLimit ?? this.remoteBitrateLimit,
      maxActiveSessions: maxActiveSessions ?? this.maxActiveSessions,
      maxParentalRating: parentalRating == null
          ? maxParentalRating
          : parentalRating.score,
      maxParentalSubRating: parentalRating == null
          ? maxParentalSubRating
          : parentalRating.subScore,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is UserPolicy &&
      other.isAdministrator == isAdministrator &&
      other.isDisabled == isDisabled &&
      other.isHidden == isHidden &&
      other.enableAllFolders == enableAllFolders &&
      listEquals(other.enabledFolders, enabledFolders) &&
      other.enableMediaPlayback == enableMediaPlayback &&
      other.enableVideoTranscoding == enableVideoTranscoding &&
      other.enableAudioTranscoding == enableAudioTranscoding &&
      other.enableRemuxing == enableRemuxing &&
      other.enableContentDownloading == enableContentDownloading &&
      other.enableContentDeletion == enableContentDeletion &&
      other.enableCollectionManagement == enableCollectionManagement &&
      other.enableRemoteAccess == enableRemoteAccess &&
      other.remoteBitrateLimit == remoteBitrateLimit &&
      other.maxActiveSessions == maxActiveSessions &&
      other.maxParentalRating == maxParentalRating &&
      other.maxParentalSubRating == maxParentalSubRating;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    isAdministrator,
    isDisabled,
    isHidden,
    enableAllFolders,
    Object.hashAll(enabledFolders),
    enableMediaPlayback,
    enableVideoTranscoding,
    enableAudioTranscoding,
    enableRemuxing,
    enableContentDownloading,
    enableContentDeletion,
    enableCollectionManagement,
    enableRemoteAccess,
    remoteBitrateLimit,
    maxActiveSessions,
    maxParentalRating,
    maxParentalSubRating,
  ]);
}

/// One account, with what it is allowed to do.
@immutable
class AdminUserDetail {
  const AdminUserDetail({
    required this.user,
    required this.policy,
    this.hasPassword = true,
  });

  final AdminUser user;
  final UserPolicy policy;

  /// False for an account anyone can sign in to by tapping its name.
  final bool hasPassword;
}

/// A library, as the access list names it.
@immutable
class AdminLibrary {
  const AdminLibrary({required this.id, required this.name, this.kind = ''});

  final String id;
  final String name;

  /// The server's `CollectionType` — movies, tvshows, music — or empty.
  final String kind;
}

/// A rating the parental limit can be set to.
@immutable
class ParentalRatingOption {
  const ParentalRatingOption({
    required this.name,
    required this.score,
    this.subScore,
  });

  /// "PG-13", "FSK-16", "TV-MA".
  final String name;
  final int score;
  final int? subScore;
}

/// A client that has signed in and been remembered.
@immutable
class AdminDevice {
  const AdminDevice({
    required this.id,
    required this.name,
    this.appName = '',
    this.appVersion = '',
    this.username = '',
    this.lastSeen,
  });

  final String id;
  final String name;
  final String appName;
  final String appVersion;
  final String username;
  final DateTime? lastSeen;
}

/// One line of the server's activity log.
@immutable
class ActivityEntry {
  const ActivityEntry({
    required this.id,
    required this.name,
    this.overview = '',
    this.type = '',
    this.severity = ActivitySeverity.information,
    this.at,
    this.userId = '',
  });

  final String id;
  final String name;

  /// The second line, where the server wrote one. Often empty.
  final String overview;

  /// The server's own event name — `AuthenticationSucceeded`,
  /// `VideoPlayback`. Kept unmapped: a client that only understands a dozen
  /// of them should still show the rest.
  final String type;

  final ActivitySeverity severity;
  final DateTime? at;

  /// The account that caused it. Empty for what the server did by itself
  /// — a scheduled scan, a plugin update.
  final String userId;
}

enum ActivitySeverity {
  information,
  warning,
  error;

  static ActivitySeverity fromWire(String? name) => switch (name) {
    'Warning' => ActivitySeverity.warning,
    'Error' || 'Critical' || 'Fatal' => ActivitySeverity.error,
    _ => ActivitySeverity.information,
  };
}

/// An installed plugin.
@immutable
class ServerPlugin {
  const ServerPlugin({
    required this.id,
    required this.name,
    required this.version,
    this.description = '',
    this.status = PluginStatus.active,
    this.canUninstall = true,
  });

  final String id;
  final String name;

  /// Needed as well as the id: the enable, disable and uninstall routes are
  /// all addressed by *both*, because a server can hold two versions of one
  /// plugin at once.
  final String version;

  final String description;
  final PluginStatus status;

  /// False for a plugin the server ships with, which cannot be removed.
  final bool canUninstall;

  bool get isEnabled => status == PluginStatus.active;
}

enum PluginStatus {
  active,
  disabled,

  /// Installed but not loaded — a restart away from working, or broken.
  restartPending,
  notSupported,
  malfunctioned,
  superceded;

  static PluginStatus fromWire(String? name) => switch (name) {
    'Disabled' => PluginStatus.disabled,
    'RestartRequired' => PluginStatus.restartPending,
    'NotSupported' => PluginStatus.notSupported,
    'Malfunctioned' => PluginStatus.malfunctioned,
    'Superceded' => PluginStatus.superceded,
    _ => PluginStatus.active,
  };
}

/// A library as the server's configuration holds it.
@immutable
class AdminLibraryFolder {
  const AdminLibraryFolder({
    required this.name,
    required this.itemId,
    this.kind = '',
    this.paths = const <String>[],
    this.refreshProgress,
  });

  /// The key the rename and delete routes take.
  final String name;

  /// The key a refresh takes.
  final String itemId;

  /// `movies`, `tvshows`, `music`, `boxsets` — or empty for mixed content.
  final String kind;

  /// Folders on the server's disk, as the server sees them.
  final List<String> paths;

  /// 0..100 while the library is being scanned, otherwise null.
  final double? refreshProgress;
}

/// How deep a refresh goes — the three choices Jellyfin's own dialog offers.
enum MetadataRefresh {
  /// Look for new and changed files; leave the metadata that is there.
  scan,

  /// Also fetch what is missing from the metadata providers.
  missing,

  /// Throw the metadata away and fetch it all again. Images are kept.
  replaceAll,
}

/// The handful of an item's fields worth editing from a phone.
@immutable
class ItemMetadata {
  const ItemMetadata({
    this.name = '',
    this.originalTitle = '',
    this.sortName = '',
    this.year,
    this.overview = '',
    this.officialRating = '',
    this.genres = const <String>[],
    this.tags = const <String>[],
    this.locked = false,
  });

  final String name;
  final String originalTitle;

  /// Empty means the server derives it from the name.
  final String sortName;
  final int? year;
  final String overview;

  /// The certificate as text — "PG-13", "16+". Empty for none.
  final String officialRating;
  final List<String> genres;
  final List<String> tags;

  /// Whether the server leaves this item alone on a refresh. Worth offering
  /// beside an edit: a hand-fixed title is otherwise undone by the next scan.
  final bool locked;

  ItemMetadata copyWith({
    String? name,
    String? originalTitle,
    String? sortName,
    // A year can be cleared, which a plain nullable cannot say.
    ({int? value})? year,
    String? overview,
    String? officialRating,
    List<String>? genres,
    List<String>? tags,
    bool? locked,
  }) {
    return ItemMetadata(
      name: name ?? this.name,
      originalTitle: originalTitle ?? this.originalTitle,
      sortName: sortName ?? this.sortName,
      year: year == null ? this.year : year.value,
      overview: overview ?? this.overview,
      officialRating: officialRating ?? this.officialRating,
      genres: genres ?? this.genres,
      tags: tags ?? this.tags,
      locked: locked ?? this.locked,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ItemMetadata &&
      other.name == name &&
      other.originalTitle == originalTitle &&
      other.sortName == sortName &&
      other.year == year &&
      other.overview == overview &&
      other.officialRating == officialRating &&
      listEquals(other.genres, genres) &&
      listEquals(other.tags, tags) &&
      other.locked == locked;

  @override
  int get hashCode => Object.hash(
    name,
    originalTitle,
    sortName,
    year,
    overview,
    officialRating,
    Object.hashAll(genres),
    Object.hashAll(tags),
    locked,
  );
}

/// Everything the administration screens can ask a server to do.
abstract class ServerAdmin {
  /// What the server is and whether it can be restarted from here.
  Future<ServerSystemInfo> systemInfo();

  /// Who is connected, playing or idle.
  Future<List<AdminSession>> sessions();

  /// Stops whatever [sessionId] is playing.
  Future<void> stopSession(String sessionId);

  /// Puts a message on [sessionId]'s screen.
  Future<void> messageSession(
    String sessionId, {
    required String header,
    required String text,
  });

  Future<List<ScheduledTask>> tasks();

  Future<void> runTask(String taskId);

  Future<void> stopTask(String taskId);

  /// Starts a scan of every library.
  ///
  /// Returns as soon as the server has accepted it. A scan takes minutes to
  /// hours and reports its progress as a scheduled task, which is where the
  /// screen watches it — waiting on this call would be waiting for nothing.
  Future<void> scanLibraries();

  Future<List<AdminUser>> users();

  /// Turns an account off without deleting it.
  ///
  /// The policy has to be **read, changed and written whole**: the route
  /// replaces the object rather than patching it, so posting one field would
  /// silently reset every other permission the account has.
  Future<void> setUserDisabled(String userId, {required bool disabled});

  /// One account and its policy.
  Future<AdminUserDetail> user(String userId);

  /// Writes [policy] over the account's current one.
  ///
  /// The server's policy is **read fresh and written whole**, with only the
  /// fields [UserPolicy] models replaced. Posting the model alone would reset
  /// every field it does not carry — access schedules, blocked tags, channel
  /// grants — to the server's defaults.
  Future<void> setUserPolicy(String userId, UserPolicy policy);

  /// Makes an account and answers with it. [password] may be empty, which
  /// leaves an account anyone can sign in to by tapping its name.
  Future<AdminUser> createUser(String name, String password);

  /// Deletes an account, its playlists and every session it has open.
  Future<void> deleteUser(String userId);

  /// Sets another account's password without knowing the old one, which only
  /// an administrator may do. Empty removes the password.
  ///
  /// Every session that account had open is signed out by the server.
  Future<void> setUserPassword(String userId, String password);

  /// The libraries an account can be granted, hidden ones left out.
  Future<List<AdminLibrary>> libraries();

  /// The ratings the server knows, lowest score first, one per score.
  Future<List<ParentalRatingOption>> parentalRatings();

  /// Every remembered device, or only [userId]'s.
  Future<List<AdminDevice>> devices({String? userId});

  Future<void> deleteDevice(String deviceId);

  /// The newest [limit] entries, or only those [user] caused.
  ///
  /// The server filters by name from 10.11; an older one ignores the filter,
  /// so the entries are also kept to the account's id here — which on such a
  /// server means "this account's among the newest [limit]", not all of them.
  Future<List<ActivityEntry>> activity({
    int limit = 50,
    ({String id, String name})? user,
  });

  /// Every library, with the folders on disk it reads.
  Future<List<AdminLibraryFolder>> libraryFolders();

  /// Rescans one library, folder or item. Returns once the server has queued
  /// it; the work shows up as a running task.
  Future<void> refreshItem(String itemId, MetadataRefresh mode);

  /// Renames a library. Addressed by name: that is how the server keys them.
  Future<void> renameLibrary(String name, String newName);

  /// Removes a library from the server. **The files stay on disk**; only the
  /// library, its metadata and its watch state go.
  Future<void> deleteLibrary(String name);

  /// Deletes an item **and its files on disk**.
  Future<void> deleteItem(String itemId);

  /// The fields of [itemId] the metadata editor shows.
  Future<ItemMetadata> itemMetadata(String itemId);

  /// Writes [metadata] over [itemId].
  ///
  /// The item is read fresh and written **whole**, like a user policy: the
  /// route replaces every field it is sent, and a field it is not sent is
  /// cleared — cast, provider ids, dates, studios.
  Future<void> setItemMetadata(String itemId, ItemMetadata metadata);

  Future<List<ServerPlugin>> plugins();

  Future<void> setPluginEnabled(
    String pluginId,
    String version, {
    required bool enabled,
  });

  Future<void> uninstallPlugin(String pluginId, String version);

  /// Renames the server.
  ///
  /// Same rule as the user policy: the configuration is read, changed and
  /// written whole, because the route replaces it.
  Future<void> setServerName(String name);

  /// Asks the server to restart itself. It stops answering immediately.
  Future<void> restartServer();

  /// Asks the server to stop. **Nothing here can start it again** — that is
  /// the machine's job, which is why the button behind this is confirmed.
  Future<void> shutdownServer();

  Future<void> dispose();
}
