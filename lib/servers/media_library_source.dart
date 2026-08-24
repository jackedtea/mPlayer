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
  const LibraryView({
    required this.id,
    required this.name,
    required this.kind,
    this.itemCount,
  });

  final String id;
  final String name;

  /// `movies`, `tvshows`, `music`, `boxsets`, … as the server names it. Left
  /// as the server's own string rather than an enum: a collection type this
  /// app has never heard of should still list.
  final String kind;

  /// Null when the server did not say, which it often does not for a view.
  final int? itemCount;
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

enum ServerItemKind { movie, series, season, episode, video, folder, unknown }

/// Somebody in the cast strip.
@immutable
class ServerPerson {
  const ServerPerson({required this.name, required this.role, this.id});

  final String name;

  /// The character played, or the job done. Empty when the server did not
  /// say, which the strip renders as a blank second line rather than a guess.
  final String role;

  final String? id;
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

  /// Artwork, or null when the item has none.
  Uri? imageUrl(ServerItem item, {int? maxWidth});

  /// How to play [itemId], given what this device can decode.
  Future<ServerPlayback> playback(String itemId, PlaybackCapabilities caps);

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
