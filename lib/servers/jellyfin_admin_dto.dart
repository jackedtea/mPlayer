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

import 'jellyfin_dto.dart' show ticksToPosition;
import 'server_admin.dart';

ServerSystemInfo systemInfoFromJson(Map<String, dynamic> json) {
  return ServerSystemInfo(
    name: json['ServerName'] as String? ?? '',
    version: json['Version'] as String? ?? '',
    operatingSystem: json['OperatingSystem'] as String? ?? '',
    // Jellyfin 10.9 renamed this; both spellings are in the wild and neither
    // is worth losing the line over.
    architecture:
        json['SystemArchitecture'] as String? ?? json['Architecture'] as String? ?? '',
    canRestart: json['CanSelfRestart'] as bool? ?? false,
    // Removed from the payload in 10.9, where every server that can restart
    // can also stop. Defaulting to the restart answer keeps the button
    // present where it works instead of hiding it on every modern server.
    canShutdown:
        json['CanSelfShutdown'] as bool? ?? json['CanSelfRestart'] as bool? ?? false,
    startupWizardCompleted: json['StartupWizardCompleted'] as bool? ?? true,
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
    runtime:
        nowPlaying is Map ? ticksToPosition(nowPlaying['RunTimeTicks']) : null,
    isPaused: playState is Map && playState['IsPaused'] == true,
    supportsRemoteControl: json['SupportsRemoteControl'] as bool? ?? false,
    lastActivity: DateTime.tryParse(json['LastActivityDate'] as String? ?? ''),
  );
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

  return <String>[series, code, name]
      .where((s) => s.isNotEmpty)
      .join(' · ');
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
    lastFailed: lastResult is Map &&
        lastResult['Status'] != null &&
        lastResult['Status'] != 'Completed',
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
    overview: json['Overview'] as String? ?? json['ShortOverview'] as String? ?? '',
    type: json['Type'] as String? ?? '',
    severity: ActivitySeverity.fromWire(json['Severity'] as String?),
    at: DateTime.tryParse(json['Date'] as String? ?? ''),
    // Present only on an entry a user caused; a scheduled scan has none.
    username: json['UserId'] as String? ?? '',
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
