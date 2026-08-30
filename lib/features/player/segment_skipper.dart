// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

/// When a labelled stretch of a file should be seeked past.
///
/// A **pure function**, for the same reason `smartSelection` is one: the rule
/// is the whole of the feature, and it is worth testing against a table of
/// positions rather than against a decoder that has to open a file first.
library;

import '../../servers/media_library_source.dart';
import '../settings/player_settings.dart';

/// The segment playback has just run into and should be seeked past, or null.
///
/// The rule, and every clause of it exists because the alternative is a
/// player that fights its user:
///
/// - **Only what the user set to [SegmentAction.skip].** `askToSkip` is a
///   pill they press; `nothing` means they want to watch it.
/// - **Only on running into it**, never on seeking into it. Someone who drags
///   the scrubber into the opening titles meant to be there, and bouncing
///   them straight back out is maddening. A seek is told from a second of
///   playback by the size of the jump — the position stream ticks well under
///   a second at a time, so anything larger came from a scrubber, a chapter
///   button or a double-tap.
/// - **Never twice.** An auto-skip lands on the segment's end, a millisecond
///   from still being inside it; without [alreadySkipped] a rounding error or
///   a small rewind bounces the viewer out a second time.
/// - **Never for a stretch shorter than [minimumSkippableSegment].** A
///   one-second jump costs the decoder more than it saves the viewer: the
///   picture stalls and the audio re-syncs over something that was over
///   before either finished.
MediaSegment? segmentToSkip({
  required List<MediaSegment> segments,
  required Duration? previous,
  required Duration now,
  required SegmentAction Function(MediaSegmentKind) actionFor,
  Set<MediaSegment> alreadySkipped = const <MediaSegment>{},
}) {
  // The first tick of a file has nothing to compare against, and a file
  // resuming at 40 minutes would otherwise look like a jump into whatever
  // segment covers it.
  if (segments.isEmpty || previous == null) return null;

  final step = now - previous;
  if (step.isNegative || step > maximumPlaybackStep) return null;

  for (final MediaSegment segment in segments) {
    if (actionFor(segment.kind) != SegmentAction.skip) continue;
    if (segment.length < minimumSkippableSegment) continue;
    if (alreadySkipped.contains(segment)) continue;
    // Crossed on this tick, rather than already inside — being inside one
    // without having crossed into it is what a seek looks like.
    if (previous < segment.start && now >= segment.start) return segment;
  }

  return null;
}

/// The largest gap between two position reports that still reads as playback.
///
/// Generous: the stream ticks several times a second, but a buffering stall
/// or a busy frame can stretch one tick, and treating that as a seek would
/// cost the viewer the skip they asked for.
const maximumPlaybackStep = Duration(seconds: 2);
