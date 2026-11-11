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
import '../../sources/media_source.dart';
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
/// - **The first tick counts as playing from [openedAt]**, where the file
///   was asked to begin. Without it an intro starting at 0:00 — the
///   commonest one there is — could never be crossed: the first report has
///   nothing before it, and the second is already inside. A file resuming at
///   40 minutes still does not skip a segment that began at 39, since the
///   file did not start before it; and a stale first report far from
///   [openedAt] (the decoder's 0:00 before a resume seek lands) is ignored.
MediaSegment? segmentToSkip({
  required List<MediaSegment> segments,
  required Duration? previous,
  required Duration now,
  required SegmentAction Function(MediaSegmentKind) actionFor,
  Set<MediaSegment> alreadySkipped = const <MediaSegment>{},
  Duration? openedAt,
}) {
  if (segments.isEmpty) return null;
  if (previous == null) {
    if (openedAt == null) return null;
    final fromOpen = now - openedAt;
    if (fromOpen.isNegative || fromOpen > maximumPlaybackStep) return null;
    // Just before the opening position, so a segment starting exactly there
    // reads as crossed.
    previous = openedAt - const Duration(milliseconds: 1);
  }

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

/// Labelled stretches read off chapter titles, for a file the server has no
/// media segments for.
///
/// Anime releases and many rips name their chapters "OP", "ED", "Opening",
/// "Ending", "Preview" and the like; a server that has not run a segment
/// plugin over the item passes those chapters on and nothing else. Turning
/// them into segments puts them through the same per-kind actions — offer,
/// skip, nothing — as the server's own, instead of a second, weaker path.
///
/// Matching is on the start of the title, so "OP1", "OP - Song name" and
/// "Ending: Artist" count, while "Option" or "Edward" do not.
List<MediaSegment> segmentsFromChapters(List<MediaChapter> chapters) {
  return <MediaSegment>[
    for (final MediaChapter chapter in chapters)
      if (chapter.end > chapter.start)
        if (chapterKind(chapter.title) case final MediaSegmentKind kind)
          MediaSegment(kind: kind, start: chapter.start, end: chapter.end),
  ];
}

/// What a chapter's title says it is, or null for an ordinary chapter.
MediaSegmentKind? chapterKind(String title) {
  final t = title.trim().toLowerCase();
  if (t.isEmpty) return null;
  for (final (RegExp pattern, MediaSegmentKind kind) in _chapterPatterns) {
    if (pattern.hasMatch(t)) return kind;
  }
  return null;
}

/// A word, an optional number ("OP2", "ED 1"), then the end of the title or
/// something that cannot continue the word.
RegExp _titled(String words) => RegExp(
  '^(?:$words)'
  r'\s*\d*(?:$|[\s:\-–—_.,(\[|/])',
);

final _chapterPatterns = <(RegExp, MediaSegmentKind)>[
  (
    _titled(
      'op|opening|opening credits|opening theme|opening song|intro|'
      'title sequence|main titles',
    ),
    MediaSegmentKind.intro,
  ),
  (
    _titled(
      'ed|ending|ending credits|ending theme|ending song|outro|'
      'credits|end credits|closing credits|closing',
    ),
    MediaSegmentKind.outro,
  ),
  (_titled('recap|previously|previously on'), MediaSegmentKind.recap),
  (
    _titled('preview|next episode preview|next episode|next time|yokoku'),
    MediaSegmentKind.preview,
  ),
];
