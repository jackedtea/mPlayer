// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/media_models.dart';
import 'thumbnail_store.dart';

/// Where playback got to in one file.
@immutable
class ResumePoint {
  const ResumePoint({
    required this.sourceId,
    required this.itemId,
    required this.title,
    required this.kind,
    required this.position,
    required this.duration,
    required this.updatedAt,
    this.thumbnailPath,
  });

  factory ResumePoint.fromJson(Map<String, dynamic> json) {
    return ResumePoint(
      sourceId: json['sourceId'] as String,
      itemId: json['itemId'] as String,
      title: json['title'] as String? ?? '',
      kind: SourceKind.values.firstWhere(
        (k) => k.name == json['kind'],
        orElse: () => SourceKind.device,
      ),
      position: Duration(milliseconds: json['positionMs'] as int? ?? 0),
      duration: Duration(milliseconds: json['durationMs'] as int? ?? 0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        json['updatedAt'] as int? ?? 0,
      ),
      thumbnailPath: json['thumbnailPath'] as String?,
    );
  }

  final String sourceId;
  final String itemId;
  final String title;
  final SourceKind kind;
  final Duration position;
  final Duration duration;
  final DateTime updatedAt;

  /// Absolute path to the frame grabbed while this file was playing, drawn as
  /// the card's artwork. Null until one has been captured — a file resumed
  /// from a build that predates stills, or one whose capture failed, falls
  /// back to the gradient placeholder.
  final String? thumbnailPath;

  /// Identity across restarts: the same file in the same source.
  String get key => '$sourceId::$itemId';

  double get progress {
    if (duration.inMilliseconds <= 0) return 0;
    return (position.inMilliseconds / duration.inMilliseconds)
        .clamp(0.0, 1.0);
  }

  Duration get remaining {
    final left = duration - position;
    return left.isNegative ? Duration.zero : left;
  }

  ResumePoint copyWith({String? thumbnailPath}) => ResumePoint(
        sourceId: sourceId,
        itemId: itemId,
        title: title,
        kind: kind,
        position: position,
        duration: duration,
        updatedAt: updatedAt,
        thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'sourceId': sourceId,
        'itemId': itemId,
        'title': title,
        'kind': kind.name,
        'positionMs': position.inMilliseconds,
        'durationMs': duration.inMilliseconds,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
        if (thumbnailPath != null) 'thumbnailPath': thumbnailPath,
      };
}

/// Persists how far through each file the user got.
///
/// `shared_preferences` rather than Drift: the Drift schema is still ahead of
/// us, and a bounded list of resume points does not need a database. Moving it
/// later is a migration of one key.
class ResumeRepository {
  /// [prefs] and [thumbnails] are injectable so tests need no platform
  /// channel.
  ResumeRepository({SharedPreferences? prefs, ThumbnailStore? thumbnails})
      // A private field cannot be an initializing formal: Dart forbids named
      // parameters starting with an underscore.
      // ignore: prefer_initializing_formals
      : _prefs = prefs,
        _thumbnails = thumbnails ?? ThumbnailStore();

  static const _prefsKey = 'resume_points_v1';

  /// Enough for a Continue-watching shelf without letting the list grow
  /// forever on a device that plays a lot of files.
  static const maxEntries = 50;

  /// Below this the user barely started; a shelf full of accidental taps is
  /// worse than an empty one.
  static const minProgress = 0.02;

  /// Past this it counts as watched, and the entry is dropped rather than
  /// sitting at "1m left" forever.
  static const finishedProgress = 0.95;

  SharedPreferences? _prefs;
  final ThumbnailStore _thumbnails;

  Future<SharedPreferences> get _store async =>
      _prefs ??= await SharedPreferences.getInstance();

  /// Newest first.
  Future<List<ResumePoint>> load() async {
    final store = await _store;
    final raw = store.getStringList(_prefsKey) ?? const <String>[];

    final points = <ResumePoint>[];
    for (final String entry in raw) {
      try {
        points.add(
          ResumePoint.fromJson(jsonDecode(entry) as Map<String, dynamic>),
        );
      } catch (e) {
        // One unreadable entry must not hide the rest of the shelf.
        debugPrint('Skipping unreadable resume point: $e');
      }
    }

    points.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return points;
  }

  /// Records progress, or clears the entry once the file counts as watched.
  ///
  /// [thumbnail] is an encoded frame grabbed off the player. It is only
  /// written when supplied — the position is saved every few seconds and
  /// capturing a frame that often would be wasteful — and an entry that gets
  /// none keeps whichever still it already had.
  Future<void> save(ResumePoint point, {Uint8List? thumbnail}) async {
    if (point.duration <= Duration.zero) return;

    if (point.progress >= finishedProgress) {
      await remove(point.sourceId, point.itemId);
      return;
    }
    if (point.progress < minProgress) return;

    final points = await load();
    final previous =
        points.where((p) => p.key == point.key).firstOrNull?.thumbnailPath;
    points.removeWhere((p) => p.key == point.key);

    final written = thumbnail == null
        ? null
        : await _thumbnails.write(point.key, thumbnail);

    points.insert(
      0,
      point.copyWith(
        thumbnailPath: written ?? point.thumbnailPath ?? previous,
      ),
    );

    final kept = points.take(maxEntries).toList();
    await _write(kept);

    // Entries pushed past the cap are dropped without going through
    // [remove], so their frames are swept here instead.
    if (points.length > kept.length) {
      await _thumbnails.retainOnly(kept.map((p) => p.key));
    }
  }

  Future<ResumePoint?> find(String sourceId, String itemId) async {
    final points = await load();
    for (final ResumePoint p in points) {
      if (p.sourceId == sourceId && p.itemId == itemId) return p;
    }
    return null;
  }

  Future<void> remove(String sourceId, String itemId) async {
    final points = await load()
      ..removeWhere((p) => p.sourceId == sourceId && p.itemId == itemId);
    await _write(points);
    await _thumbnails.delete('$sourceId::$itemId');
  }

  Future<void> clear() async {
    await _write(const <ResumePoint>[]);
    // Awaited so a caller knows the stills are gone too. Safe to wait on:
    // the directory lookup behind it is bounded, so a slow or unavailable
    // app-support directory degrades to "no stills" instead of hanging the
    // button the user just pressed.
    await _thumbnails.retainOnly(const <String>[]);
  }

  Future<void> _write(List<ResumePoint> points) async {
    final store = await _store;
    await store.setStringList(
      _prefsKey,
      points.map((p) => jsonEncode(p.toJson())).toList(),
    );
  }
}

final resumeRepositoryProvider = Provider<ResumeRepository>(
  (ref) => ResumeRepository(thumbnails: ref.watch(thumbnailStoreProvider)),
);

/// The Continue-watching shelf.
///
/// Invalidated when playback stops, so returning from the player shows the
/// updated position rather than the one from before.
final resumePointsProvider = FutureProvider<List<ResumePoint>>(
  (ref) => ref.watch(resumeRepositoryProvider).load(),
);
