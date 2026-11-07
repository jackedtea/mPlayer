// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_library_source.dart';

import 'package:mplayer/app/app.dart';
import 'package:mplayer/app/router.dart';
import 'package:mplayer/cast/cast_renderer.dart';
import 'package:mplayer/cast/upnp.dart';
import 'package:mplayer/core/models/media_models.dart';
import 'package:mplayer/features/cast/cast_controller.dart';
import 'package:mplayer/features/music/audio_session.dart';
import 'package:mplayer/features/player/playback_controller.dart';
import 'package:mplayer/features/player/playback_state.dart';
import 'package:mplayer/features/servers/server_library.dart';
import 'package:mplayer/remote/remote_protocol.dart';
import 'package:mplayer/servers/media_library_source.dart';
import 'package:mplayer/sources/media_source.dart';

MediaRef _ref(String id) => MediaRef(sourceId: 'p1', itemId: id, title: id);

/// A controller with no decoder, using the real queue changes.
class _FakePlayback extends PlaybackController {
  @override
  PlaybackState build() => const PlaybackState();

  @override
  Future<void> openInstead(PlayableMedia media, {PlaybackQueue? queue}) async {
    state = state.copyWith(media: media, queue: queue, playing: true);
  }

  @override
  Future<void> stop() async => state = const PlaybackState();

  @override
  Future<void> playAt(int index) async {
    state = state.copyWith(queue: state.queue.stepTo(index));
  }
}

class _Music extends FakeLibrarySource {
  const _Music();

  @override
  Future<List<LibraryView>> views() async => const <LibraryView>[
    LibraryView(id: 'm', name: 'Music', kind: 'music'),
  ];

  @override
  Future<List<ServerItem>> musicItems(
    String viewId,
    MusicListing listing, {
    int startIndex = 0,
    int limit = 100,
    ServerSort sort = ServerSort.name,
    SortOrder? order,
    LibraryFilter filter = LibraryFilter.none,
  }) async => const <ServerItem>[
    ServerItem(
      id: 'new',
      title: 'Newest Album',
      kind: ServerItemKind.musicAlbum,
    ),
  ];

  @override
  Future<List<ServerItem>> recentlyPlayedTracks({int limit = 20}) async =>
      const <ServerItem>[
        ServerItem(id: 'r', title: 'Played Song', kind: ServerItemKind.audio),
      ];

  @override
  Future<List<ServerItem>> search(
    String query, {
    int limit = 40,
    Set<ServerItemKind> kinds = const <ServerItemKind>{
      ServerItemKind.movie,
      ServerItemKind.series,
      ServerItemKind.episode,
    },
  }) async => <ServerItem>[
    for (final ServerItemKind kind in kinds)
      if (kind.isMusic) ServerItem(id: kind.name, title: kind.name, kind: kind),
  ];
}

Future<(GoRouter, ProviderContainer)> _pump(
  WidgetTester tester, {
  Size size = const Size(400, 900),
  MediaLibrarySource source = const _Music(),
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(
    overrides: [
      playbackControllerProvider.overrideWith(_FakePlayback.new),
      activeServerProvider.overrideWithValue(source),
    ],
  );
  addTearDown(container.dispose);

  final router = buildRouter();
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MPlayerApp(router: router),
    ),
  );
  await tester.pumpAndSettle();
  return (router, container);
}

Future<void> _nowPlaying(
  WidgetTester tester,
  GoRouter router,
  ProviderContainer container,
) async {
  await container
      .read(audioSessionProvider.notifier)
      .present(
        router,
        PlayableMedia(
          ref: _ref('a'),
          uri: Uri.parse('https://media.home.lan/stream'),
          kind: SourceKind.jellyfin,
          capabilities: const SourceCapabilities(),
          sourceLine: 'Jellyfin',
          isAudio: true,
        ),
        queue: PlaybackQueue(
          items: <MediaRef>[_ref('a'), _ref('b'), _ref('c')],
          kind: PlaybackQueueKind.music,
        ),
      );
  router.push('/now-playing');
  await tester.pumpAndSettle();
}

