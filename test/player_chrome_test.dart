// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mplayer/core/models/media_models.dart';
import 'package:mplayer/features/player/playback_state.dart';
import 'package:mplayer/features/player/player_ui_state.dart';
import 'package:mplayer/sources/media_source.dart';

PlayableMedia mediaWithChapters(List<MediaChapter> chapters) {
  return PlayableMedia(
    ref: const MediaRef(sourceId: 's', itemId: 'i', title: 'Nightfall S01E02'),
    uri: Uri.parse('https://example.invalid/stream'),
    kind: SourceKind.jellyfin,
    capabilities: const SourceCapabilities(chapters: true),
    sourceLine: 'Jellyfin · direct play',
    chapters: chapters,
  );
}

const _intro = MediaChapter(
  title: 'Intro',
  start: Duration(seconds: 30),
  end: Duration(seconds: 90),
  isIntro: true,
);
const _body = MediaChapter(
  title: 'Part one',
  start: Duration(seconds: 90),
  end: Duration(minutes: 20),
);

void main() {
  group('MediaChapter', () {
    test('contains is inclusive of start and exclusive of end', () {
      expect(_intro.contains(const Duration(seconds: 29)), isFalse);
      expect(_intro.contains(const Duration(seconds: 30)), isTrue);
      expect(_intro.contains(const Duration(seconds: 89)), isTrue);
      // The boundary belongs to the next chapter, or the skip pill would
      // linger for a frame after the intro ends.
      expect(_intro.contains(const Duration(seconds: 90)), isFalse);
    });

    test('chapterAt finds the chapter around a position', () {
      final media = mediaWithChapters(<MediaChapter>[_intro, _body]);

      expect(media.chapterAt(const Duration(seconds: 60))?.title, 'Intro');
      expect(media.chapterAt(const Duration(minutes: 5))?.title, 'Part one');
      expect(media.chapterAt(const Duration(hours: 2)), isNull);
    });
  });

  group('skip intro', () {
    test('appears only inside a chapter marked as an intro', () {
      final media = mediaWithChapters(<MediaChapter>[_intro, _body]);

      PlaybackState at(Duration p) => PlaybackState(media: media, position: p);

      expect(at(const Duration(seconds: 10)).currentIntro, isNull);
      expect(at(const Duration(seconds: 60)).currentIntro?.title, 'Intro');
      // Inside a chapter, but not the intro one.
      expect(at(const Duration(minutes: 5)).currentIntro, isNull);
    });

    test('container chapters drive the pill when the source has none', () {
      // A local MKV carries chapters even though its source supplies none.
      final media = mediaWithChapters(const <MediaChapter>[]);
      final state = PlaybackState(
        media: media,
        position: const Duration(seconds: 60),
        containerChapters: const <MediaChapter>[_intro, _body],
      );

      expect(state.chapters, hasLength(2));
      expect(state.currentIntro?.title, 'Intro');
    });

    test('no chapters anywhere means no pill', () {
      final media = mediaWithChapters(const <MediaChapter>[]);

      expect(
        PlaybackState(media: media, position: const Duration(seconds: 60))
            .currentIntro,
        isNull,
      );
      expect(PlaybackState(media: media).chapters, isEmpty);
    });
  });

  group('chapter precedence', () {
    const fromContainer = MediaChapter(
      title: 'Chapter 1',
      start: Duration.zero,
      end: Duration(minutes: 10),
    );

    test('source chapters win over the container', () {
      // Only the source marks intros, so its list is authoritative when both
      // exist — otherwise a server-marked intro would be masked by a generic
      // container chapter.
      final state = PlaybackState(
        media: mediaWithChapters(const <MediaChapter>[_intro, _body]),
        containerChapters: const <MediaChapter>[fromContainer],
      );

      expect(state.chapters.map((c) => c.title), <String>['Intro', 'Part one']);
    });

    test('the container is used only as a fallback', () {
      final state = PlaybackState(
        media: mediaWithChapters(const <MediaChapter>[]),
        containerChapters: const <MediaChapter>[fromContainer],
      );

      expect(state.chapters.single.title, 'Chapter 1');
    });
  });

  group('PlaybackStats', () {
    test('recognises hardware decoders by name', () {
      const hw = <String>[
        'd3d11va-copy',
        'dxva2',
        'vaapi',
        'videotoolbox',
        'mediacodec',
        'nvdec',
      ];
      for (final String decoder in hw) {
        expect(
          PlaybackStats(videoDecoder: decoder).isHardwareDecoded,
          isTrue,
          reason: '$decoder should read as hardware',
        );
      }
    });

    test('anything else, including no decoder at all, reads as software', () {
      expect(const PlaybackStats(videoDecoder: 'ffmpeg').isHardwareDecoded,
          isFalse);
      expect(const PlaybackStats().isHardwareDecoded, isFalse);
    });
  });

  group('MediaTrack.isImageBased', () {
    MediaTrack sub(String? codec) => MediaTrack(
          id: '2',
          kind: TrackKind.subtitle,
          label: 'English',
          codec: codec,
        );

    test('recognises the bitmap subtitle codecs', () {
      for (final String codec in <String>[
        'hdmv_pgs_subtitle',
        'PGS',
        'dvd_subtitle',
        'dvb_subtitle',
        'xsub',
      ]) {
        expect(sub(codec).isImageBased, isTrue, reason: codec);
      }
    });

    test('text subtitle codecs are not image-based', () {
      for (final String codec in <String>['ass', 'subrip', 'webvtt', 'mov_text']) {
        expect(sub(codec).isImageBased, isFalse, reason: codec);
      }
      expect(sub(null).isImageBased, isFalse);
    });
  });

  group('MediaTrack', () {
    test('reserved ids are recognised rather than shown as track names', () {
      const off = MediaTrack(id: 'no', kind: TrackKind.subtitle, label: 'Off');
      const auto = MediaTrack(id: 'auto', kind: TrackKind.audio, label: 'Auto');
      const real = MediaTrack(id: '2', kind: TrackKind.audio, label: 'English');

      expect(off.isOff, isTrue);
      expect(auto.isAuto, isTrue);
      expect(real.isOff, isFalse);
      expect(real.isAuto, isFalse);
    });
  });

  group('RotationMode', () {
    test('cycles auto to landscape to portrait and back', () {
      expect(RotationMode.auto.next, RotationMode.landscape);
      expect(RotationMode.landscape.next, RotationMode.portrait);
      expect(RotationMode.portrait.next, RotationMode.auto);
    });

    test('auto pins no axis of its own — the video decides', () {
      // Auto is "follow video", not "let the sensor decide", so the enum
      // carries no orientation list; orientationsForVideo supplies it.
      expect(RotationMode.auto.orientations, isEmpty);
      expect(
        RotationMode.landscape.orientations,
        containsAll(<DeviceOrientation>[
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]),
      );
      expect(RotationMode.portrait.orientations,
          <DeviceOrientation>[DeviceOrientation.portraitUp]);
    });
  });

  group('orientationsForVideo', () {
    test('a wide video asks for landscape, both ways up', () {
      expect(
        orientationsForVideo(1920, 1080),
        <DeviceOrientation>[
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ],
      );
    });

    test('a tall video asks for portrait', () {
      // Phone-shot clips are common enough that this is not a corner case.
      expect(
        orientationsForVideo(1080, 1920),
        <DeviceOrientation>[
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ],
      );
    });

    test('a square video is treated as landscape rather than left undecided', () {
      expect(
        orientationsForVideo(1000, 1000),
        contains(DeviceOrientation.landscapeLeft),
      );
    });
  });

  group('AspectMode', () {
    test('maps to the BoxFit the video surface uses', () {
      expect(AspectMode.fit.boxFit, BoxFit.contain);
      expect(AspectMode.fill.boxFit, BoxFit.cover);
      expect(AspectMode.stretch.boxFit, BoxFit.fill);
    });

    test('cycles back around', () {
      expect(AspectMode.fit.next, AspectMode.fill);
      expect(AspectMode.stretch.next, AspectMode.fit);
    });
  });

  group('PlayerUiState', () {
    test('sleep timer label reads Off when unset', () {
      expect(const PlayerUiState().sleepLabel, 'Off');
      expect(
        const PlayerUiState(sleepTimer: Duration(minutes: 30)).sleepLabel,
        '30 min',
      );
    });

    test('copyWith can clear the sleep timer, which null cannot', () {
      const state = PlayerUiState(sleepTimer: Duration(minutes: 15));

      expect(state.copyWith().sleepTimer, isNotNull);
      expect(state.copyWith(sleepTimer: null).sleepTimer, isNotNull);
      expect(state.copyWith(clearSleepTimer: true).sleepTimer, isNull);
    });
  });
}
