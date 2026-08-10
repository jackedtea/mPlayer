// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';

import 'models/library_models.dart';
import 'models/media_models.dart';

/// Placeholder content for the browse, library, detail, download and search
/// screens, mirroring the design canvas.
///
/// TEMPORARY, exactly like `SampleData`. Each list is replaced by its real
/// source as that source lands: `SampleLibrary.shareListing` by the SMB/WebDAV
/// drivers, everything else by the Jellyfin client. Nothing outside the
/// presentation layer may depend on this file.
abstract final class SampleLibrary {
  // ---------------------------------------------------------------- 1b

  static const breadcrumb = <String>['media', 'films', '2024'];

  static const shareMeta = '18 folders · 62 files · 1.4 TB';

  static const shareListing = <BrowseEntry>[
    BrowseEntry(
      name: 'Anthology',
      kind: BrowseEntryKind.folder,
      detail: '12 items',
    ),
    BrowseEntry(
      name: 'Short films',
      kind: BrowseEntryKind.folder,
      detail: '31 items',
    ),
    BrowseEntry(
      name: 'The Harbour Line (2024) 2160p HDR.mkv',
      kind: BrowseEntryKind.video,
      detail: '18.4 GB · HEVC · 2h 16m',
    ),
    BrowseEntry(
      name: 'The Harbour Line (2024).en.srt',
      kind: BrowseEntryKind.subtitle,
      detail: '84 KB · SubRip',
    ),
    BrowseEntry(
      name: 'Coastline (2019) 1080p.avi',
      kind: BrowseEntryKind.video,
      detail: '4.1 GB · MPEG-4 · 1h 48m — needs transcoding',
      needsTranscode: true,
    ),
    BrowseEntry(
      name: 'Nightfall S02E04.mkv',
      kind: BrowseEntryKind.video,
      detail: '2.8 GB · HEVC · 44m',
    ),
  ];

  // ---------------------------------------------------------------- 1d

  static const serverName = 'Jellyfin';
  static const serverHost = 'media.home.lan';
  static const serverUser = 'minh';

  static const libraryFilters = <String>[
    'All',
    'Movies',
    'Shows',
    'Music',
    'Live TV',
  ];

  static const nextUp = <ResumeItem>[
    ResumeItem(
      id: 'n1',
      title: 'Nightfall — S02E05',
      sourceKind: SourceKind.jellyfin,
      sourceLabel: 'Jellyfin',
      remaining: '44m left',
      quality: '1080p',
      progress: 0.05,
    ),
    ResumeItem(
      id: 'n2',
      title: 'The Cartographer',
      sourceKind: SourceKind.jellyfin,
      sourceLabel: 'Jellyfin',
      remaining: '1h 12m left',
      quality: '4K HDR',
      progress: 0.34,
    ),
  ];

  static const recentlyAdded = <LibraryItem>[
    LibraryItem(id: 'a1', title: 'The Harbour Line', year: '2024'),
    LibraryItem(id: 'a2', title: 'Salt Flats', year: '2023'),
    LibraryItem(id: 'a3', title: 'Meridian', year: '2024'),
    LibraryItem(id: 'a4', title: 'Low Tide', year: '2022'),
  ];

  static const librarySections = <LibrarySection>[
    LibrarySection(name: 'Movies', itemCount: 412, icon: Icons.movie_rounded),
    LibrarySection(name: 'Shows', itemCount: 68, icon: Icons.live_tv_rounded),
    LibrarySection(
      name: 'Music',
      itemCount: 1204,
      icon: Icons.library_music_rounded,
    ),
    LibrarySection(
      name: 'Podcasts',
      itemCount: 37,
      icon: Icons.podcasts_rounded,
    ),
  ];

  // ---------------------------------------------------------------- 1e

  static const movieLibraryMeta = '412 items · 2.1 TB';

  static const movieLibrary = <LibraryItem>[
    LibraryItem(id: 'm1', title: 'The Harbour Line', year: '2024'),
    LibraryItem(id: 'm2', title: 'Salt Flats', year: '2023'),
    LibraryItem(id: 'm3', title: 'Meridian', year: '2024'),
    LibraryItem(id: 'm4', title: 'Low Tide', year: '2022', watched: true),
    LibraryItem(id: 'm5', title: 'The Cartographer', year: '2021'),
    LibraryItem(id: 'm6', title: 'Northerly', year: '2020', watched: true),
    LibraryItem(id: 'm7', title: 'Glasshouse', year: '2023'),
    LibraryItem(id: 'm8', title: 'Ferrous', year: '2019'),
    LibraryItem(id: 'm9', title: 'Quiet Harbour', year: '2024'),
  ];

  // ---------------------------------------------------------------- 1f

