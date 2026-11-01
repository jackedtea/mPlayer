// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

/// Translating between libmpv's tracks and the server's stream indexes.
///
/// The server remembers a track choice per item, and applies the user's
/// server-side language settings, in its own terms: `AudioStreamIndex: 3`.
/// libmpv numbers its tracks per kind from 1. The two line up only on a
/// **direct play**, where the decoder sees the very file the server probed —
/// embedded tracks in container order, then the subtitles the server keeps
/// as files, in the order the controller appended them. A transcode carries
/// whichever tracks the server chose, so nothing here is attempted on one.
///
/// Every function answers null rather than guess when the two lists do not
/// line up: reporting the wrong index would make the server remember a track
/// nobody chose.
library;

import 'package:collection/collection.dart';

import '../../servers/media_library_source.dart';
import '../../sources/media_source.dart';
import 'playback_state.dart';

/// The server's index for subtitles off.
const int serverSubtitlesOff = -1;

/// The server index of [track], or null where it cannot be told.
///
/// Subtitles off is [serverSubtitlesOff].
int? serverIndexOf(
  MediaTrack track,
  List<MediaTrack> tracks,
  PlayableMedia media,
) {
  if (track.kind == TrackKind.subtitle && track.isOff) {
    return serverSubtitlesOff;
  }
  if (track.isAuto || track.isOff) return null;

  final pairs = _pairs(track.kind, tracks, media);
  if (pairs == null) return null;
  return pairs.firstWhereOrNull((p) => p.track.id == track.id)?.stream.index;
}

/// The track in [tracks] the server means by [index], or null where none can
/// be told. Callers handle [serverSubtitlesOff] themselves.
MediaTrack? trackForServerIndex(
  int index,
  TrackKind kind,
  List<MediaTrack> tracks,
  PlayableMedia media,
) {
  final pairs = _pairs(kind, tracks, media);
  if (pairs == null) return null;
  return pairs.firstWhereOrNull((p) => p.stream.index == index)?.track;
}

/// Decoder track and server stream side by side, or null if they cannot be
/// paired with confidence.
List<({MediaTrack track, ServerStream stream})>? _pairs(
  TrackKind kind,
  List<MediaTrack> tracks,
  PlayableMedia media,
) {
  if (!media.isDirectPlay || media.serverStreams.isEmpty) return null;

  final type = switch (kind) {
    TrackKind.audio => ServerStreamType.audio,
    TrackKind.subtitle => ServerStreamType.subtitle,
    TrackKind.video => ServerStreamType.video,
  };
  final ofType = media.serverStreams.where((s) => s.type == type).toList()
    ..sort((a, b) => a.index.compareTo(b.index));
  final embedded = ofType.where((s) => !s.isExternal).toList();
  final server = <ServerStream>[
    ...embedded,
    ...ofType.where((s) => s.isExternal),
  ];

  final decoder = tracks
      .where((t) => t.kind == kind && !t.isAuto && !t.isOff)
      .toList();
  final ids = decoder.map((t) => int.tryParse(t.id)).toList();
  if (ids.contains(null)) return null;
  decoder.sort((a, b) => int.parse(a.id).compareTo(int.parse(b.id)));

  if (kind == TrackKind.subtitle) {
    // The server's sidecar files are appended after the open, and a file the
    // user loads by hand after those, so the decoder's list may be short of
    // the server's for a moment and longer than it later. Shorter than the
    // embedded tracks alone means the two describe different files.
    if (decoder.length < embedded.length) return null;
  } else if (decoder.length != server.length) {
    return null;
  }

  return <({MediaTrack track, ServerStream stream})>[
    for (var i = 0; i < decoder.length && i < server.length; i++)
      (track: decoder[i], stream: server[i]),
  ];
}
