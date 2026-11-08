// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

/// When a file has ended without the decoder saying so.
///
/// media_kit reports the end of a file only from mpv's `eof-reached`. A
/// server's transcoded stream can stop short of that: the last segment never
/// arrives, or the runtime the server announced runs a few seconds past the
/// picture. mpv then sits on the final frame with nothing reported, and
/// "Auto-play next episode" waits for an end that never comes, while the Next
/// button, which asks for nothing, works.
///
/// A **pure function**, like the segment skipper, so the rule is tested against
/// positions rather than against a decoder.
library;

/// How close to the end a stall has to be to count as the end.
///
/// Wide enough for a runtime that overstates the picture by a few seconds,
/// narrow enough that a stall mid-credits on a slow network does not skip
/// more than the last few seconds of them.
const silentEndWindow = Duration(seconds: 10);

/// How long the position must stand still there first. Long enough for the
/// decoder's own report, when it does come, to arrive first.
const silentEndStall = Duration(seconds: 4);

/// Whether a file stood still at [position] has, for every purpose, ended.
///
/// Never while the user paused it: someone stopping on the last frame meant
/// to stop there.
bool endedSilently({
  required Duration position,
  required Duration duration,
  required bool pausedByUser,
}) {
  if (pausedByUser || duration <= Duration.zero) return false;
  return duration - position <= silentEndWindow;
}
