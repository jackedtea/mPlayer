// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter_test/flutter_test.dart';

import 'package:mplayer/core/models/media_models.dart';
import 'package:mplayer/servers/jellyfin_media_source.dart';
import 'package:mplayer/servers/media_library_source.dart';
import 'package:mplayer/servers/server_profile.dart';
import 'package:mplayer/sources/media_source.dart';

const _profile = ServerProfile(
  id: 'p1',
  kind: ServerKind.jellyfin,
  name: 'Home',
  uri: 'https://media.home.lan',
  userId: 'u1',
  username: 'nam',
);

/// A server that answers from fields instead of a network.
class _FakeLibrary implements MediaLibrarySource {
  _FakeLibrary({
    required this.item_,
    required this.playback_,
    this.failWith,
    this.segments_ = const <MediaSegment>[],
  });

  final ServerItem item_;
  final ServerPlayback playback_;
  final ServerException? failWith;
  final List<MediaSegment> segments_;

  final List<(String, Duration, bool)> progress = <(String, Duration, bool)>[];
  final List<(String, Duration, String?)> stops = <(String, Duration, String?)>[];

  @override
  ServerProfile get profile => _profile;

  @override
  Future<ServerItem> item(String itemId) async {
    final failure = failWith;
    if (failure != null) throw failure;
    return item_;
  }

  @override
  Future<ServerPlayback> playback(
    String itemId,
    PlaybackCapabilities caps, {
    int? audioStreamIndex,
    int? subtitleStreamIndex,
    String? mediaSourceId,
  }) async {
    final failure = failWith;
    if (failure != null) throw failure;
    return playback_;
  }

  @override
  Future<void> reportProgress(
    String itemId, {
    required Duration position,
    required bool isPaused,
    String? playSessionId,
  }) async {
    progress.add((itemId, position, isPaused));
  }

  @override
  Future<void> reportStopped(
    String itemId, {
    required Duration position,
    String? playSessionId,
  }) async {
    stops.add((itemId, position, playSessionId));
  }

  @override
  Future<List<MediaSegment>> segments(String itemId) async => segments_;

  @override
  Uri? chapterImageUrl(String itemId, ServerChapter chapter, {int? maxWidth}) =>
      chapter.imageTag == null
          ? null
          : Uri.parse(
              'https://media.home.lan/Items/$itemId/Images/Chapter/'
              '\${chapter.index}?tag=\${chapter.imageTag}',
            );

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
          {int startIndex = 0, int limit = 100, ServerSort sort = ServerSort.name}) async =>
      const <ServerItem>[];
  @override
  Future<List<ServerItem>> nextUp({int limit = 12}) async => const <ServerItem>[];
  @override
  Future<List<ServerItem>> resumable({int limit = 12}) async => const <ServerItem>[];
  @override
  Future<List<ServerItem>> search(String query, {int limit = 40}) async =>
      const <ServerItem>[];
  @override
  Future<List<ServerItem>> similar(String itemId, {int limit = 12}) async =>
      const <ServerItem>[];
  @override
  Future<List<ServerItem>> personItems(String personId,
          {int limit = 100}) async =>
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
  Future<String?> createPlaylist(String name, List<String> itemIds) async =>
      null;
  @override
  Future<void> setFavourite(String itemId, {required bool favourite}) async {}
  @override
  Future<void> setPlayed(String itemId, {required bool played}) async {}
  @override
  Future<List<LibraryView>> views() async => const <LibraryView>[];
  @override
  Future<int> itemCount(String viewId) async => 0;
  @override
  Future<void> dispose() async {}
}

