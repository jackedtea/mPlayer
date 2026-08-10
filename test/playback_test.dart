// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:mplayer/core/models/media_models.dart';
import 'package:mplayer/features/player/playback_state.dart';
import 'package:mplayer/sources/local_source.dart';
import 'package:mplayer/sources/media_source.dart';

void main() {
  group('formatDuration', () {
    test('omits the hour below an hour', () {
      expect(formatDuration(const Duration(seconds: 5)), '0:05');
      expect(formatDuration(const Duration(minutes: 12, seconds: 4)), '12:04');
      expect(formatDuration(const Duration(minutes: 59, seconds: 59)), '59:59');
    });

    test('shows an unpadded hour above one', () {
      expect(
        formatDuration(const Duration(hours: 1, minutes: 34, seconds: 52)),
        '1:34:52',
      );
      expect(formatDuration(const Duration(hours: 2)), '2:00:00');
    });

    test('clamps negatives to zero rather than printing a minus', () {
      expect(formatDuration(const Duration(seconds: -30)), '0:00');
    });
  });

  group('PlaybackState', () {
    test('progress is zero while the duration is still unknown', () {
      const state = PlaybackState(position: Duration(seconds: 30));
      expect(state.duration, Duration.zero);
      expect(state.progress, 0);
    });

    test('progress is clamped even if position overshoots', () {
      const state = PlaybackState(
        position: Duration(seconds: 120),
        duration: Duration(seconds: 100),
      );
      expect(state.progress, 1.0);
    });

    test('remaining never goes negative', () {
      const state = PlaybackState(
        position: Duration(seconds: 120),
        duration: Duration(seconds: 100),
      );
      expect(state.remaining, Duration.zero);
    });

    test('copyWith can clear the error, which a null argument cannot', () {
      const state = PlaybackState(error: 'boom');
      expect(state.copyWith().error, 'boom');
      expect(state.copyWith(error: null).error, 'boom');
      expect(state.copyWith(clearError: true).error, isNull);
    });
  });

  group('formatBytes', () {
    test('scales through the units', () {
      expect(formatBytes(512), '512 B');
      expect(formatBytes(2048), '2.0 KB');
      expect(formatBytes(19 * 1024 * 1024 * 1024), '19.0 GB');
    });

    test('drops the fraction once three digits are shown', () {
      expect(formatBytes(842 * 1024 * 1024), '842 MB');
    });
  });

  group('LocalSource.resolve', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('mplayer_test');
    });

    tearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    test('produces a file:// handle for a real file', () async {
      final file = File('${tempDir.path}${Platform.pathSeparator}clip.mkv');
      await file.writeAsBytes(List<int>.filled(2048, 0));

      const source = LocalSource();
      final media = await source.resolve(
        MediaRef(
          sourceId: LocalSource.sourceId,
          itemId: file.path,
          title: 'clip.mkv',
        ),
      );

      expect(media.uri.scheme, 'file');
      expect(media.kind, SourceKind.device);
      expect(media.title, 'clip.mkv');
      expect(media.sourceLine, contains('MKV'));
      expect(media.sourceLine, contains('2.0 KB'));
      // A local file has no server to report to and no chapter list.
      expect(media.capabilities.reportsWatchState, isFalse);
      expect(media.capabilities.chapters, isFalse);
    });

    test('reports a missing file as a MediaSourceException, not a crash',
        () async {
      const source = LocalSource();

      expect(
        () => source.resolve(
          const MediaRef(
            sourceId: LocalSource.sourceId,
            itemId: '/definitely/not/here.mkv',
            title: 'here.mkv',
          ),
        ),
        throwsA(isA<MediaSourceException>()),
      );
    });

    test('passes an Android content:// handle straight through', () async {
      const source = LocalSource();
      final media = await source.resolve(
        const MediaRef(
          sourceId: LocalSource.sourceId,
          itemId: 'content://media/external/video/media/42',
          title: 'clip.mp4',
        ),
      );

      expect(media.uri.scheme, 'content');
      expect(media.uri.toString(), 'content://media/external/video/media/42');
    });
  });
}
