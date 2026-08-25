// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter_test/flutter_test.dart';

import 'package:mplayer/core/models/media_models.dart';
import 'package:mplayer/servers/jellyfin_dto.dart';
import 'package:mplayer/servers/jellyfin_media_source.dart';
import 'package:mplayer/servers/media_library_source.dart';
import 'package:mplayer/servers/server_profile.dart';
import 'package:mplayer/servers/stream_preferences.dart';
import 'package:mplayer/sources/media_source.dart';

const _profile = ServerProfile(
  id: 'p1',
  kind: ServerKind.jellyfin,
  name: 'Home',
  uri: 'https://media.home.lan',
  userId: 'u1',
  username: 'nam',
);

/// Captured from the dev server: an MKV with two audio tracks and two
/// subtitle tracks, one of them a picture format.
Map<String, dynamic> _playbackInfo() => <String, dynamic>{
      'PlaySessionId': 'sess1',
      'MediaSources': <Object?>[
        <String, dynamic>{
          'Id': 'ms1',
          'Container': 'mkv',
          'Bitrate': 6255512,
          'SupportsDirectPlay': true,
          'SupportsTranscoding': true,
          'DefaultAudioStreamIndex': 1,
          'MediaStreams': <Object?>[
            <String, dynamic>{
              'Index': 0,
              'Type': 'Video',
              'Codec': 'hevc',
              'DisplayTitle': '1080p HEVC SDR',
              'IsDefault': true,
              'BitRate': 5423512,
              'Width': 1920,
              'Height': 1040,
            },
            <String, dynamic>{
              'Index': 1,
              'Type': 'Audio',
              'Codec': 'ac3',
              'Language': 'eng',
              'DisplayTitle': 'English - Dolby Digital - 5.1 - Default',
              'IsDefault': true,
              'Channels': 6,
            },
            <String, dynamic>{
              'Index': 2,
              'Type': 'Audio',
              'Codec': 'ac3',
              'Language': 'vie',
              'DisplayTitle': 'Thuyết Minh - Vietnamese - Dolby Digital',
              'Channels': 2,
            },
            <String, dynamic>{
              'Index': 3,
              'Type': 'Subtitle',
              'Codec': 'PGSSUB',
              'Language': 'eng',
              'DisplayTitle': 'English - PGSSUB',
            },
            <String, dynamic>{
              'Index': 4,
              'Type': 'Subtitle',
              'Codec': 'subrip',
              'Language': 'vie',
              'DisplayTitle': 'Vietnamese - SUBRIP',
            },
          ],
        },
      ],
    };

