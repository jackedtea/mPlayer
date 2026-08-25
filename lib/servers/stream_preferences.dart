// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/foundation.dart' show debugPrint, immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A quality the user can ask a server for.
///
/// A ceiling, not a demand: the server hands the file over untouched when it
/// already fits under the cap, and only re-encodes when it does not. So
/// [original] is not "best quality" — it is "never re-encode", which on a LAN
/// is both the fastest and the best-looking option, and over a phone
/// connection is the one that stalls.
@immutable
class StreamQuality {
  const StreamQuality({
    required this.id,
    required this.label,
    this.maxBitrate,
    this.maxHeight,
  });

  /// Stored, so the ladder can be reordered without changing what a user
  /// picked last week.
  final String id;

  final String label;

  /// Bits per second. Null means no cap at all.
  final int? maxBitrate;

  /// Null leaves the resolution alone; a transcode is then only about
  /// bitrate.
  final int? maxHeight;

  bool get isOriginal => maxBitrate == null && maxHeight == null;
}

/// The ladder offered in the picker.
///
/// Coarse on purpose. Every step here is a visibly different picture on a
/// phone; a list with 4.0 and 3.5 Mbps in it asks the user a question they
/// cannot answer.
const streamQualities = <StreamQuality>[
  StreamQuality(id: 'original', label: 'Original'),
  StreamQuality(id: 'uhd', label: '4K · 80 Mbps', maxBitrate: 80000000, maxHeight: 2160),
  StreamQuality(id: 'fhd20', label: '1080p · 20 Mbps', maxBitrate: 20000000, maxHeight: 1080),
  StreamQuality(id: 'fhd10', label: '1080p · 10 Mbps', maxBitrate: 10000000, maxHeight: 1080),
  StreamQuality(id: 'hd4', label: '720p · 4 Mbps', maxBitrate: 4000000, maxHeight: 720),
  StreamQuality(id: 'sd2', label: '480p · 2 Mbps', maxBitrate: 2000000, maxHeight: 480),
  StreamQuality(id: 'low', label: '360p · 1 Mbps', maxBitrate: 1000000, maxHeight: 360),
];

StreamQuality qualityById(String? id) {
  for (final StreamQuality q in streamQualities) {
    if (q.id == id) return q;
  }
  return streamQualities.first;
}

/// The quality cap every server request is made under.
class StreamQualityController extends Notifier<StreamQuality> {
  static const _prefsKey = 'stream_quality_v1';

  @override
  StreamQuality build() {
    Future<void>.microtask(_restore);
    // Original: the common case is a server on the same network, where
    // re-encoding costs picture quality and CPU and buys nothing.
    return streamQualities.first;
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString(_prefsKey);
      if (id != null) state = qualityById(id);
    } catch (e) {
      debugPrint('Unreadable stream quality, using the default: $e');
    }
  }

  Future<void> set(StreamQuality quality) async {
    state = quality;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, quality.id);
  }
}

final streamQualityProvider =
    NotifierProvider<StreamQualityController, StreamQuality>(
  StreamQualityController.new,
);

/// An audio and subtitle choice made *before* playback starts.
///
/// Carries the item it was made for. A choice is a set of stream indexes, and
/// those numbers mean something entirely different in the next file — so
/// rather than trusting whoever clears it, the resolve checks that the id
/// still matches and ignores the choice if it does not.
@immutable
class TrackChoice {
  const TrackChoice({
    required this.itemId,
    this.audioStreamIndex,
    this.subtitleStreamIndex,
    this.mediaSourceId,
  });

  final String itemId;
  final int? audioStreamIndex;

  /// Null means "no subtitles", which the server distinguishes from "decide
  /// for me" — the latter is simply not sending the parameter.
  final int? subtitleStreamIndex;

  final String? mediaSourceId;
}

/// Set by the detail screen just before it opens the player, read once by the
/// resolve, and never persisted.
class TrackChoiceController extends Notifier<TrackChoice?> {
  @override
  TrackChoice? build() => null;

  void set(TrackChoice? choice) => state = choice;

  /// The choice for [itemId], or null when the last one was made for
  /// something else.
  TrackChoice? forItem(String itemId) {
    final current = state;
    return current != null && current.itemId == itemId ? current : null;
  }
}

final trackChoiceProvider =
    NotifierProvider<TrackChoiceController, TrackChoice?>(
  TrackChoiceController.new,
);

/// Everything a resolve needs to know about how the user wants this played.
///
/// Handed to `JellyfinMediaSource` as a callback rather than a value: the
/// source is built once and resolves many times, and reading the preference
/// at resolve time is what lets a quality change take effect on the next
/// file without rebuilding the source map.
@immutable
class StreamPreferences {
  const StreamPreferences({
    this.quality = const StreamQuality(id: 'original', label: 'Original'),
    this.trackChoice,
  });

  final StreamQuality quality;
  final TrackChoice? trackChoice;
}
