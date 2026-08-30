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
    this.username = '',
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
  final String username;
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

  Future<List<AdminDevice>> devices();

  Future<void> deleteDevice(String deviceId);

  Future<List<ActivityEntry>> activity({int limit = 50});

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
