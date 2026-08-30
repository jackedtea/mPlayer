// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

/// A [MediaLibrarySource] that answers nothing, so a test can override the
/// two or three methods it actually exercises.
///
/// The alternative — `implements MediaLibrarySource` in every test file — put
/// sixty lines of "returns an empty list" stub in each, and every method added
/// to the interface broke all of them at once. `extends` this instead, and a
/// test says only what it is about.
library;

import 'package:mplayer/servers/media_library_source.dart';
import 'package:mplayer/servers/server_profile.dart';

const fakeServerProfile = ServerProfile(
  id: 'p1',
  kind: ServerKind.jellyfin,
  name: 'Home',
  uri: 'https://media.home.lan',
  userId: 'u1',
  username: 'nam',
);

class FakeLibrarySource implements MediaLibrarySource {
  const FakeLibrarySource();

  @override
  ServerProfile get profile => fakeServerProfile;

  @override
  Future<ServerItem> item(String itemId) async =>
      ServerItem(id: itemId, title: itemId);

  @override
  Future<ServerPlayback> playback(
    String itemId,
    PlaybackCapabilities caps, {
    int? audioStreamIndex,
    int? subtitleStreamIndex,
    String? mediaSourceId,
  }) async {
    return ServerPlayback(
      uri: Uri.parse('https://media.home.lan/Videos/$itemId/stream'),
      isDirectPlay: true,
    );
  }

  @override
  Future<List<ServerItem>> items(
    String viewId, {
    int startIndex = 0,
    int limit = 100,
    ServerSort sort = ServerSort.name,
  }) async =>
      const <ServerItem>[];

  @override
  Future<List<ServerItem>> episodes(String seriesId, {String? seasonId}) async =>
      const <ServerItem>[];

  @override
  Future<List<ServerItem>> resumable({int limit = 12, String? viewId}) async =>
      const <ServerItem>[];

  @override
  Future<List<ServerItem>> nextUp({int limit = 12, String? viewId}) async =>
      const <ServerItem>[];

  @override
  Future<List<ServerItem>> favourites(String viewId) async =>
      const <ServerItem>[];

  @override
  Future<List<ServerItem>> collections(String viewId) async =>
      const <ServerItem>[];

  @override
  Future<List<ServerShelf>> suggestions(String viewId) async =>
      const <ServerShelf>[];

  @override
  Future<List<MediaSegment>> segments(String itemId) async =>
      const <MediaSegment>[];

  @override
  Future<List<ServerItem>> search(String query, {int limit = 40}) async =>
      const <ServerItem>[];

  @override
  Future<List<ServerItem>> similar(String itemId, {int limit = 12}) async =>
      const <ServerItem>[];

  @override
  Future<List<ServerItem>> personItems(String personId, {int limit = 100}) async =>
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
    String playlistId,
    List<String> entryIds,
  ) async {}

  @override
  Future<String?> createPlaylist(String name, List<String> itemIds) async => null;

  @override
  Future<void> reportProgress(
    String itemId, {
    required Duration position,
    required bool isPaused,
    String? playSessionId,
  }) async {}

  @override
  Future<void> reportStopped(
    String itemId, {
    required Duration position,
    String? playSessionId,
  }) async {}

  @override
  Future<void> setFavourite(String itemId, {required bool favourite}) async {}

  @override
  Future<void> setPlayed(String itemId, {required bool played}) async {}

  @override
  Future<List<LibraryView>> views() async => const <LibraryView>[];

  @override
  Future<int> itemCount(String viewId) async => 0;

  @override
  Uri? imageUrl(ServerItem item, {int? maxWidth}) => null;

  @override
  Uri? backdropUrl(ServerItem item, {int? maxWidth}) => null;

  @override
  Uri? personImageUrl(ServerPerson person, {int? maxWidth}) => null;

  @override
  Uri? chapterImageUrl(String itemId, ServerChapter chapter, {int? maxWidth}) =>
      null;

  @override
  Future<void> dispose() async {}
}
