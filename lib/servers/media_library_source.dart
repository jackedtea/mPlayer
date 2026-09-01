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
    this.backdropTag,
    this.backdropOwnerId,
    this.originalTitle,
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
    this.chapters = const <ServerChapter>[],
    this.trickplay,
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

  /// The wide artwork behind a detail header, where the server holds one.
  ///
  /// Separate from [imageTag] because they are different pictures: the
  /// primary image of a series is its portrait poster, and stretching that
  /// across the top of the screen crops it to a chin and a shoulder.
  final String? backdropTag;

  /// Which item [backdropTag] belongs to — an episode borrows its series'
  /// backdrop the same way it borrows the poster.
  final String? backdropOwnerId;

  /// The title in the language it was made in, where that is not [title].
  ///
  /// Only the detail fetch asks for it: a grid draws one title per poster,
  /// and the second one is what the detail header shows under the first.
  final String? originalTitle;

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

  /// The server's own chapter list, with the stills it generated.
  ///
  /// Empty unless the request asked for it, which only the detail fetch does:
  /// a hundred-item listing carrying a chapter list each is a hundred times
  /// the payload for something no card draws.
  final List<ServerChapter> chapters;

  /// The scrubber preview sheets, where the server has generated them.
  final ServerTrickplay? trickplay;

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
    this.externalSubtitles = const <ExternalSubtitle>[],
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

  /// The subtitles that arrive as files of their own, already resolved
  /// against the server root and carrying the token.
  ///
  /// These are the ones a direct play would otherwise lose: the video is
  /// handed over untouched and the sidecar simply never travels with it.
  final List<ExternalSubtitle> externalSubtitles;

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
    this.deliveryUrl,
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

  /// Where this track is fetched from, when it is **not** inside the video.
  ///
  /// Set on subtitles the server keeps as separate files. Relative to the
  /// server root as it arrives; [ServerPlayback.externalSubtitles] is the
  /// resolved form the player can actually open.
  final String? deliveryUrl;

  /// A track the decoder will never find on its own.
  bool get isExternal => deliveryUrl != null && deliveryUrl!.isNotEmpty;

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

/// A stretch of a file the server has labelled as something other than the
/// programme itself.
///
/// Not a chapter. A chapter says *where* something is; a segment says **what**
/// it is, and that is the whole difference — "Skip intro" needs a server that
/// knows the opening titles run from 1:04 to 2:34, not a rip whose author
/// happened to name a chapter "Intro".
///
/// Jellyfin 10.10 and later. An older server answers 404 and the client
/// reports no segments, which is not an error: everything else still works.
enum MediaSegmentKind {
  intro,
  outro,
  preview,
  recap,
  commercial,

  /// A type this app has never heard of. Never acted on — a segment nobody
  /// can label is a segment nobody should be silently seeking past.
  unknown;

  /// The server's own spelling, which is what the request filters on.
  String get wireName => switch (this) {
        MediaSegmentKind.intro => 'Intro',
        MediaSegmentKind.outro => 'Outro',
        MediaSegmentKind.preview => 'Preview',
        MediaSegmentKind.recap => 'Recap',
        MediaSegmentKind.commercial => 'Commercial',
        MediaSegmentKind.unknown => 'Unknown',
      };

  static MediaSegmentKind fromWire(String? name) => switch (name) {
        'Intro' => MediaSegmentKind.intro,
        'Outro' => MediaSegmentKind.outro,
        'Preview' => MediaSegmentKind.preview,
        'Recap' => MediaSegmentKind.recap,
        'Commercial' => MediaSegmentKind.commercial,
        _ => MediaSegmentKind.unknown,
      };
}

/// The kinds this app asks for and is willing to act on.
///
/// Sent as the request filter as well as checked on the way back: a server
/// that grows a sixth type should not start producing a pill labelled with an
/// enum name.
const supportedSegmentKinds = <MediaSegmentKind>[
  MediaSegmentKind.intro,
  MediaSegmentKind.outro,
  MediaSegmentKind.preview,
  MediaSegmentKind.recap,
  MediaSegmentKind.commercial,
];

