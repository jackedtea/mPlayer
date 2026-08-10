// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';

/// Where a playable item lives.
///
/// The design's rule is that one player screen serves every kind; only the
/// source line and the availability of server-only features differ. This enum
/// is what the UI switches on to render badges, icons and status.
enum SourceKind {
  device(label: 'Device', icon: Icons.smartphone_rounded),
  smb(label: 'SMB', icon: Icons.lan_rounded),
  webdav(label: 'WebDAV', icon: Icons.cloud_rounded),
  nfs(label: 'NFS', icon: Icons.dns_rounded),
  jellyfin(label: 'Jellyfin', icon: Icons.dns_rounded);

  const SourceKind({required this.label, required this.icon});

  final String label;
  final IconData icon;

  bool get isNetwork => this != SourceKind.device;
  bool get isServer => this == SourceKind.jellyfin;
}

/// A configured place to read media from: this device, a share, or a server.
@immutable
class MediaSourceRef {
  const MediaSourceRef({
    required this.id,
    required this.kind,
    required this.name,
    required this.detail,
    this.online = true,
  });

  final String id;
  final SourceKind kind;

  /// Display name — "NAS", "Nextcloud", "This device".
  final String name;

  /// Supporting line — "smb://192.168.1.10/media · 2 shares".
  final String detail;

  /// Reachability. Offline sources stay listed and are skipped, never hidden;
  /// a dead source must not block local playback.
  final bool online;
}

/// A row in the "This device" section — a shortcut into local storage.
@immutable
class DeviceShortcut {
  const DeviceShortcut({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;
}

/// An item on the Continue-watching shelf.
@immutable
class ResumeItem {
  const ResumeItem({
    required this.id,
    required this.title,
    required this.sourceKind,
    required this.sourceLabel,
    required this.remaining,
    required this.quality,
    required this.progress,
  }) : assert(progress >= 0 && progress <= 1);

  final String id;
  final String title;
  final SourceKind sourceKind;

  /// Badge text — "NAS", "Device", "WebDAV".
  final String sourceLabel;

  /// "41m left".
  final String remaining;

  /// "4K HDR".
  final String quality;

  /// 0..1, drawn as the 4px bar pinned to the bottom of the thumbnail.
  final double progress;

  String get subtitle => '$remaining · $quality';
}

/// A previously run query on the Search tab.
@immutable
class RecentSearch {
  const RecentSearch(this.query);
  final String query;
}

/// One toggleable target in the Search tab's "Where to look" list.
@immutable
class SearchScope {
  const SearchScope({
    required this.source,
    required this.capability,
    required this.enabled,
  });

  final MediaSourceRef source;

  /// What searching this source actually does — "Filename search, walks
  /// folders" vs "Titles, people, genres, episodes".
  final String capability;

  final bool enabled;

  SearchScope copyWith({bool? enabled}) => SearchScope(
        source: source,
        capability: capability,
        enabled: enabled ?? this.enabled,
      );
}
