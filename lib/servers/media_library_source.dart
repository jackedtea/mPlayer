// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

/// What a server hands over, before anything has been formatted for a screen.
///
/// Deliberately **not** the `core/models/library_models.dart` types: those
/// carry strings the design already shaped — "2h 16m", "48m · watched",
/// "Resume · 41m left" — and an `IconData`. Building those in the data layer
/// would put date formatting and translation behind the network client, where
/// neither belongs. The screens map these to those.
library;

import 'package:flutter/foundation.dart';

import 'server_profile.dart';

/// A top-level library: Movies, Shows, Music.
@immutable
class LibraryView {
  const LibraryView({required this.id, required this.name, required this.kind});

  final String id;
  final String name;

  /// `movies`, `tvshows`, `music`, `boxsets`, … as the server names it. Left
  /// as the server's own string rather than an enum: a collection type this
  /// app has never heard of should still list.
  final String kind;

  // There is deliberately no item count here. `/UserViews` answers with a
  // `ChildCount`, and on a library it is not the number of items in it — the
  // dev server returns 7 for a library of 99 films, 7 for one of 8 series and
  // 7 for a collection folder holding 32 box sets. Whatever it counts, it is
  // not what a user reading "8 items" would understand. The real number comes
  // from [itemCount], which asks the server to count.
}

/// One entry in a library, a shelf, or a search result.
@immutable
class ServerItem {
  const ServerItem({
    required this.id,
    required this.title,
    this.kind = ServerItemKind.unknown,
    this.year,
    this.overview,
    this.runtime,
    this.position,
    this.played = false,
    this.favourite = false,
    this.imageTag,
    this.imageOwnerId,
    this.seriesId,
    this.seriesTitle,
    this.seasonNumber,
    this.episodeNumber,
    this.rating,
    this.certificate,
    this.genres = const <String>[],
    this.people = const <ServerPerson>[],
    this.childCount,
    this.tags = const <String>[],
    this.studios = const <String>[],
    this.status,
    this.endYear,
    this.playlistEntryId,
  });

  final String id;
  final String title;
  final ServerItemKind kind;

  final int? year;
  final String? overview;
  final Duration? runtime;

  /// Where the user left off. Null means never started — which is not the
  /// same as being at zero, and the two drive different buttons.
  final Duration? position;

  final bool played;
  final bool favourite;

  /// Changes whenever the artwork does, so it is part of the image URL and
  /// what makes caching safe.
  final String? imageTag;

  /// Which item [imageTag] belongs to.
  ///
  /// Usually this item. An episode with no artwork of its own borrows the
  /// series', and then the tag and the id have to travel together — asking
  /// this item for a tag that belongs to its series returns nothing.
  final String? imageOwnerId;

  final String? seriesId;
  final String? seriesTitle;
  final int? seasonNumber;
  final int? episodeNumber;

  /// Community rating out of ten, as the server holds it. Null where nobody
  /// has rated it — which is not the same as zero.
  final double? rating;

  /// "PG-13". The server calls this the official rating.
  final String? certificate;

  final List<String> genres;

  /// Cast and crew, in the order the server lists them — which is the order
  /// billing was decided in, and better than anything this app could sort by.
  final List<ServerPerson> people;

  /// Keywords the server holds alongside the genres.
  ///
  /// Empty unless the request asked for them: no screen shows keywords, so
  /// `Tags` is not in the field list the client sends. Parsed and kept
  /// because the field list is the only thing standing between here and a
  /// screen that wants them.
  final List<String> tags;

  final List<String> studios;

  /// "Continuing" or "Ended", for a series. Null for everything else.
  final String? status;

  /// When a series finished. Null while it is still running, and null for a
  /// film, where [year] is the whole story.
  final int? endYear;

  /// This item's identity *inside a playlist*, which is not its own id: the
  /// same film can sit in a playlist twice, and a removal names the entry
  /// rather than the film. Null everywhere outside a playlist listing.
  final String? playlistEntryId;

  /// Seasons on a series, episodes on a season.
  final int? childCount;

  bool get isStarted => position != null && position! > Duration.zero;

  /// 0..1, or null when there is nothing to draw a bar from.
  double? get watchedFraction {
    final total = runtime;
    final at = position;
    if (total == null || at == null || total <= Duration.zero) return null;
    return (at.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
  }
}

/// A collection is a [folder] the design treats as a poster: it is browsed,
/// not played, and getting that wrong opens a Play button over a box set.
enum ServerItemKind {
  movie,
  series,
  season,
  episode,
  video,
  folder,
  collection,
  unknown;

