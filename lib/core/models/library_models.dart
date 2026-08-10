// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';

import 'media_models.dart';

/// What a row in a folder listing is.
enum BrowseEntryKind { folder, video, subtitle, other }

/// One row in a share or folder listing (screen 1b).
@immutable
class BrowseEntry {
  const BrowseEntry({
    required this.name,
    required this.kind,
    this.detail = '',
    this.needsTranscode = false,
  });

  final String name;
  final BrowseEntryKind kind;

  /// "18.4 GB · HEVC · 2h 16m" for a video, "12 items" for a folder.
  final String detail;

  /// Flagged in the subtitle so the user knows before opening that the file
  /// will not direct-play.
  final bool needsTranscode;

  bool get isPlayable => kind == BrowseEntryKind.video;
}

/// A poster-shaped item in a library grid or a "recently added" shelf.
@immutable
class LibraryItem {
  const LibraryItem({
    required this.id,
    required this.title,
    required this.year,
    this.watched = false,
  });

  final String id;
  final String title;
  final String year;
  final bool watched;
}

/// A top-level library on a server (screen 1d).
@immutable
class LibrarySection {
  const LibrarySection({
    required this.name,
    required this.itemCount,
    required this.icon,
  });

  final String name;
  final int itemCount;
  final IconData icon;
}

/// A track/stream summary row inside the media-info card (screen 1f).
@immutable
class MediaInfoRow {
  const MediaInfoRow({
    required this.label,
    required this.value,
    this.isSuccess = false,
  });

  final String label;
  final String value;

  /// "Direct play" renders in the success green; "Transcoding" does not.
  final bool isSuccess;
}

/// A person in the cast strip.
@immutable
class CastMember {
  const CastMember({required this.name, required this.role});

  final String name;
  final String role;
}

/// Full metadata behind screen 1f.
@immutable
class MovieDetail {
  const MovieDetail({
    required this.title,
    required this.year,
    required this.rating,
    required this.runtime,
    required this.certificate,
    required this.quality,
    required this.overview,
    required this.genres,
    required this.info,
    required this.cast,
    this.watchedFraction = 0,
    this.resumeLabel,
  });

  final String title;
  final String year;

  /// "8.1" — shown beside the star.
  final String rating;

  final String runtime;

  /// "PG-13", drawn in an outlined box.
  final String certificate;

  /// "4K HDR".
  final String quality;

  final String overview;
  final List<String> genres;
  final List<MediaInfoRow> info;
  final List<CastMember> cast;

  /// 0..1; drives the progress bar under the action row.
  final double watchedFraction;

  /// "Resume · 41m left". Null means the item has never been started, and the
  /// primary action reads "Play" instead.
  final String? resumeLabel;

  bool get isStarted => watchedFraction > 0 && resumeLabel != null;
}

/// One episode row (screen 1g).
@immutable
class Episode {
  const Episode({
    required this.number,
    required this.title,
    required this.description,
    required this.meta,
    this.progress = 0,
  });

  final int number;
  final String title;
  final String description;

  /// "48m · watched" / "44m · 12m left" / "46m · new".
  final String meta;

  /// 0..1. Zero draws no bar at all — an unwatched episode has no progress.
  final double progress;
}

@immutable
class Season {
  const Season({required this.name, required this.episodes});

  final String name;
  final List<Episode> episodes;
}

@immutable
class SeriesDetail {
  const SeriesDetail({
    required this.title,
    required this.summary,
    required this.seasons,
  });

  final String title;

  /// "3 seasons · 28 episodes · 6 unwatched".
  final String summary;

  final List<Season> seasons;
}

/// Lifecycle of an offline copy (screen 1i).
enum DownloadStatus { inProgress, completed, queued }

@immutable
class DownloadItem {
  const DownloadItem({
    required this.title,
    required this.status,
    required this.detail,
    this.progress = 0,
  });

  final String title;
  final DownloadStatus status;

  /// "412 MB of 1.4 GB" / "Available offline · expires in 27 days" /
  /// "Queued · waiting for Wi-Fi".
  final String detail;

  final double progress;
}

/// What kind of hit a search result is, which decides how it is drawn.
enum SearchHitKind { poster, series, file, folder }

@immutable
class SearchHit {
  const SearchHit({
    required this.title,
    required this.subtitle,
    required this.kind,
  });

  final String title;

  /// "18.4 GB · /media/films" for a file, "2024 · Movie" for a poster.
  final String subtitle;

  final SearchHitKind kind;
}

/// Results from one source, kept separate because the design groups by source
/// rather than merging into one ranked list — a filename hit on a NAS and a
/// metadata hit on Jellyfin are not comparable.
@immutable
class SearchResultGroup {
  const SearchResultGroup({
    required this.sourceName,
    required this.sourceKind,
    required this.total,
    required this.hits,
  });

  final String sourceName;
  final SourceKind sourceKind;

  /// Total matches, which may exceed [hits] — the group ends with a
  /// "Show N more" affordance.
  final int total;

  final List<SearchHit> hits;

  int get hiddenCount => total - hits.length;
}