  static const movieDetail = MovieDetail(
    title: 'The Harbour Line',
    year: '2024',
    rating: '8.1',
    runtime: '2h 16m',
    certificate: 'PG-13',
    quality: '4K HDR',
    overview:
        'A dock worker inherits a derelict ferry and, with it, a route nobody '
        'has sailed in thirty years. As the harbour town turns against the '
        'idea, she discovers why the line was closed — and what the tide has '
        'been keeping quiet ever since.',
    genres: <String>['Drama', 'Mystery', 'Sea'],
    info: <MediaInfoRow>[
      MediaInfoRow(label: 'Video', value: 'HEVC · 3840×2160 · HDR10 · 24 fps'),
      MediaInfoRow(label: 'Audio', value: 'TrueHD 7.1 · English'),
      MediaInfoRow(label: 'Playback', value: 'Direct play', isSuccess: true),
    ],
    cast: <CastMember>[
      CastMember(name: 'Ada Fenwick', role: 'Mara'),
      CastMember(name: 'Ilan Roche', role: 'Teodor'),
      CastMember(name: 'Suri Chandran', role: 'Harbourmaster'),
      CastMember(name: 'Bo Nilsen', role: 'Jonas'),
    ],
    watchedFraction: 0.7,
    resumeLabel: 'Resume · 41m left',
  );

  static const watchedLabel = '1h 35m watched';

  // ---------------------------------------------------------------- 1g

  static const series = SeriesDetail(
    title: 'Nightfall',
    summary: '3 seasons · 28 episodes · 6 unwatched',
    seasons: <Season>[
      Season(
        name: 'Season 1',
        episodes: <Episode>[
          Episode(
            number: 1,
            title: 'The Long Dark',
            description:
                'A power cut strands the valley for a night, and by morning '
                'one house has not switched its lights back on.',
            meta: '48m · watched',
            progress: 1,
          ),
          Episode(
            number: 2,
            title: 'Signal',
            description:
                'Reception returns to the ridge, carrying a broadcast that '
                'nobody in town admits to recording.',
            meta: '44m · 12m left',
            progress: 0.73,
          ),
          Episode(
            number: 3,
            title: 'Undertow',
            description:
                'The search party splits at the waterline and comes back with '
                'two different accounts of the same hour.',
            meta: '46m · new',
          ),
        ],
      ),
      Season(
        name: 'Season 2',
        episodes: <Episode>[
          Episode(
            number: 1,
            title: 'Landfall',
            description:
                'A year on, the storm returns on schedule and so does the '
                'question everyone stopped asking.',
            meta: '52m · watched',
            progress: 1,
          ),
          Episode(
            number: 2,
            title: 'Cold Front',
            description:
                'The new sergeant reopens a file that was closed twice, for '
                'two incompatible reasons.',
            meta: '47m · new',
          ),
        ],
      ),
      Season(
        name: 'Season 3',
        episodes: <Episode>[
          Episode(
            number: 1,
            title: 'Slack Water',
            description:
                'Nothing moves for six hours between the tides, which is '
                'exactly long enough.',
            meta: '49m · new',
          ),
        ],
      ),
    ],
  );

  // ---------------------------------------------------------------- 1i

  static const downloads = <DownloadItem>[
    DownloadItem(
      title: 'The Harbour Line (2024)',
      status: DownloadStatus.inProgress,
      detail: '412 MB of 1.4 GB',
      progress: 0.29,
    ),
    DownloadItem(
      title: 'Nightfall — S02E04',
      status: DownloadStatus.completed,
      detail: 'Available offline · expires in 27 days',
      progress: 1,
    ),
    DownloadItem(
      title: 'Salt Flats (2023)',
      status: DownloadStatus.queued,
      detail: 'Queued · waiting for Wi-Fi',
    ),
  ];

  // ---------------------------------------------------------------- 1n

  static const resultsSummary = '14 results · device 3 · NAS 6 · server 5';

  static const resultGroups = <SearchResultGroup>[
    SearchResultGroup(
      sourceName: 'Jellyfin · media.home.lan',
      sourceKind: SourceKind.jellyfin,
      total: 5,
      hits: <SearchHit>[
        SearchHit(
          title: 'The Harbour Line',
          subtitle: '2024 · Movie',
          kind: SearchHitKind.poster,
        ),
        SearchHit(
          title: 'Quiet Harbour',
          subtitle: '2024 · Movie',
          kind: SearchHitKind.poster,
        ),
        SearchHit(
          title: 'Harbour Watch',
          subtitle: '2 seasons · 16 episodes',
          kind: SearchHitKind.series,
        ),
      ],
    ),
    SearchResultGroup(
      sourceName: 'NAS · SMB',
      sourceKind: SourceKind.smb,
      total: 6,
      hits: <SearchHit>[
        SearchHit(
          title: 'The Harbour Line (2024) 2160p HDR.mkv',
          subtitle: '18.4 GB · /media/films/2024',
          kind: SearchHitKind.file,
        ),
        SearchHit(
          title: 'harbour-b-roll.mov',
          subtitle: '2.2 GB · /media/raw',
          kind: SearchHitKind.file,
        ),
        SearchHit(
          title: 'Harbour archive',
          subtitle: '31 items · /media/archive',
          kind: SearchHitKind.folder,
        ),
      ],
    ),
    SearchResultGroup(
      sourceName: 'This device',
      sourceKind: SourceKind.device,
      total: 3,
      hits: <SearchHit>[
        SearchHit(
          title: 'harbour_trailer.mp4',
          subtitle: '184 MB · Downloads',
          kind: SearchHitKind.file,
        ),
        SearchHit(
          title: 'harbour_cut_02.mp4',
          subtitle: '1.1 GB · Movies',
          kind: SearchHitKind.file,
        ),
      ],
    ),
  ];
}
