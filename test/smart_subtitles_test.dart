// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter_test/flutter_test.dart';

import 'package:mplayer/core/languages.dart';
import 'package:mplayer/features/player/playback_state.dart';
import 'package:mplayer/features/player/smart_subtitles.dart';

MediaTrack audio(String id, String? language) =>
    MediaTrack(id: id, kind: TrackKind.audio, label: id, language: language);

MediaTrack subtitle(String id, String? language) =>
    MediaTrack(id: id, kind: TrackKind.subtitle, label: id, language: language);

const _off = MediaTrack(id: 'no', kind: TrackKind.subtitle, label: 'Off');
const _auto = MediaTrack(id: 'auto', kind: TrackKind.audio, label: 'Auto');

void main() {
  group('canonicalLanguage', () {
    test('reduces the spellings a container actually uses', () {
      // Both ISO 639-2 forms exist in the wild and neither is a mistake.
      expect(canonicalLanguage('vie'), 'vi');
      expect(canonicalLanguage('VIE'), 'vi');
      expect(canonicalLanguage('Vietnamese'), 'vi');
      expect(canonicalLanguage('ger'), 'de');
      expect(canonicalLanguage('deu'), 'de');
      expect(canonicalLanguage('chi'), 'zh');
      expect(canonicalLanguage('zho'), 'zh');
    });

    test('drops region, script and a muxer note', () {
      expect(canonicalLanguage('pt-BR'), 'pt');
      expect(canonicalLanguage('zh_Hans'), 'zh');
      expect(canonicalLanguage('en (SDH)'), 'en');
      expect(canonicalLanguage('  eng  '), 'en');
    });

    test('an unlabelled track is unknown, not a guess', () {
      expect(canonicalLanguage('und'), isNull);
      expect(canonicalLanguage('zxx'), isNull);
      expect(canonicalLanguage(''), isNull);
      expect(canonicalLanguage(null), isNull);
    });
  });

  group('languageMatches', () {
    test('matches across spellings', () {
      expect(languageMatches('vie', 'vi'), isTrue);
      expect(languageMatches('en-US', 'eng'), isTrue);
    });

    test('an unknown language never matches', () {
      // Guessing here either hides subtitles someone needs or shows ones
      // they do not — both worse than leaving the file alone.
      expect(languageMatches('und', 'vi'), isFalse);
      expect(languageMatches(null, 'vi'), isFalse);
      expect(languageMatches('vie', null), isFalse);
    });
  });

  group('smartSelection', () {
    test('does nothing without a preferred language', () {
      final selection = smartSelection(
        audioTracks: <MediaTrack>[audio('1', 'jpn')],
        subtitleTracks: <MediaTrack>[subtitle('1', 'vie')],
        activeAudio: audio('1', 'jpn'),
        preferred: null,
      );

      expect(selection.isEmpty, isTrue);
    });

    test('foreign audio turns on subtitles in the preferred language', () {
      final selection = smartSelection(
        audioTracks: <MediaTrack>[_auto, audio('1', 'jpn')],
        subtitleTracks: <MediaTrack>[
          _off,
          subtitle('1', 'eng'),
          subtitle('2', 'vie'),
        ],
        activeAudio: audio('1', 'jpn'),
        preferred: 'vi',
      );

      expect(selection.subtitle?.id, '2');
      expect(selection.subtitlesOff, isFalse);
      expect(selection.audio, isNull);
    });

    test('audio already in the preferred language switches subtitles off', () {
      // Explicitly off, not "leave alone": a file may have flagged one of
      // its subtitle tracks as default.
      final selection = smartSelection(
        audioTracks: <MediaTrack>[audio('1', 'vie')],
        subtitleTracks: <MediaTrack>[_off, subtitle('1', 'vie')],
        activeAudio: audio('1', 'vie'),
        preferred: 'vi',
      );

      expect(selection.subtitlesOff, isTrue);
      expect(selection.subtitle, isNull);
      expect(selection.audio, isNull);
    });

    test('an audio track in the preferred language is chosen over subtitles',
        () {
      final selection = smartSelection(
        audioTracks: <MediaTrack>[audio('1', 'eng'), audio('2', 'vie')],
        subtitleTracks: <MediaTrack>[_off, subtitle('1', 'vie')],
        activeAudio: audio('1', 'eng'),
        preferred: 'vi',
      );

      expect(selection.audio?.id, '2');
      expect(selection.subtitlesOff, isTrue);
      expect(selection.subtitle, isNull);
    });

    test('foreign audio with no matching subtitle leaves the file alone', () {
      final selection = smartSelection(
        audioTracks: <MediaTrack>[audio('1', 'jpn')],
        subtitleTracks: <MediaTrack>[_off, subtitle('1', 'eng')],
        activeAudio: audio('1', 'jpn'),
        preferred: 'vi',
      );

      expect(selection.isEmpty, isTrue);
    });

    test('an unlabelled audio track is not treated as the preferred one', () {
      // The common case this protects: a rip whose audio says `und` and whose
      // subtitles are labelled. Assuming the audio matches would switch off
      // exactly the subtitles the user wants.
      final selection = smartSelection(
        audioTracks: <MediaTrack>[audio('1', null)],
        subtitleTracks: <MediaTrack>[_off, subtitle('1', 'vie')],
        activeAudio: audio('1', null),
        preferred: 'vi',
      );

      expect(selection.subtitle?.id, '1');
      expect(selection.subtitlesOff, isFalse);
    });

    test('the placeholder tracks are never selected', () {
      final selection = smartSelection(
        audioTracks: <MediaTrack>[_auto],
        subtitleTracks: <MediaTrack>[_off],
        activeAudio: _auto,
        preferred: 'vi',
      );

      expect(selection.isEmpty, isTrue);
    });
  });
}