List<String> _queueOf(ProviderContainer container) => container
    .read(playbackControllerProvider)
    .queue
    .items
    .map((r) => r.itemId)
    .toList();

void main() {
  group('the queue on Now playing', () {
    testWidgets('a row comes out, and what is playing cannot', (tester) async {
      final (router, container) = await _pump(
        tester,
        size: const Size(1400, 900),
      );
      await _nowPlaying(tester, router, container);

      // One cross a row, for the two songs that are not playing.
      expect(find.byTooltip('Remove from queue'), findsNWidgets(2));

      await tester.tap(find.byTooltip('Remove from queue').first);
      await tester.pumpAndSettle();

      expect(_queueOf(container), <String>['a', 'c']);
    });

    testWidgets('Clear leaves what is playing', (tester) async {
      final (router, container) = await _pump(
        tester,
        size: const Size(1400, 900),
      );
      await _nowPlaying(tester, router, container);

      await tester.tap(find.widgetWithText(TextButton, 'Clear'));
      await tester.pumpAndSettle();

      expect(_queueOf(container), <String>['a']);
      expect(find.widgetWithText(TextButton, 'Clear'), findsNothing);
    });

    testWidgets('a row dragged down lands where it is dropped', (tester) async {
      final (router, container) = await _pump(
        tester,
        size: const Size(1400, 900),
      );
      await _nowPlaying(tester, router, container);

      final handle = find.byIcon(Icons.drag_handle_rounded).at(1);
      final gesture = await tester.startGesture(tester.getCenter(handle));
      await tester.pump(const Duration(milliseconds: 100));
      // In steps, as a finger moves: the list reacts to where the row is now.
      for (var i = 0; i < 6; i++) {
        await gesture.moveBy(const Offset(0, 16));
        await tester.pump(const Duration(milliseconds: 100));
      }
      await gesture.up();
      await tester.pumpAndSettle();

      expect(_queueOf(container), <String>['a', 'c', 'b']);
      expect(container.read(playbackControllerProvider).queue.index, 0);
    });

    test('clearing keeps the kind, and has nothing to do on a lone song', () {
      final queue = PlaybackQueue(
        items: <MediaRef>[_ref('a'), _ref('b')],
        index: 1,
        kind: PlaybackQueueKind.music,
      );

      final cleared = queue.clearedUpcoming();
      expect(cleared.items, <MediaRef>[_ref('b')]);
      expect(cleared.index, 0);
      expect(cleared.isMusic, isTrue);
      expect(cleared.clearedUpcoming(), same(cleared));
    });
  });

  group('Home', () {
    testWidgets('a music library has its newest albums and what was played', (
      tester,
    ) async {
      final (router, _) = await _pump(tester);
      router.go('/home');
      await tester.pumpAndSettle();

      // Empty before this: the row asked for films.
      expect(find.text('Newest Album'), findsOneWidget);
      expect(find.text('Recently played'), findsOneWidget);
      expect(find.text('Played Song'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Search', () {
    testWidgets('finds albums, artists and songs', (tester) async {
      final (router, _) = await _pump(tester);
      router.go('/search');
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(SearchBar), 'daft');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.text('Albums'), findsOneWidget);
      expect(find.text('musicAlbum'), findsOneWidget);
      expect(find.text('musicArtist'), findsOneWidget);
      expect(find.text('audio'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('casting a song', () {
    test('the device is told it is a song', () {
      final didl = didlMetadata(
        title: 'One More Time',
        url: Uri.parse('https://media.home.lan/stream'),
        contentType: 'audio/flac',
        track: CastTrackInfo(
          artist: 'Daft & Punk',
          album: 'Discovery',
          artUrl: Uri.parse('https://media.home.lan/art?a=1&b=2'),
        ),
      );

      expect(didl, contains('object.item.audioItem.musicTrack'));
      expect(didl, isNot(contains('videoItem')));
      expect(didl, contains('<upnp:artist>Daft &amp; Punk</upnp:artist>'));
      expect(didl, contains('<upnp:album>Discovery</upnp:album>'));
      expect(didl, contains('a=1&amp;b=2</upnp:albumArtURI>'));
    });

    test('a video stays a video', () {
      final didl = didlMetadata(
        title: 'Dune',
        url: Uri.parse('https://media.home.lan/stream'),
      );

      expect(didl, contains('object.item.videoItem'));
      expect(didl, isNot(contains('upnp:artist')));
    });

    test('the content type comes from the stream, not the title', () {
      String typeOf(String url) => audioContentTypeFor(Uri.parse(url));

      expect(typeOf('https://h/Audio/1/stream?container=flac'), 'audio/flac');
      expect(typeOf('https://h/Audio/1/stream?container=m4a'), 'audio/mp4');
      expect(typeOf('https://h/Audio/1/stream'), 'audio/mpeg');
      expect(
        typeOf('https://h/audio/1/master.m3u8?x=1'),
        'application/x-mpegURL',
      );
    });
  });

  group('sending a queue to a receiver', () {
    List<(String, String)> songs(int n) => <(String, String)>[
      for (var i = 0; i < n; i++) ('id$i', 'Song $i'),
    ];

    test('it survives the wire', () {
      final sent = RemoteCommand.playQueue(
        serverId: 's1',
        items: songs(3),
        index: 1,
      );

      final back = RemoteCommand.fromJson(sent.toJson())!;

      expect(back.kind, RemoteCommandKind.playItem);
      expect(back.itemId, 'id1');
      expect(back.queueIds, <String>['id0', 'id1', 'id2']);
      expect(back.queueTitles[2], 'Song 2');
      expect(back.queueIndex, 1);
    });

    test('a long queue is cut around the current song, and fits a message', () {
      final sent = RemoteCommand.playQueue(
        serverId: 's1',
        items: <(String, String)>[
          for (var i = 0; i < 2000; i++)
            ('0123456789abcdef0123456789abc$i', 'x' * 200),
        ],
        index: 1500,
      );

      expect(sent.queueIds, hasLength(RemoteCommand.maxQueueItems));
      expect(sent.queueIds[sent.queueIndex], sent.itemId);
      expect(sent.queueIndex, 50);
      expect(sent.queueTitles.first, hasLength(80));
      expect(
        sent.toJson().toString().length,
        lessThan(RemoteProtocol.maxMessageBytes),
      );
    });

    test('a queue that does not line up plays the one item', () {
      final json = RemoteCommand.playQueue(
        serverId: 's1',
        items: songs(3),
        index: 1,
      ).toJson()..['queueIndex'] = 9;

      final back = RemoteCommand.fromJson(json)!;

      expect(back.itemId, 'id1');
      expect(back.queueIds, isEmpty);
    });

    test('an old command with no queue still reads', () {
      final back = RemoteCommand.fromJson(const <String, Object?>{
        'c': 'playItem',
        'serverId': 's1',
        'itemId': 'a',
      })!;

      expect(back.itemId, 'a');
      expect(back.queueIds, isEmpty);
    });

    test('the state carries what a phone shows for a song', () {
      const sent = RemoteSnapshot(
        title: 'Song',
        artist: 'Daft Punk',
        album: 'Discovery',
        queueIndex: 2,
        queueLength: 12,
      );

      final back = RemoteSnapshot.fromJson(sent.toJson());

      expect(back.artist, 'Daft Punk');
      expect(back.album, 'Discovery');
      expect(back.queueIndex, 2);
      expect(back.queueLength, 12);
      expect(back.sameApartFromPosition(sent), isTrue);
      expect(
        back.sameApartFromPosition(
          const RemoteSnapshot(
            title: 'Song',
            artist: 'Daft Punk',
            album: 'Discovery',
            queueIndex: 3,
            queueLength: 12,
          ),
        ),
        isFalse,
      );
    });
  });
}
