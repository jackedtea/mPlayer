// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mplayer/features/player/incoming_media.dart';
import 'package:mplayer/sources/local_source.dart';

/// `mPlayer video.mkv` on desktop, which is also the path every Windows and
/// Linux file association takes.
///
/// Android reads its files off an intent channel instead, so these are
/// skipped there rather than asserting the opposite behaviour.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Reads the provider before yielding, the way the app root does: it is a
  /// lazy provider, so nothing runs — and no file is published — until
  /// something is actually watching.
  Future<ProviderContainer> containerFor(List<String> args) async {
    final container = ProviderContainer(
      overrides: [startupArgumentsProvider.overrideWithValue(args)],
    );
    addTearDown(container.dispose);
    container.read(incomingMediaProvider);
    await Future<void>.delayed(Duration.zero);
    return container;
  }

  test('a path on the command line becomes an incoming file', () async {
    final container = ProviderContainer(
      overrides: [
        startupArgumentsProvider
            .overrideWithValue(<String>[r'D:\Movies\dune.mkv']),
      ],
    );
    addTearDown(container.dispose);

    // Nothing is pending on the first read: the app root watches for a
    // *change*, so publishing during build would go unseen.
    expect(container.read(incomingMediaProvider), isNull);
    await Future<void>.delayed(Duration.zero);

    final mediaRef = container.read(incomingMediaProvider);
    expect(mediaRef, isNotNull);
    expect(mediaRef!.itemId, r'D:\Movies\dune.mkv');
    expect(mediaRef.title, 'dune.mkv');
    expect(mediaRef.sourceId, LocalSource.sourceId);
  }, skip: Platform.isAndroid);

  test('engine flags are not mistaken for a file', () async {
    final container = await containerFor(<String>[
      '--enable-dart-profiling',
      '--observatory-port=0',
    ]);

    expect(container.read(incomingMediaProvider), isNull);
  }, skip: Platform.isAndroid);

  test('launching with no arguments opens nothing', () async {
    final container = await containerFor(const <String>[]);

    expect(container.read(incomingMediaProvider), isNull);
  }, skip: Platform.isAndroid);

  test('the first bare argument wins when flags come first', () async {
    final container = await containerFor(<String>[
      '--enable-dart-profiling',
      '/home/nam/videos/ep01.mkv',
      '/home/nam/videos/ep02.mkv',
    ]);

    expect(
      container.read(incomingMediaProvider)?.itemId,
      '/home/nam/videos/ep01.mkv',
    );
  }, skip: Platform.isAndroid);

  test('consume clears it so a rebuild does not reopen the file', () async {
    final container = await containerFor(<String>['/tmp/clip.mp4']);
    expect(container.read(incomingMediaProvider), isNotNull);

    container.read(incomingMediaProvider.notifier).consume();

    expect(container.read(incomingMediaProvider), isNull);
  }, skip: Platform.isAndroid);
}
