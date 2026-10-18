// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:file_selector/file_selector.dart';

/// What the picker offers.
///
/// It used to live in `sources/media_source.dart` beside the video extension
/// set, which drove the folder browser's row icons. The browser is gone and
/// took the video list with it; this half is still needed.
const subtitleFileExtensions = <String>[
  'srt', 'ass', 'ssa', 'sub', 'vtt', 'idx', 'sup',
];

/// Picks a subtitle file off the device, for the file already playing.
///
/// This is the **only** thing left that opens a local file, and it is not
/// local playback: the video comes from a server and the user has a `.srt`
/// for it that the server does not. It lived on `LocalSource` before, which
/// is gone with the rest of the device library.
Future<XFile?> pickSubtitleFile() {
  final group = XTypeGroup(
    label: 'Subtitle',
    extensions: subtitleFileExtensions,
    // No UTI or MIME wildcard covers subtitles, and naming text/plain here
    // would hide .ass and .srt on the platforms that key off it — so the
    // group stays extension-only and Android falls back to any file.
    uniformTypeIdentifiers: const <String>['public.data'],
  );

  return openFile(acceptedTypeGroups: <XTypeGroup>[group]);
}