void main() {
  group('stream parsing', () {
    test('the track list survives the round trip', () {
      final playback = playbackFromJson(
        _playbackInfo(),
        base: Uri.parse('https://media.home.lan'),
        itemId: 'i1',
        token: 't',
      )!;

      expect(playback.streams, hasLength(5));
      expect(playback.mediaSourceId, 'ms1');
      expect(playback.supportsTranscoding, isTrue);

      final audio = playback.streamsOfType(ServerStreamType.audio);
      expect(audio.map((s) => s.index), <int>[1, 2]);
      // The server's own description wins: it knows about channel layouts and
      // commentary flags this app does not model.
      expect(audio.first.label, contains('Dolby Digital'));
      expect(audio.last.language, 'vie');

      expect(
        playback.streamsOfType(ServerStreamType.subtitle).map((s) => s.index),
        <int>[3, 4],
      );
    });

    test('the server says which audio it would pick, and no subtitle', () {
      // Null for subtitles is "none", not "the server did not say" — the two
      // drive different pickers.
      final playback = playbackFromJson(
        _playbackInfo(),
        base: Uri.parse('https://media.home.lan'),
        itemId: 'i1',
        token: 't',
      )!;

      expect(playback.defaultAudioIndex, 1);
      expect(playback.defaultSubtitleIndex, isNull);
    });

    test('a track with no description is labelled from its parts', () {
      final stream = serverStreamFromJson(<String, dynamic>{
        'Index': 2,
        'Type': 'Audio',
        'Codec': 'aac',
        'Language': 'jpn',
        'Channels': 2,
      });

      expect(stream.label, 'jpn · AAC · 2 ch');
    });
  });

  group('quality', () {
    test('original means no cap at all, which is what a LAN wants', () {
      final original = qualityById('original');
      expect(original.isOriginal, isTrue);
      expect(original.maxBitrate, isNull);
      expect(original.maxHeight, isNull);
    });

    test('an id written by an older build falls back rather than throwing', () {
      expect(qualityById('something-removed').id, 'original');
      expect(qualityById(null).id, 'original');
    });

    test('every rung caps both bitrate and resolution', () {
      // A bitrate cap alone leaves the server re-encoding 4K at 2 Mbps, which
      // looks worse than the 480p it could have sent instead.
      for (final StreamQuality q in streamQualities.skip(1)) {
        expect(q.maxBitrate, isNotNull, reason: q.id);
        expect(q.maxHeight, isNotNull, reason: q.id);
      }
    });
  });

  group('preferences reaching the server', () {
    test('the chosen quality becomes the cap on the request', () async {
      final library = _RecordingLibrary();
      final source = JellyfinMediaSource(
        library,
        preferences: () => const StreamPreferences(
          quality: StreamQuality(
            id: 'hd4',
            label: '720p',
            maxBitrate: 4000000,
            maxHeight: 720,
          ),
        ),
      );

      await source.resolve(
        const MediaRef(sourceId: 'p1', itemId: 'a1', title: ''),
      );

      expect(library.lastCaps?.maxBitrate, 4000000);
      expect(library.lastCaps?.maxHeight, 720);
    });

    test('a track choice made for another item is ignored', () async {
      // The indexes are positions in one file's track list. Carried onto the
      // next film they would select something arbitrary, so the choice names
      // the item it belongs to and is dropped when that does not match.
      final library = _RecordingLibrary();
      final source = JellyfinMediaSource(
        library,
        preferences: () => const StreamPreferences(
          trackChoice: TrackChoice(itemId: 'somethingElse', audioStreamIndex: 2),
        ),
      );

      await source.resolve(
        const MediaRef(sourceId: 'p1', itemId: 'a1', title: ''),
      );

      expect(library.lastAudioIndex, isNull);
    });

    test('a track choice for this item is quoted to the server', () async {
      final library = _RecordingLibrary();
      final source = JellyfinMediaSource(
        library,
        preferences: () => const StreamPreferences(
          trackChoice: TrackChoice(
            itemId: 'a1',
            audioStreamIndex: 2,
            subtitleStreamIndex: 4,
            mediaSourceId: 'ms1',
          ),
        ),
      );

      await source.resolve(
        const MediaRef(sourceId: 'p1', itemId: 'a1', title: ''),
      );

      expect(library.lastAudioIndex, 2);
      expect(library.lastSubtitleIndex, 4);
      expect(library.lastMediaSourceId, 'ms1');
    });
  });

  group('the device profile', () {
    test('no cap means no profile at all', () {
      // "Original" is the promise never to re-encode, and the surest way to
      // keep it is to state no condition the file could fail.
      expect(deviceProfileFor(const PlaybackCapabilities()), isEmpty);
    });

    test('a cap becomes the conditions the server re-encodes against', () {
      // Verified against a live server: the query parameter alone comes back
      // SupportsDirectPlay with no transcode URL, because with no profile the
      // server assumes the client can play anything. These conditions are
      // what actually make the cap bite.
      final body = deviceProfileFor(
        const PlaybackCapabilities(maxBitrate: 4000000, maxHeight: 720),
      );

      final profile = body['DeviceProfile']! as Map<String, dynamic>;
      expect(profile['MaxStreamingBitrate'], 4000000);

      final codec = (profile['CodecProfiles']! as List).first
          as Map<String, dynamic>;
      final conditions =
          (codec['Conditions']! as List).cast<Map<String, dynamic>>();

      expect(
        conditions.map((c) => c['Property']),
        containsAll(<String>['Height', 'VideoBitrate']),
      );
      for (final Map<String, dynamic> c in conditions) {
        expect(c['IsRequired'], isTrue, reason: 'an optional condition is ignored');
      }
    });

    test('a segmented transcode, or seeking lands in the wrong place', () {
      final body = deviceProfileFor(
        const PlaybackCapabilities(maxBitrate: 2000000, maxHeight: 480),
      );
      final profile = body['DeviceProfile']! as Map<String, dynamic>;
      final transcode = (profile['TranscodingProfiles']! as List).first
          as Map<String, dynamic>;

      expect(transcode['Protocol'], 'hls');
      expect(transcode['BreakOnNonKeyFrames'], isTrue);
    });
  });

  group('start over', () {
    test('the same media, opened at the beginning', () {
      final media = PlayableMedia(
        ref: const MediaRef(sourceId: 'p1', itemId: 'a1', title: 'Dune'),
        uri: Uri.parse('https://media.home.lan/s'),
        kind: SourceKind.jellyfin,
        capabilities: const SourceCapabilities(),
        sourceLine: 'Jellyfin',
        startPosition: const Duration(minutes: 41),
      );

      final restarted = media.startingAt(Duration.zero);

      expect(restarted.startPosition, Duration.zero);
      // Everything else has to survive, or "start over" silently drops the
      // auth headers and the chapter list with it.
      expect(restarted.uri, media.uri);
      expect(restarted.ref, media.ref);
      expect(restarted.sourceLine, media.sourceLine);
    });
  });
}

