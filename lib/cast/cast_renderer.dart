// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/foundation.dart';
import 'cast_device.dart';

/// Thrown when a device refuses or cannot be reached.
///
/// Carries a sentence fit to show the user: a cast failure is something they
/// have to act on — a TV asleep, a firewall, the wrong network — and a SOAP
/// fault code tells them nothing.
class CastException implements Exception {
  const CastException(this.message);

  final String message;

  @override
  String toString() => 'CastException: $message';
}

/// One device, driven.
///
/// Deliberately narrow, and deliberately the same shape for both protocols:
/// what a player needs from a television is a URL to load and five transport
/// commands. Anything a given protocol cannot do (volume on a renderer with
/// no RenderingControl service) fails softly rather than widening this.
abstract class CastRenderer {
  CastDevice get device;

  /// Hands the device a URL and starts it playing.
  ///
  /// [url] has to be reachable *from the device*, which is why casting serves
  /// media over the LAN rather than the loopback address libmpv uses.
  Future<void> load(
    Uri url, {
    required String title,
    String contentType = 'video/mp4',
    Duration position = Duration.zero,
    CastTrackInfo? track,
  });

  Future<void> play();

  Future<void> pause();

  Future<void> stop();

  Future<void> seek(Duration to);

  /// Where the device has got to. Polled: neither protocol pushes position.
  Future<CastStatus> status();

  Future<void> dispose();
}

/// What a device shows for a song. Null [CastTrackInfo] is a video.
@immutable
class CastTrackInfo {
  const CastTrackInfo({this.artist, this.album, this.artUrl});

  final String? artist;
  final String? album;

  /// Fetched by the device itself, so it has to be reachable from there.
  final Uri? artUrl;
}