void main() {
  group('resolving for the player', () {
    test('the server decides where playback starts', () async {
      // The server has been collecting the position from every device the
      // user owns, so it outranks anything this one remembers.
      final library = _FakeLibrary(
        item_: const ServerItem(
          id: 'a1',
          title: 'Dune',
          position: Duration(minutes: 41),
        ),
        playback_: ServerPlayback(
          uri: Uri.parse('https://media.home.lan/Videos/a1/stream'),
          isDirectPlay: true,
          playSessionId: 'sess1',
        ),
      );

      final media = await JellyfinMediaSource(library).resolve(
        const MediaRef(sourceId: 'p1', itemId: 'a1', title: ''),
      );

      expect(media.startPosition, const Duration(minutes: 41));
      expect(media.uri.path, '/Videos/a1/stream');
      expect(media.kind, SourceKind.jellyfin);
      expect(media.title, 'Dune');
    });

    test('the source line says whether the file is being re-encoded', () async {
      final library = _FakeLibrary(
        item_: const ServerItem(id: 'a1', title: 'Dune'),
        playback_: ServerPlayback(
          uri: Uri.parse('https://media.home.lan/videos/a1/master.m3u8'),
          isDirectPlay: false,
          bitrate: 8000000,
        ),
      );

      final media = await JellyfinMediaSource(library).resolve(
        const MediaRef(sourceId: 'p1', itemId: 'a1', title: ''),
      );

      expect(media.sourceLine, contains('transcoding'));
      expect(media.sourceLine, contains('8.0 Mbps'));
    });

    test('a server failure reads as a sentence on the player', () async {
      // The player renders this inline, so a SOAP-shaped error would be
      // shown to the user verbatim.
      final library = _FakeLibrary(
        item_: const ServerItem(id: 'a1', title: 'x'),
        playback_: ServerPlayback(uri: Uri.parse('https://x'), isDirectPlay: true),
        failWith: const ServerException('Your session has expired.'),
      );

      await expectLater(
        JellyfinMediaSource(library).resolve(
          const MediaRef(sourceId: 'p1', itemId: 'a1', title: ''),
        ),
        throwsA(
          isA<MediaSourceException>()
              .having((e) => e.message, 'message', 'Your session has expired.'),
        ),
      );
    });

    test('a server advertises transcoding, which is what shows the quality pill',
        () {
      final source = JellyfinMediaSource(
        _FakeLibrary(
          item_: const ServerItem(id: 'a1', title: 'x'),
          playback_:
              ServerPlayback(uri: Uri.parse('https://x'), isDirectPlay: true),
        ),
      );

      expect(source.capabilities.transcoding, isTrue);
      expect(source.capabilities.reportsWatchState, isTrue);
    });
  });

  group('progress', () {
    test('the play session from the resolve is quoted back on stop', () async {
      // Without it the server never ties the stop to the session, and a
      // transcode keeps running until it times out.
      final library = _FakeLibrary(
        item_: const ServerItem(id: 'a1', title: 'Dune'),
        playback_: ServerPlayback(
          uri: Uri.parse('https://media.home.lan/s'),
          isDirectPlay: false,
          playSessionId: 'sess9',
        ),
      );
      final source = JellyfinMediaSource(library);

      await source.resolve(
        const MediaRef(sourceId: 'p1', itemId: 'a1', title: ''),
      );
      await source.reportStopped('a1', position: const Duration(minutes: 5));

      expect(library.stops.single.$3, 'sess9');
      expect(library.stops.single.$2, const Duration(minutes: 5));
    });

    test('a failed report is swallowed, not thrown at the player', () async {
      // The local resume point is already written; a dropped report costs
      // the server one update and the user nothing they can see.
      final source = JellyfinMediaSource(_ThrowingLibrary());

      await source.reportProgress(
        'a1',
        position: const Duration(minutes: 1),
        isPaused: false,
      );
      await source.reportStopped('a1', position: const Duration(minutes: 1));
    });
  });
  group('what the player is told about a server file', () {
    test('segments, chapters and trickplay all arrive with the handle',
        () async {
      final library = _FakeLibrary(
        item_: ServerItem(
          id: 'a1',
          title: 'Tomozaki',
          runtime: const Duration(minutes: 24),
          chapters: const <ServerChapter>[
            ServerChapter(
              index: 0,
              title: 'Cold open',
              start: Duration.zero,
              imageTag: 'aaa',
            ),
            ServerChapter(
              index: 1,
              title: 'Titles',
              start: Duration(seconds: 90),
            ),
          ],
          trickplay: ServerTrickplay(
            width: 320,
            height: 180,
            tileWidth: 10,
            tileHeight: 10,
            interval: 10000,
            thumbnailCount: 144,
            tileUrl: (i) => Uri.parse('https://media.home.lan/tile/$i.jpg'),
          ),
        ),
        playback_: ServerPlayback(
          uri: Uri.parse('https://media.home.lan/Videos/a1/stream'),
          isDirectPlay: true,
          externalSubtitles: <ExternalSubtitle>[
            ExternalSubtitle(
              uri: Uri.parse('https://media.home.lan/sub.srt'),
              label: 'English - SRT',
              index: 2,
            ),
          ],
        ),
        segments_: const <MediaSegment>[
          MediaSegment(
            kind: MediaSegmentKind.intro,
            start: Duration(seconds: 90),
            end: Duration(seconds: 180),
          ),
        ],
      );

      final media = await JellyfinMediaSource(library).resolve(
        const MediaRef(sourceId: 'p1', itemId: 'a1', title: ''),
      );

      expect(media.segments.single.kind, MediaSegmentKind.intro);
      expect(media.trickplay, isNotNull);
      expect(media.externalSubtitles.single.label, 'English - SRT');

      // A chapter runs until the next one begins, and the last one to the
      // end of the film.
      expect(media.chapters, hasLength(2));
      expect(media.chapters.first.end, const Duration(seconds: 90));
      expect(media.chapters.last.end, const Duration(minutes: 24));
      expect(media.chapters.first.imageUri, isNotNull);
      // Most servers extract no chapter stills at all, and a row without one
      // is the normal case rather than a broken image.
      expect(media.chapters.last.imageUri, isNull);
    });

    test('a server chapter never claims to be an intro on its own', () async {
      // The title heuristic is for containers, where a name is the only
      // signal there is. A server says so through its segments instead, and
      // letting a chapter called "Opening" claim it too puts two pills on
      // the screen.
      final library = _FakeLibrary(
        item_: const ServerItem(
          id: 'a1',
          title: 'Tomozaki',
          runtime: Duration(minutes: 24),
          chapters: <ServerChapter>[
            ServerChapter(index: 0, title: 'Opening', start: Duration.zero),
          ],
        ),
        playback_: ServerPlayback(
          uri: Uri.parse('https://media.home.lan/Videos/a1/stream'),
          isDirectPlay: true,
        ),
      );

      final media = await JellyfinMediaSource(library).resolve(
        const MediaRef(sourceId: 'p1', itemId: 'a1', title: ''),
      );

      expect(media.chapters.single.isIntro, isFalse);
    });
  });
}

class _ThrowingLibrary extends _FakeLibrary {
  _ThrowingLibrary()
      : super(
          item_: const ServerItem(id: 'a1', title: 'x'),
          playback_:
              ServerPlayback(uri: Uri.parse('https://x'), isDirectPlay: true),
        );

  @override
  Future<void> reportProgress(
    String itemId, {
    required Duration position,
    required bool isPaused,
    String? playSessionId,
  }) async {
    throw const ServerException('gone');
  }

  @override
  Future<void> reportStopped(
    String itemId, {
    required Duration position,
    String? playSessionId,
  }) async {
    throw const ServerException('gone');
  }
}