  /// Whether tapping this opens a grid of its children rather than a detail.
  bool get isBrowsable => this == folder || this == collection;
}

/// Somebody in the cast strip.
@immutable
class ServerPerson {
  const ServerPerson({
    required this.name,
    required this.role,
    this.id,
    this.imageTag,
  });

  final String name;

  /// The character played, or the job done. Empty when the server did not
  /// say, which the strip renders as a blank second line rather than a guess.
  final String role;

  final String? id;

  /// Their headshot, if the server holds one. Null is common — a person
  /// scraped from an episode credit often has no image at all.
  final String? imageTag;
}

/// How the server says a file should be played.
@immutable
class ServerPlayback {
  const ServerPlayback({
    required this.uri,
    required this.isDirectPlay,
    this.headers = const <String, String>{},
    this.playSessionId,
    this.container,
    this.bitrate,
    this.streams = const <ServerStream>[],
    this.mediaSourceId,
    this.defaultAudioIndex,
    this.defaultSubtitleIndex,
    this.supportsTranscoding = false,
  });

  final Uri uri;

  /// False when the server is re-encoding. The player says so in its source
  /// line, and it is the only thing that makes the quality control mean
  /// anything.
  final bool isDirectPlay;

  final Map<String, String> headers;

  /// Echoed back with every progress report, and needed to stop a transcode
  /// the user walked away from.
  final String? playSessionId;

  final String? container;
  final int? bitrate;

  /// Every track in the file, as the server describes it.
  ///
  /// Known *before* a decoder has opened anything, which is the whole point:
  /// it is what lets the user choose an audio track on the detail screen
  /// rather than after the film has already started in the wrong language.
  final List<ServerStream> streams;

  /// Which of an item's files this is. A film with two rips has two, and the
  /// index numbers only mean anything against the one they came from.
  final String? mediaSourceId;

  /// What the server would have picked. Null for subtitles means "none",
  /// which is not the same as "the server did not say".
  final int? defaultAudioIndex;
  final int? defaultSubtitleIndex;

  /// Whether the server is willing to re-encode. False makes the quality
  /// control meaningless, so it is hidden rather than shown doing nothing.
  final bool supportsTranscoding;

  List<ServerStream> streamsOfType(ServerStreamType type) =>
      streams.where((s) => s.type == type).toList();
}

enum ServerStreamType { video, audio, subtitle, unknown }

/// One track inside a file, as the server reports it.
@immutable
class ServerStream {
  const ServerStream({
    required this.index,
    required this.type,
    this.codec,
    this.language,
    this.title,
    this.isDefault = false,
    this.isForced = false,
    this.bitrate,
    this.width,
    this.height,
    this.channels,
  });

  /// The server's own index, which is what a playback request quotes back.
  /// Not a position in any list this app builds.
  final int index;

  final ServerStreamType type;
  final String? codec;
  final String? language;

  /// The server's assembled description — "English - Dolby Digital - 5.1".
  /// Worth preferring over anything reassembled here, because the server has
  /// fields this app does not model.
  final String? title;

  final bool isDefault;
  final bool isForced;

  final int? bitrate;
  final int? width;
  final int? height;
  final int? channels;

  /// What to show when the server supplied no description of its own.
  String get label {
    final assembled = title;
    if (assembled != null && assembled.trim().isNotEmpty) return assembled.trim();

    return <String>[
      if (language != null && language!.isNotEmpty) language!,
      if (codec != null && codec!.isNotEmpty) codec!.toUpperCase(),
      if (channels != null) '$channels ch',
    ].join(' · ');
  }
}

/// A catalog-level source: metadata, artwork, playback URLs and watch state,
/// already assembled by something else.
///
/// The counterpart to `MediaSource`, which hands over bytes and nothing more.
/// A server never implements `BrowsableSource`: a Jellyfin library is browsed
/// by collection, not by path.
abstract class MediaLibrarySource {
  ServerProfile get profile;

  /// The libraries the signed-in user can see.
  Future<List<LibraryView>> views();

  /// How many items a library holds.
  ///
  /// A request of its own because the only trustworthy source for it is a
  /// listing's `TotalRecordCount`, which means asking for the listing — with
  /// a limit of zero, so the server counts without sending anything.
  Future<int> itemCount(String viewId);

