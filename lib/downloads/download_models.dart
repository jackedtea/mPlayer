// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/foundation.dart';

import '../servers/media_library_source.dart';

/// Where an offline copy is in its life.
///
/// `paused` and `failed` both keep the partial file: either can be resumed
/// from the byte it stopped at. Only a delete throws the bytes away.
enum DownloadStatus {
  queued,
  downloading,
  paused,
  failed,
  completed;

  /// Waiting its turn or under way — what the engine picks work from.
  bool get isActive => this == queued || this == downloading;

  static DownloadStatus fromName(String? name) => DownloadStatus.values
      .firstWhere((s) => s.name == name, orElse: () => DownloadStatus.queued);
}

/// One server item kept on this device.
///
/// Keyed by profile *and* item: two servers can hand out the same GUID, and
/// a copy belongs to the server it was taken from. What a listing needs to
/// draw the row is copied in here, so the Downloads tab draws with no server
/// signed in at all.
///
/// Never holds a token. The URL is asked for again each time the bytes are
/// fetched, from whichever session is signed in to [profileId].
@immutable
class DownloadEntry {
  const DownloadEntry({
    required this.profileId,
    required this.itemId,
    required this.title,
    required this.createdAt,
    this.kind = ServerItemKind.unknown,
    this.seriesId,
    this.seriesTitle,
    this.seasonNumber,
    this.episodeNumber,
    this.year,
    this.runtime,
    this.status = DownloadStatus.queued,
    this.receivedBytes = 0,
    this.totalBytes,
    this.fileName,
    this.error,
  });

  /// The copy a press of Download on [item] starts.
  factory DownloadEntry.fromItem(
    String profileId,
    ServerItem item, {
    DateTime? now,
  }) =>
      DownloadEntry(
        profileId: profileId,
        itemId: item.id,
        title: item.title,
        createdAt: now ?? DateTime.now(),
        kind: item.kind,
        seriesId: item.seriesId,
        seriesTitle: item.seriesTitle,
        seasonNumber: item.seasonNumber,
        episodeNumber: item.episodeNumber,
        year: item.year,
        runtime: item.runtime,
      );

  final String profileId;
  final String itemId;
  final String title;
  final DateTime createdAt;

  final ServerItemKind kind;
  final String? seriesId;
  final String? seriesTitle;
  final int? seasonNumber;
  final int? episodeNumber;
  final int? year;
  final Duration? runtime;

  final DownloadStatus status;

  /// Bytes on disk, which is where a resume starts from.
  final int receivedBytes;

  /// Null until the server has said how large the file is.
  final int? totalBytes;

  /// The finished file's name inside the item's folder. Null until then:
  /// the extension is only known once the server has named the file.
  final String? fileName;

  /// Why the last attempt stopped, as a sentence. Null unless [status] is
  /// [DownloadStatus.failed].
  final String? error;

  String get key => keyOf(profileId, itemId);

  static String keyOf(String profileId, String itemId) => '$profileId/$itemId';

  /// 0–1, or null while the size is unknown.
  double? get progress {
    final total = totalBytes;
    if (status == DownloadStatus.completed) return 1;
    if (total == null || total <= 0) return null;
    return (receivedBytes / total).clamp(0, 1).toDouble();
  }

  DownloadEntry copyWith({
    DownloadStatus? status,
    int? receivedBytes,
    int? totalBytes,
    String? fileName,
    String? error,
    bool clearError = false,
  }) =>
      DownloadEntry(
        profileId: profileId,
        itemId: itemId,
        title: title,
        createdAt: createdAt,
        kind: kind,
        seriesId: seriesId,
        seriesTitle: seriesTitle,
        seasonNumber: seasonNumber,
        episodeNumber: episodeNumber,
        year: year,
        runtime: runtime,
        status: status ?? this.status,
        receivedBytes: receivedBytes ?? this.receivedBytes,
        totalBytes: totalBytes ?? this.totalBytes,
        fileName: fileName ?? this.fileName,
        error: clearError ? null : (error ?? this.error),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'profileId': profileId,
        'itemId': itemId,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'kind': kind.name,
        'seriesId': ?seriesId,
        'seriesTitle': ?seriesTitle,
        'seasonNumber': ?seasonNumber,
        'episodeNumber': ?episodeNumber,
        'year': ?year,
        'runtimeMs': ?runtime?.inMilliseconds,
        'status': status.name,
        'receivedBytes': receivedBytes,
        'totalBytes': ?totalBytes,
        'fileName': ?fileName,
        'error': ?error,
      };

  /// Null for a record that is missing what identifies it; the index skips
  /// it rather than failing to load every other copy.
  static DownloadEntry? fromJson(Map<String, dynamic> json) {
    final profileId = json['profileId'];
    final itemId = json['itemId'];
    if (profileId is! String || itemId is! String) return null;

    final runtimeMs = json['runtimeMs'];
    return DownloadEntry(
      profileId: profileId,
      itemId: itemId,
      title: json['title'] as String? ?? itemId,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      kind: ServerItemKind.values.firstWhere(
        (k) => k.name == json['kind'],
        orElse: () => ServerItemKind.unknown,
      ),
      seriesId: json['seriesId'] as String?,
      seriesTitle: json['seriesTitle'] as String?,
      seasonNumber: json['seasonNumber'] as int?,
      episodeNumber: json['episodeNumber'] as int?,
      year: json['year'] as int?,
      runtime: runtimeMs is int ? Duration(milliseconds: runtimeMs) : null,
      status: DownloadStatus.fromName(json['status'] as String?),
      receivedBytes: json['receivedBytes'] as int? ?? 0,
      totalBytes: json['totalBytes'] as int?,
      fileName: json['fileName'] as String?,
      error: json['error'] as String?,
    );
  }
}