@immutable
class MediaSegment {
  const MediaSegment({
    required this.kind,
    required this.start,
    required this.end,
  });

  final MediaSegmentKind kind;

  /// Zero is ordinary here and means the file opens on it. This is why
  /// positions are parsed differently from runtimes — a runtime of zero is a
  /// missing value, a start of zero is the first frame.
  final Duration start;

  final Duration end;

  Duration get length => end - start;

  bool contains(Duration position) => position >= start && position < end;

  @override
  bool operator ==(Object other) =>
      other is MediaSegment &&
      other.kind == kind &&
      other.start == start &&
      other.end == end;

  @override
  int get hashCode => Object.hash(kind, start, end);
}

/// A chapter as the *server* holds it, with the artwork it generated for it.
///
/// Distinct from the player's `MediaChapter`, which is also fed by the
/// container: only a server chapter has a picture to show.
@immutable
class ServerChapter {
  const ServerChapter({
    required this.index,
    required this.title,
    required this.start,
    this.imageTag,
  });

  /// Its position in the server's list, which is what the image route is
  /// numbered by — not an id.
  final int index;

  final String title;
  final Duration start;

  /// Null on every chapter of an item the server has not extracted stills
  /// for, which is the default until trickplay or chapter images are enabled.
  final String? imageTag;
}

/// The sprite sheets a server generates so a client can preview a scrub.
///
/// One image holds [tileWidth] × [tileHeight] thumbnails, one every
/// [interval] milliseconds, so the frame for a position is an offset inside a
/// tile rather than a request of its own. That is the whole point: a scrub
/// across a two-hour film costs a handful of images instead of a thousand.
@immutable
class ServerTrickplay {
  const ServerTrickplay({
    required this.width,
    required this.height,
    required this.tileWidth,
    required this.tileHeight,
    required this.interval,
    required this.thumbnailCount,
    required this.tileUrl,
  });

  /// One thumbnail's pixel size.
  final int width;
  final int height;

  /// How many thumbnails a sheet holds, across and down.
  final int tileWidth;
  final int tileHeight;

  /// Milliseconds between thumbnails.
  final int interval;

  final int thumbnailCount;

  /// The sheet holding thumbnail number *n*, ready to fetch.
  final Uri Function(int tileIndex) tileUrl;

  /// How many thumbnails one sheet holds.
  int get perTile => tileWidth * tileHeight;

  /// Which thumbnail covers [position], or null when it falls outside what
  /// the server generated.
  TrickplayTile? tileFor(Duration position) {
    if (interval <= 0 || perTile <= 0) return null;

    final thumbnail = position.inMilliseconds ~/ interval;
    if (thumbnail < 0 || (thumbnailCount > 0 && thumbnail >= thumbnailCount)) {
      return null;
    }

    final offset = thumbnail % perTile;
    return TrickplayTile(
      url: tileUrl(thumbnail ~/ perTile),
      // Where in the sheet this frame sits, in pixels.
      left: (offset % tileWidth) * width,
      top: (offset ~/ tileWidth) * height,
      width: width,
      height: height,
    );
  }
}