/// Records what the resolve asked the server for.
class _RecordingLibrary implements MediaLibrarySource {
  PlaybackCapabilities? lastCaps;
  int? lastAudioIndex;
  int? lastSubtitleIndex;
  String? lastMediaSourceId;

  @override
  ServerProfile get profile => _profile;

  @override
  Future<ServerItem> item(String itemId) async =>
      ServerItem(id: itemId, title: 'Dune');

  @override
  Future<ServerPlayback> playback(
    String itemId,
    PlaybackCapabilities caps, {
    int? audioStreamIndex,
    int? subtitleStreamIndex,
    String? mediaSourceId,
  }) async {
    lastCaps = caps;
    lastAudioIndex = audioStreamIndex;
    lastSubtitleIndex = subtitleStreamIndex;
    lastMediaSourceId = mediaSourceId;

    return ServerPlayback(
      uri: Uri.parse('https://media.home.lan/s'),
      isDirectPlay: true,
    );
  }

  // Nothing below is exercised here.
  @override
  Future<List<ServerItem>> episodes(String seriesId, {String? seasonId}) async =>
      const <ServerItem>[];
  @override
  Uri? imageUrl(ServerItem item, {int? maxWidth}) => null;
  @override
  Uri? personImageUrl(ServerPerson person, {int? maxWidth}) => null;
  @override
  Future<List<ServerItem>> items(String viewId,
          {int startIndex = 0,
          int limit = 100,
          ServerSort sort = ServerSort.name}) async =>
      const <ServerItem>[];
  @override
  Future<List<ServerItem>> nextUp({int limit = 12}) async => const <ServerItem>[];
  @override
  Future<List<ServerItem>> resumable({int limit = 12}) async =>
      const <ServerItem>[];
  @override
  Future<List<ServerItem>> search(String query, {int limit = 40}) async =>
      const <ServerItem>[];
  @override
  Future<List<ServerItem>> similar(String itemId, {int limit = 12}) async =>
      const <ServerItem>[];
  @override
  Future<List<ServerItem>> playlists() async => const <ServerItem>[];
  @override
  Future<List<ServerItem>> playlistItems(String playlistId) async =>
      const <ServerItem>[];
  @override
  Future<void> addToPlaylist(String playlistId, List<String> itemIds) async {}
  @override
  Future<void> removeFromPlaylist(
      String playlistId, List<String> entryIds) async {}
  @override
  Future<String?> createPlaylist(String name, List<String> itemIds) async => null;
  @override
  Future<void> reportProgress(String itemId,
      {required Duration position,
      required bool isPaused,
      String? playSessionId}) async {}
  @override
  Future<void> reportStopped(String itemId,
      {required Duration position, String? playSessionId}) async {}
  @override
  Future<void> setFavourite(String itemId, {required bool favourite}) async {}
  @override
  Future<void> setPlayed(String itemId, {required bool played}) async {}
  @override
  Future<List<LibraryView>> views() async => const <LibraryView>[];
  @override
  Future<void> dispose() async {}
}
