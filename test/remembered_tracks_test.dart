// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mplayer/core/models/media_models.dart';
import 'package:mplayer/features/player/playback_state.dart';
import 'package:mplayer/features/player/remembered_tracks.dart';
import 'package:mplayer/features/player/server_tracks.dart';
import 'package:mplayer/servers/media_library_source.dart';
import 'package:mplayer/sources/media_source.dart';

MediaTrack audio(String id, String label, [String? language]) =>
    MediaTrack(id: id, kind: TrackKind.audio, label: label, language: language);

MediaTrack sub(String id, String label, [String? language]) => MediaTrack(
  id: id,
  kind: TrackKind.subtitle,
  label: label,
  language: language,
);

const auto = MediaTrack(id: 'auto', kind: TrackKind.audio, label: 'Auto');
const subOff = MediaTrack(id: 'no', kind: TrackKind.subtitle, label: 'Off');

/// A file as the server probed it: video 0, two audio, one embedded subtitle
/// and one the server keeps as a file of its own.
const streams = <ServerStream>[
  ServerStream(index: 0, type: ServerStreamType.video),
  ServerStream(index: 1, type: ServerStreamType.audio, language: 'jpn'),
  ServerStream(index: 2, type: ServerStreamType.audio, language: 'eng'),
  ServerStream(index: 3, type: ServerStreamType.subtitle, language: 'eng'),
  ServerStream(
    index: 4,
    type: ServerStreamType.subtitle,
    language: 'vie',
    deliveryUrl: '/Videos/a1/a1/Subtitles/4/0/Stream.srt',
  ),
];

PlayableMedia media({bool directPlay = true}) => PlayableMedia(
  ref: const MediaRef(sourceId: 'p1', itemId: 'a1', title: 'Ep 1'),
  uri: Uri.parse('https://media.home.lan/a1'),
  kind: SourceKind.jellyfin,
  capabilities: const SourceCapabilities(),
  sourceLine: 'Jellyfin',
  serverStreams: streams,
  isDirectPlay: directPlay,
);

final audioTracks = <MediaTrack>[
  auto,
  audio('1', 'Japanese', 'jpn'),
  audio('2', 'English', 'eng'),
];

final subtitleTracks = <MediaTrack>[
  subOff,
  sub('1', 'English', 'eng'),
  sub('2', 'Vietnamese', 'vi'),
];

void main() {
  group('decoder tracks and server indexes', () {
    test('line up on a direct play, kind by kind', () {
      expect(serverIndexOf(audioTracks[2], audioTracks, media()), 2);
      expect(
        trackForServerIndex(1, TrackKind.audio, audioTracks, media())?.id,
        '1',
      );
      // The sidecar file comes after the embedded subtitle, as appended.
      expect(serverIndexOf(subtitleTracks[2], subtitleTracks, media()), 4);
      expect(
        trackForServerIndex(3, TrackKind.subtitle, subtitleTracks, media())?.id,
        '1',
      );
    });

    test('subtitles off is the server\'s -1; auto is not a choice', () {
      expect(serverIndexOf(subOff, subtitleTracks, media()), -1);
      expect(serverIndexOf(auto, audioTracks, media()), isNull);
    });

    test('a transcode is never mapped', () {
      // The decoder holds the one audio the server encoded, not the
      // original's list.
      expect(
        serverIndexOf(audioTracks[1], audioTracks, media(directPlay: false)),
        isNull,
      );
    });

    test('lists that disagree answer nothing rather than a guess', () {
      final short = <MediaTrack>[auto, audio('1', 'Japanese', 'jpn')];
      expect(serverIndexOf(short[1], short, media()), isNull);
    });

    test('a sidecar not yet listed is simply not found yet', () {
      final early = subtitleTracks.take(2).toList();
      expect(
        trackForServerIndex(4, TrackKind.subtitle, early, media()),
        isNull,
      );
      expect(
        trackForServerIndex(3, TrackKind.subtitle, early, media())?.id,
        '1',
      );
    });
  });

  group('matching a remembered track in the next file', () {
    test('same title and language first, then the language alone', () {
      final next = <MediaTrack>[
        sub('1', 'English', 'en'),
        sub('2', 'English (Signs & Songs)', 'eng'),
      ];
      final picked = RememberedTrack.of(
        sub('9', 'English (Signs & Songs)', 'eng'),
      );
      expect(matchRemembered(next, picked)?.id, '2');

      final plain = RememberedTrack.of(sub('9', 'English SDH', 'eng'));
      expect(matchRemembered(next, plain)?.id, '1');
    });

    test('a language the file does not have matches nothing', () {
      final picked = RememberedTrack.of(audio('9', 'French', 'fre'));
      expect(matchRemembered(audioTracks, picked), isNull);
    });
  });

  group('remembering', () {
    setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

    test('survives a restart, subtitles off included', () async {
      final first = ProviderContainer();
      final memory = first.read(rememberedTracksProvider.notifier);
      await memory.rememberAudio('p1:s1', audio('1', 'Japanese', 'jpn'));
      await memory.rememberSubtitle('p1:s1', null);
      first.dispose();

      final second = ProviderContainer();
      addTearDown(second.dispose);
      final back = await second
          .read(rememberedTracksProvider.notifier)
          .forGroup('p1:s1');
      expect(back?.audio?.language, 'ja');
      expect(back?.subtitle?.off, isTrue);
    });

    test('Auto hands the audio back to the file', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final memory = container.read(rememberedTracksProvider.notifier);
      await memory.rememberAudio('p1:s1', audio('1', 'Japanese', 'jpn'));
      await memory.rememberSubtitle('p1:s1', sub('1', 'English', 'eng'));
      await memory.rememberAudio('p1:s1', auto);

      final back = await memory.forGroup('p1:s1');
      expect(back?.audio, isNull);
      // The other half is left as it was.
      expect(back?.subtitle?.language, 'en');
    });

    test('keeps the most recently changed when full', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final memory = container.read(rememberedTracksProvider.notifier);
      for (var i = 0; i <= RememberedTracksController.limit; i++) {
        await memory.rememberSubtitle('p1:s$i', null);
      }
      expect(await memory.forGroup('p1:s0'), isNull);
      expect(await memory.forGroup('p1:s1'), isNotNull);
    });
  });
}
