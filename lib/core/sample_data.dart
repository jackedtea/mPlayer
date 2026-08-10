// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';

import 'models/media_models.dart';

/// Placeholder content mirroring the design canvas, so the screens can be laid
/// out and reviewed before the real sources exist.
///
/// TEMPORARY. Each list is replaced by a repository-backed Riverpod provider
/// as its source lands (local index, SMB, WebDAV, Jellyfin). Nothing outside
/// the presentation layer may depend on this file.
abstract final class SampleData {
  static const resumeShelf = <ResumeItem>[
    ResumeItem(
      id: 'r1',
      title: 'The Harbour Line',
      sourceKind: SourceKind.smb,
      sourceLabel: 'NAS',
      remaining: '41m left',
      quality: '4K HDR',
      progress: 0.62,
    ),
    ResumeItem(
      id: 'r2',
      title: 'Nightfall — S02E04',
      sourceKind: SourceKind.device,
      sourceLabel: 'Device',
      remaining: '12m left',
      quality: '1080p',
      progress: 0.78,
    ),
    ResumeItem(
      id: 'r3',
      title: 'Coastline Documentary',
      sourceKind: SourceKind.webdav,
      sourceLabel: 'WebDAV',
      remaining: '1h 05m left',
      quality: '1080p',
      progress: 0.24,
    ),
  ];

  static const deviceShortcuts = <DeviceShortcut>[
    DeviceShortcut(
      title: 'Internal storage',
      subtitle: '252 videos · 84.2 GB',
      icon: Icons.sd_storage_rounded,
    ),
    DeviceShortcut(
      title: 'Camera & screen recordings',
      subtitle: '38 videos',
      icon: Icons.photo_library_rounded,
    ),
    DeviceShortcut(
      title: 'Downloads',
      subtitle: '6 videos · available offline',
      icon: Icons.download_for_offline_rounded,
    ),
  ];

  static const networkSources = <MediaSourceRef>[
    MediaSourceRef(
      id: 'nas',
      kind: SourceKind.smb,
      name: 'NAS',
      detail: 'smb://192.168.1.10 · 3 shares',
    ),
    MediaSourceRef(
      id: 'nextcloud',
      kind: SourceKind.webdav,
      name: 'Nextcloud',
      detail: 'dav.home.lan · offline',
      online: false,
    ),
  ];

  static const jellyfinSource = MediaSourceRef(
    id: 'jellyfin',
    kind: SourceKind.jellyfin,
    name: 'Jellyfin · media.home.lan',
    detail: 'media.home.lan',
  );

  static const thisDeviceSource = MediaSourceRef(
    id: 'device',
    kind: SourceKind.device,
    name: 'This device',
    detail: '252 videos indexed · instant',
  );

  static const recentSearches = <RecentSearch>[
    RecentSearch('harbour'),
    RecentSearch('1080p 2019'),
  ];

  static const searchScopes = <SearchScope>[
    SearchScope(
      source: thisDeviceSource,
      capability: '252 videos indexed · instant',
      enabled: true,
    ),
    SearchScope(
      source: MediaSourceRef(
        id: 'nas',
        kind: SourceKind.smb,
        name: 'NAS · SMB',
        detail: 'smb://192.168.1.10',
      ),
      capability: 'Filename search, walks folders',
      enabled: true,
    ),
    SearchScope(
      source: MediaSourceRef(
        id: 'nextcloud',
        kind: SourceKind.webdav,
        name: 'Nextcloud · WebDAV',
        detail: 'dav.home.lan',
        online: false,
      ),
      capability: 'Offline — will be skipped',
      enabled: false,
    ),
    SearchScope(
      source: jellyfinSource,
      capability: 'Titles, people, genres, episodes',
      enabled: true,
    ),
  ];
}