/// One frame, named as a rectangle inside a sheet.
@immutable
class TrickplayTile {
  const TrickplayTile({
    required this.url,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final Uri url;
  final int left;
  final int top;
  final int width;
  final int height;

  @override
  bool operator ==(Object other) =>
      other is TrickplayTile &&
      other.url == url &&
      other.left == left &&
      other.top == top;

  @override
  int get hashCode => Object.hash(url, left, top);
}

/// A subtitle the server keeps as a file of its own rather than inside the
/// video.
///
/// The player has to be told about these explicitly. An embedded track
/// arrives with the stream and the decoder finds it; an external one is a
/// second URL that nothing would ever fetch on its own, and the user is left
/// looking at a subtitle picker missing the language they came for.
@immutable
class ExternalSubtitle {
  const ExternalSubtitle({
    required this.uri,
    required this.label,
    this.language,
    this.index,
  });

  final Uri uri;

  /// The server's own description — "English - SRT".
  final String label;

  final String? language;

  /// The stream index it was numbered under, so a choice made on the detail
  /// screen can still be matched to the track mpv ends up publishing.
  final int? index;
}


/// Why a server put a shelf of items in front of the user.
///
/// The *reason*, not a sentence. Jellyfin hands back "SimilarToRecentlyPlayed"
/// and the film it was reasoning from; turning that into "Because you watched
/// Dune" needs a locale and a phrasing decision, and neither belongs behind an
/// HTTP client — the screen does it.
enum SuggestionKind {
  similarToRecentlyPlayed,
  similarToLiked,
  directorFromRecentlyPlayed,
  actorFromRecentlyPlayed,
  likedDirector,
  likedActor,

  /// A reason this app has no wording for. The shelf still draws, titled
  /// with the subject alone — the films are the point, and dropping them
  /// because the label is unfamiliar helps nobody.
  unknown;

  static SuggestionKind fromWire(String? name) => switch (name) {
        'SimilarToRecentlyPlayed' => SuggestionKind.similarToRecentlyPlayed,
        'SimilarToLikedItem' => SuggestionKind.similarToLiked,
        'HasDirectorFromRecentlyPlayed' =>
          SuggestionKind.directorFromRecentlyPlayed,
        'HasActorFromRecentlyPlayed' => SuggestionKind.actorFromRecentlyPlayed,
        'HasLikedDirector' => SuggestionKind.likedDirector,
        'HasLikedActor' => SuggestionKind.likedActor,
        _ => SuggestionKind.unknown,
      };
}

/// One row of suggestions, and the server's reason for it.
@immutable
class ServerShelf {
  const ServerShelf({
    required this.kind,
    required this.items,
    this.subject = '',
  });

  final SuggestionKind kind;

  /// What the reason is *about* — the film watched, the director liked. Empty
  /// where the server named nobody, which some recommendation types do.
  final String subject;

  final List<ServerItem> items;
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
  ///
  /// [order] is null for the sort's own natural direction — a name reads A-Z,
  /// a date newest first — and set only where the user has said otherwise.
  Future<List<ServerItem>> items(
    String viewId, {
    int startIndex = 0,
    int limit = 100,
    ServerSort sort = ServerSort.name,
    SortOrder? order,
    LibraryFilter filter = LibraryFilter.none,
  });

  /// The values a library can actually be filtered by.
  ///
  /// Asked of the server rather than derived from a page of items: the grid
  /// holds a hundred of several hundred, and a genre list built from those
  /// would be missing whatever the first page happens not to contain.
  ///
  /// Empty rather than an error wherever the server will not answer — a
  /// filter sheet with fewer sections is worth more than a screen that
  /// refuses to open.
  Future<LibraryFilterOptions> filterOptions(String viewId);

  /// Everything the detail screen shows for one item.
  Future<ServerItem> item(String itemId);

  /// Episodes of a season, in order.
  Future<List<ServerItem>> episodes(String seriesId, {String? seasonId});

  /// What the user was watching, most recent first.
  ///
  /// [viewId] narrows it to one library, which is what a library's own
  /// Suggestions tab wants: a film left half-watched has no place on a shelf
  /// inside the shows library.
  Future<List<ServerItem>> resumable({int limit = 12, String? viewId});

  /// The next unwatched episode of each series in progress.
  Future<List<ServerItem>> nextUp({int limit = 12, String? viewId});

  /// What the user has starred inside [viewId].
  ///
  /// The same item types the grid lists, deliberately. A favourited episode
  /// exists and is not returned: every tile here opens a detail screen, and
  /// there is none that an episode on its own belongs on.
  Future<List<ServerItem>> favourites(String viewId);

  /// The box sets drawing on [viewId].
  ///
  /// A collection is not *inside* a library — it lives in its own folder and
  /// points at items across several. Asked for by parent anyway, because that
  /// is how the server answers "which collections does this library feed".
  Future<List<ServerItem>> collections(String viewId);

  /// What the server suggests from [viewId], as titled rows.
  ///
  /// Empty rather than an error wherever the server has no opinion — a fresh
  /// account with no watch history has nothing to reason from, and neither
  /// does a library the server offers no recommendations for.
  Future<List<ServerShelf>> suggestions(String viewId);

  Future<List<ServerItem>> search(String query, {int limit = 40});

  /// Everything [personId] appears in.
  ///
  /// Films and series only: an actor credited on forty episodes of one show
  /// should read as that one show, not as forty rows of it.
  Future<List<ServerItem>> personItems(String personId, {int limit = 100});

  /// What the server thinks resembles [itemId].
  ///
  /// Empty rather than an error when the server has no opinion — a shelf that
  /// cannot be filled is simply not drawn.
  Future<List<ServerItem>> similar(String itemId, {int limit = 12});

  /// Artwork, or null when the item has none.
  Uri? imageUrl(ServerItem item, {int? maxWidth});

  /// The wide artwork behind a detail header, or null where the server holds
  /// none — which is common enough that every caller has to have a poster to
  /// fall back on.
  Uri? backdropUrl(ServerItem item, {int? maxWidth});

  /// A person's headshot, or null when the server holds none.
  Uri? personImageUrl(ServerPerson person, {int? maxWidth});

  /// The still the server generated for a chapter, or null where it has none.
  ///
  /// Takes the item as well as the chapter because the route is numbered
  /// rather than identified: a chapter still is the *n*th image of an item,
  /// and the chapter alone does not say whose.
  Uri? chapterImageUrl(String itemId, ServerChapter chapter, {int? maxWidth});

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

  /// The labelled stretches of [itemId] — intro, outro, recap and the rest.
  ///
  /// Empty rather than an error for a server too old to have the endpoint:
  /// media segments arrived in Jellyfin 10.10, and an item nobody has run a
  /// detection plugin over has none either. Neither is a failure worth
  /// showing anyone.
  Future<List<MediaSegment>> segments(String itemId);

  Future<void> setPlayed(String itemId, {required bool played});

  Future<void> setFavourite(String itemId, {required bool favourite});

  /// Releases the HTTP client.
  Future<void> dispose();
}

/// What a library listing is ordered by.
///
/// The order is part of the *request*: the server does the sorting, so
/// changing it refetches rather than reordering what is already on screen.
/// Which also means an entry exists here only where the server has a field
/// behind it — there is no sorting by anything this app would have to
/// compute over a page it only partly holds.
enum ServerSort {
  name,
  random,
  communityRating,

  /// When the item itself was added to the library.
  dateAdded,

  /// When the newest *episode* under it landed, which is not when the series
  /// did. Meaningless outside a shows library, and offered only there.
  dateEpisodeAdded,

  datePlayed,

  /// The certificate — G before PG before R.
  parentalRating,

  releaseDate;

  /// Which way this sort reads when nobody has said otherwise.
  ///
  /// A name and a certificate ascend; everything else is newest or highest
  /// first, because "recently added, oldest first" is not what anyone
  /// choosing it meant.
  SortOrder get naturalOrder => switch (this) {
        ServerSort.name ||
        ServerSort.releaseDate ||
        ServerSort.parentalRating =>
          SortOrder.ascending,
        _ => SortOrder.descending,
      };
}

enum SortOrder { ascending, descending }

/// A watch-state constraint the server applies to a listing.
///
/// [played] and [unplayed] are both here and are not a single tri-state on
/// purpose: the server takes them as a set, and asking for neither — which
/// is the default — is not the same as asking for both.
enum ItemFilter { played, unplayed, favourite, resumable }

/// Whether a series is still running.
///
/// Only a shows library has these; a film is neither continuing nor ended.
enum SeriesStatus { continuing, ended }

/// Something the server holds *alongside* the film itself.
enum ItemFeature { subtitles, trailer, specialFeature, themeSong, themeVideo }

/// Everything the filter sheet can narrow a library listing by.
///
/// Sets rather than single values throughout, because every one of these is
/// an "any of" on the wire: two genres selected means either, not both.
@immutable
class LibraryFilter {
  const LibraryFilter({
    this.flags = const <ItemFilter>{},
    this.status = const <SeriesStatus>{},
    this.features = const <ItemFeature>{},
    this.genres = const <String>{},
    this.parentalRatings = const <String>{},
    this.tags = const <String>{},
    this.years = const <int>{},
  });

  /// Nothing narrowed — what a library opens on. Hiding most of a collection
  /// until the user notices a control is the wrong first impression.
  static const LibraryFilter none = LibraryFilter();

  final Set<ItemFilter> flags;
  final Set<SeriesStatus> status;
  final Set<ItemFeature> features;
  final Set<String> genres;
  final Set<String> parentalRatings;
  final Set<String> tags;
  final Set<int> years;

  bool get isEmpty => count == 0;

  /// How many constraints are on — the number on the filter button, which is
  /// the only thing telling a user why a library looks half empty.
  int get count =>
      flags.length +
      status.length +
      features.length +
      genres.length +
      parentalRatings.length +
      tags.length +
      years.length;

  LibraryFilter copyWith({
    Set<ItemFilter>? flags,
    Set<SeriesStatus>? status,
    Set<ItemFeature>? features,
    Set<String>? genres,
    Set<String>? parentalRatings,
    Set<String>? tags,
    Set<int>? years,
  }) {
    return LibraryFilter(
      flags: flags ?? this.flags,
      status: status ?? this.status,
      features: features ?? this.features,
      genres: genres ?? this.genres,
      parentalRatings: parentalRatings ?? this.parentalRatings,
      tags: tags ?? this.tags,
      years: years ?? this.years,
    );
  }

  /// Adds or removes one value of a set, which is what a checkbox does.
  static Set<T> toggled<T>(Set<T> from, T value, bool on) {
    final next = Set<T>.of(from);
    on ? next.add(value) : next.remove(value);
    return next;
  }

  // Value equality is not decoration here: this is half of a provider family
  // key, so an identical filter built twice has to be the same request rather
  // than a second one.
  @override
  bool operator ==(Object other) =>
      other is LibraryFilter &&
      setEquals(other.flags, flags) &&
      setEquals(other.status, status) &&
      setEquals(other.features, features) &&
      setEquals(other.genres, genres) &&
      setEquals(other.parentalRatings, parentalRatings) &&
      setEquals(other.tags, tags) &&
      setEquals(other.years, years);

  @override
  int get hashCode => Object.hash(
        Object.hashAllUnordered(flags),
        Object.hashAllUnordered(status),
        Object.hashAllUnordered(features),
        Object.hashAllUnordered(genres),
        Object.hashAllUnordered(parentalRatings),
        Object.hashAllUnordered(tags),
        Object.hashAllUnordered(years),
      );
}

/// What one library actually holds to be filtered by.
///
/// Four lists the server compiles from the library itself, so the sheet
/// offers the genres that occur in it rather than a fixed vocabulary that
/// would mostly return nothing.
@immutable
class LibraryFilterOptions {
  const LibraryFilterOptions({
    this.genres = const <String>[],
    this.parentalRatings = const <String>[],
    this.tags = const <String>[],
    this.years = const <int>[],
  });

  /// What a server that will not answer gets: the sheet then draws the
  /// sections it can build without asking anything, and no empty headings.
  static const LibraryFilterOptions empty = LibraryFilterOptions();

  final List<String> genres;
  final List<String> parentalRatings;
  final List<String> tags;
  final List<int> years;

  bool get isEmpty =>
      genres.isEmpty &&
      parentalRatings.isEmpty &&
      tags.isEmpty &&
      years.isEmpty;
}

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
