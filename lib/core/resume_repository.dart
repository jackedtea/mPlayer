// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/media_models.dart';

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
    );
  }

  final String sourceId;
  final String itemId;
  final String title;
  final SourceKind kind;
  final Duration position;
  final Duration duration;
  final DateTime updatedAt;

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

  Map<String, dynamic> toJson() => <String, dynamic>{
        'sourceId': sourceId,
        'itemId': itemId,
        'title': title,
        'kind': kind.name,
        'positionMs': position.inMilliseconds,
        'durationMs': duration.inMilliseconds,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
      };
}

/// Persists how far through each file the user got.
///
/// `shared_preferences` rather than Drift: the Drift schema is still ahead of
/// us, and a bounded list of resume points does not need a database. Moving it
/// later is a migration of one key.
class ResumeRepository {
  /// [prefs] is injectable so tests need no platform channel.
  ResumeRepository({SharedPreferences? prefs})
      // A private field cannot be an initializing formal: Dart forbids named
      // parameters starting with an underscore.
      // ignore: prefer_initializing_formals
      : _prefs = prefs;

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
  Future<void> save(ResumePoint point) async {
    if (point.duration <= Duration.zero) return;

    if (point.progress >= finishedProgress) {
      await remove(point.sourceId, point.itemId);
      return;
    }
    if (point.progress < minProgress) return;

    final points = await load()
      ..removeWhere((p) => p.key == point.key);
    points.insert(0, point);

    await _write(points.take(maxEntries).toList());
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
  }

  Future<void> clear() async => _write(const <ResumePoint>[]);

  Future<void> _write(List<ResumePoint> points) async {
    final store = await _store;
    await store.setStringList(
      _prefsKey,
      points.map((p) => jsonEncode(p.toJson())).toList(),
    );
  }
}

final resumeRepositoryProvider =
    Provider<ResumeRepository>((ref) => ResumeRepository());

/// The Continue-watching shelf.
///
/// Invalidated when playback stops, so returning from the player shows the
/// updated position rather than the one from before.
final resumePointsProvider = FutureProvider<List<ResumePoint>>(
  (ref) => ref.watch(resumeRepositoryProvider).load(),
);
