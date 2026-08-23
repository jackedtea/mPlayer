// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

import '../../core/languages.dart';
import 'playback_state.dart';

/// What smart subtitles decided for a file.
///
/// A plain description rather than an action, so the rule can be read and
/// tested without a decoder: the controller is what turns it into calls.
@immutable
class SmartSelection {
  const SmartSelection({this.audio, this.subtitle, this.subtitlesOff = false});

  /// Switch to this audio track, or null to leave the current one.
  final MediaTrack? audio;

  /// Turn this subtitle track on, or null to change nothing.
  final MediaTrack? subtitle;

  /// Turn subtitles off — the audio already is in the user's language.
  final bool subtitlesOff;

  bool get isEmpty => audio == null && subtitle == null && !subtitlesOff;
}

/// The rule: play the audio in the language the user reads, and show
/// subtitles only when that was not possible.
///
/// A film in your own language plays clean; a foreign one turns subtitles on
/// by itself. Nothing happens without a [preferred] language, and nothing
/// happens for a track whose language the file does not state — `und` is not
/// evidence of anything, and guessing costs the user either the subtitles
/// they needed or a line of text over a film they understood.
SmartSelection smartSelection({
  required List<MediaTrack> audioTracks,
  required List<MediaTrack> subtitleTracks,
  required MediaTrack? activeAudio,
  required String? preferred,
}) {
  if (preferred == null) return const SmartSelection();

  final playingPreferredAudio = languageMatches(activeAudio?.language, preferred);

  // Only worth switching audio if the file actually carries that language and
  // is not already playing it.
  final audio = playingPreferredAudio
      ? null
      : audioTracks.firstWhereOrNull(
          (t) => !t.isAuto && !t.isOff && languageMatches(t.language, preferred),
        );

  if (playingPreferredAudio || audio != null) {
    // Audio the user understands, so subtitles are noise. Off explicitly:
    // the file may well have flagged one of its subtitle tracks as default.
    return SmartSelection(audio: audio, subtitlesOff: true);
  }

  final subtitle = subtitleTracks.firstWhereOrNull(
    (t) => !t.isOff && languageMatches(t.language, preferred),
  );

  // No subtitle in that language either: leave whatever the file chose. The
  // user is no worse off than without the feature, and switching something
  // off they might be reading is worse than doing nothing.
  return SmartSelection(subtitle: subtitle);
}
