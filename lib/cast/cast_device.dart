// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/foundation.dart';

/// Which protocol a device speaks.
///
/// The two share nothing on the wire — DLNA is SOAP over HTTP that this app
/// speaks itself, Chromecast is a Google SDK behind a platform channel — so
/// the kind decides which renderer is built for a device, and nothing else.
enum CastKind {
  dlna('DLNA'),
  chromecast('Chromecast');

  const CastKind(this.label);

  final String label;
}

/// A device that can play the file instead of this screen.
@immutable
class CastDevice {
  const CastDevice({
    required this.id,
    required this.name,
    required this.kind,
    this.model,
    this.controlUrl,
    this.address,
  });

  /// Stable across discoveries: the UPnP USN, or the Cast device id. Used to
  /// recognise a device the user is already connected to when it turns up in
  /// a later search rather than listing it twice.
  final String id;

  final String name;
  final CastKind kind;

  /// "Samsung TV", "BRAVIA" — shown under the name when the two differ.
  final String? model;

  /// DLNA only: the absolute AVTransport control URL.
  final Uri? controlUrl;

  /// The device's address on the network, for the picker's second line.
  final String? address;

  @override
  bool operator ==(Object other) =>
      other is CastDevice && other.id == id && other.kind == kind;

  @override
  int get hashCode => Object.hash(id, kind);
}

/// What a device says it is doing.
enum CastPlayback { idle, buffering, playing, paused, stopped }

@immutable
class CastStatus {
  const CastStatus({
    this.playback = CastPlayback.idle,
    this.position = Duration.zero,
    this.duration = Duration.zero,
  });

  final CastPlayback playback;
  final Duration position;
  final Duration duration;

  bool get isPlaying => playback == CastPlayback.playing;
}
