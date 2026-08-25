// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:io' show File;

import 'package:flutter_test/flutter_test.dart';

/// Guards the player's teardown against the bug that cost two rounds of
/// fixes aimed at the wrong end of it.
///
/// `StatefulElement.unmount` calls `super.unmount()` — which sets the element
/// defunct — **before** `state.dispose()`. So by the time `dispose` runs,
/// `context.mounted` is already false, and Riverpod's `ref.read` throws
/// `StateError('Cannot use "ref" after the widget was disposed.')`.
///
/// One such call sat in the middle of the player's `dispose`. It threw every
/// time the screen closed, and the lines after it — stopping the decoder and
/// releasing the rotation lock — never ran. The film kept playing behind the
/// popped route and the app stayed sideways, and both survived being fixed at
/// the far end because the far end was never reached.
///
/// This is checked against the source rather than by driving the widget
/// because the player needs a real libmpv, which a unit test has no way to
/// give it. The invariant is narrow and load-bearing enough to be worth a
/// test the type system cannot express.
void main() {
  group('the player releases everything it holds', () {
    late String dispose;

    setUpAll(() {
      final source =
          File('lib/features/player/player_page.dart').readAsStringSync();
      // Comments stripped first: this file explains the bug in prose, and
      // the explanation names the very call it is checking is absent.
      dispose = _stripComments(_bodyOf(source, 'void dispose() {'));
    });

    test('dispose touches no ref', () {
      // Every notifier the teardown needs is captured in initState instead.
      expect(
        RegExp(r'\bref\s*\.').hasMatch(dispose),
        isFalse,
        reason: 'ref.read in dispose throws — the element is already defunct, '
            'and everything after the throw is silently skipped',
      );
    });

    test('every step is guarded, so one failure cannot skip the rest', () {
      // The shape of the original bug was a chain, not the particular call in
      // it. Guarding each step is what stops the next such call costing the
      // user their audio and their screen orientation.
      expect(dispose, contains('_guard('));

      for (final String step in <String>[
        '_playback.stop()',
        '_playerUi.reset',
        '_nowPlaying.stop()',
      ]) {
        expect(
          RegExp('_guard\\([^;]*${RegExp.escape(step)}').hasMatch(dispose),
          isTrue,
          reason: '$step must not be able to skip the steps after it',
        );
      }
    });

    test('the decoder is stopped before the notification is', () {
      // Ordering is the mitigation of last resort: if something below still
      // manages to take the whole method down, what the user can hear has
      // already been dealt with.
      expect(
        dispose.indexOf('_playback.stop()'),
        lessThan(dispose.indexOf('_nowPlaying.stop()')),
      );
    });

    test('a pop pauses without waiting for dispose at all', () {
      final source =
          File('lib/features/player/player_page.dart').readAsStringSync();

      // The net under the teardown: it runs while the widget is unambiguously
      // alive, so however the route goes away the audio stops with it.
      expect(source, contains('PopScope('));
      expect(source, contains('onPopInvokedWithResult:'));
      expect(
        RegExp(r'onPopInvokedWithResult:[\s\S]{0,200}_playback\.pause\(\)')
            .hasMatch(source),
        isTrue,
      );
    });
  });
}

/// Drops line comments, so prose about the bug is not read as the bug.
String _stripComments(String source) {
  final newline = String.fromCharCode(10);
  return source
      .split(newline)
      .map((line) {
        final comment = line.indexOf('//');
        return comment < 0 ? line : line.substring(0, comment);
      })
      .join(newline);
}

/// The body of the block opened by [header], brace-matched.
String _bodyOf(String source, String header) {
  final start = source.indexOf(header);
  if (start < 0) {
    throw StateError('Could not find "$header" — has it been renamed?');
  }

  var depth = 0;
  for (var i = start + header.length - 1; i < source.length; i++) {
    final c = source[i];
    if (c == '{') depth++;
    if (c == '}') {
      depth--;
      if (depth == 0) return source.substring(start, i + 1);
    }
  }
  throw StateError('Unbalanced braces after "$header".');
}
