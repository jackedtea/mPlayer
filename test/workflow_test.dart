// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:io' show File;

import 'package:flutter_test/flutter_test.dart';

/// The release workflow, checked for the one thing that cannot be seen by
/// reading it.
///
/// The Telegram step passes jq a program as a **single-quoted shell
/// argument**. One apostrophe anywhere inside closes that string early, the
/// rest is re-parsed as shell words, and jq is handed no program at all — it
/// exits 3 with "Top-level program not given", which says nothing about where
/// the quote was or even that a quote was involved. A comment reading
/// "someone's phone" is what did it, and the whole notification step failed
/// on a build nobody could otherwise explain.
void main() {
  test('the jq program contains no apostrophes', () {
    final source =
        File('.github/workflows/release.yml').readAsStringSync();

    final start = source.indexOf('jq -n');
    expect(start, isNot(-1), reason: 'the Telegram step has been renamed');

    // The program runs from the lone quote that opens it to the `}'` that
    // closes it.
    final open = source.indexOf("\n            '\n", start);
    expect(open, isNot(-1), reason: 'the jq program no longer opens on its own line');

    final close = source.indexOf("}'", open);
    expect(close, isNot(-1), reason: 'the jq program is not closed by `}\'`');

    final program = source.substring(open + "\n            '\n".length, close);

    expect(
      program.contains("'"),
      isFalse,
      reason: 'an apostrophe inside the jq program ends the shell string and '
          'leaves jq with nothing to run',
    );
  });
}