  /// One library's contents.
  Future<List<ServerItem>> items(
    String viewId, {
    int startIndex = 0,
    int limit = 100,
    ServerSort sort = ServerSort.name,
  });

  /// Everything the detail screen shows for one item.
  Future<ServerItem> item(String itemId);

  /// Episodes of a season, in order.
  Future<List<ServerItem>> episodes(String seriesId, {String? seasonId});

  /// What the user was watching, most recent first.
  Future<List<ServerItem>> resumable({int limit = 12});

  /// The next unwatched episode of each series in progress.
  Future<List<ServerItem>> nextUp({int limit = 12});

  Future<List<ServerItem>> search(String query, {int limit = 40});

  /// What the server thinks resembles [itemId].
  ///
  /// Empty rather than an error when the server has no opinion — a shelf that
  /// cannot be filled is simply not drawn.
  Future<List<ServerItem>> similar(String itemId, {int limit = 12});

  /// Artwork, or null when the item has none.
  Uri? imageUrl(ServerItem item, {int? maxWidth});

  /// A person's headshot, or null when the server holds none.
  Uri? personImageUrl(ServerPerson person, {int? maxWidth});

  /// How to play [itemId], given what this device can decode.
  ///
  /// The stream indexes are the server's own, taken from a previous
  /// [ServerPlayback]. Passing them is what makes a chosen audio track
  /// survive a transcode: the server bakes the choice into the stream it
  /// produces, and there is nothing for the player to select afterwards.
  Future<ServerPlayback> playback(
    String itemId,
    PlaybackCapabilities caps, {
    int? audioStreamIndex,
    int? subtitleStreamIndex,
    String? mediaSourceId,
  });

  /// The playlists this user owns.
  Future<List<ServerItem>> playlists();

  /// What is in one playlist.
  ///
  /// The entries carry a `playlistEntryId` distinct from the item's own id,
  /// which is what a removal has to quote.
  Future<List<ServerItem>> playlistItems(String playlistId);

  /// Adds [itemIds] to [playlistId].
  Future<void> addToPlaylist(String playlistId, List<String> itemIds);

  /// Removes [entryIds] from [playlistId].
  ///
  /// The ids are *playlist entry* ids, not item ids: the same film can sit in
  /// a playlist twice and only one of them is meant to go.
  Future<void> removeFromPlaylist(String playlistId, List<String> entryIds);

  /// Creates a playlist holding [itemIds] and returns its id.
  Future<String?> createPlaylist(String name, List<String> itemIds);

  /// Tells the server where playback got to. Called on start, periodically,
  /// and once on stop — the server is the authority on watch state when two
  /// devices disagree.
  Future<void> reportProgress(
    String itemId, {
    required Duration position,
    required bool isPaused,
    String? playSessionId,
  });

  Future<void> reportStopped(
    String itemId, {
    required Duration position,
    String? playSessionId,
  });

  Future<void> setPlayed(String itemId, {required bool played});

  Future<void> setFavourite(String itemId, {required bool favourite});

  /// Releases the HTTP client.
  Future<void> dispose();
}

enum ServerSort { name, dateAdded, datePlayed, releaseDate, random }

/// What this device can play without help.
///
/// Sent with every playback request: the server decides between direct play
/// and a transcode from it, so being honest here is what keeps a file from
/// being re-encoded for no reason.
@immutable
class PlaybackCapabilities {
  const PlaybackCapabilities({
    this.maxBitrate,
    this.maxHeight,
    this.supportsHevc = true,
    this.supportsAv1 = false,
  });

  /// Null means no cap, which is the right default on a LAN.
  final int? maxBitrate;

  final int? maxHeight;

  /// libmpv decodes both in software wherever hardware cannot, so the honest
  /// answer for HEVC is yes. AV1 is left off by default: software AV1 on a
  /// phone is a slideshow, and a transcode is genuinely better.
  final bool supportsHevc;
  final bool supportsAv1;
}

/// A server that could not be reached or would not answer.
///
/// Carries a sentence fit to show the user, the same contract
/// [MediaSourceException] follows — a 401 from a server means "sign in
/// again", not "401".
class ServerException implements Exception {
  const ServerException(this.message, {this.isUnauthorised = false});

  final String message;

  /// True when the token has expired or been revoked, which the UI answers
  /// by asking for the password again rather than by showing an error.
  final bool isUnauthorised;

  @override
  String toString() => 'ServerException: $message';
}
