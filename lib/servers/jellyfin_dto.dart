// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

/// Reading what Jellyfin sends, and building what it expects.
///
/// Kept apart from the HTTP client on purpose: every function here is pure,
/// so the whole shape of the protocol can be tested against captured
/// responses with no server on the network — the same reason
/// `parsePropfind` lives apart from `WebDavSource`.
library;

import 'media_library_source.dart';

/// Jellyfin counts in **ticks**: 100 nanoseconds, so ten thousand to the
/// millisecond. Getting this wrong is the classic Jellyfin client bug — a
/// runtime out by a factor of ten thousand looks plausible enough to ship.
const ticksPerMillisecond = 10000;

Duration? ticksToDuration(Object? ticks) {
  final value = switch (ticks) {
    final int i => i,
    final num n => n.toInt(),
    _ => null,
  };
  if (value == null || value <= 0) return null;
  return Duration(milliseconds: value ~/ ticksPerMillisecond);
}

int durationToTicks(Duration duration) =>
    duration.inMilliseconds * ticksPerMillisecond;

/// The header every request carries.
///
/// Jellyfin parses this itself rather than using a standard scheme, and it is
/// strict about the shape: a quoted value per field, comma separated. The
/// token is absent until the user has signed in, and sending `Token=""` is
/// what a server reads as an anonymous request.
String authorizationHeader({
  required String client,
  required String device,
  required String deviceId,
  required String version,
  String? token,
}) {
  final fields = <String>[
    'Client="${_escape(client)}"',
    'Device="${_escape(device)}"',
    'DeviceId="${_escape(deviceId)}"',
    'Version="${_escape(version)}"',
    if (token != null && token.isNotEmpty) 'Token="${_escape(token)}"',
  ];
  return 'MediaBrowser ${fields.join(', ')}';
}

/// A device name is whatever the OS reports, and a quote in it would end the
/// field early.
String _escape(String value) => value.replaceAll('"', '');

/// One `BaseItemDto` from any of the item endpoints.
ServerItem serverItemFromJson(Map<String, dynamic> json) {
  final userData = json['UserData'] as Map<String, dynamic>?;

  return ServerItem(
    id: json['Id'] as String? ?? '',
    // A server can return an item with no name; showing the id beats showing
    // an empty row the user cannot identify.
    title: (json['Name'] as String?)?.trim().isNotEmpty ?? false
        ? (json['Name'] as String).trim()
        : (json['Id'] as String? ?? ''),
    kind: _kindFrom(json['Type'] as String?),
    year: json['ProductionYear'] as int?,
    overview: json['Overview'] as String?,
    runtime: ticksToDuration(json['RunTimeTicks']),
    position: ticksToDuration(userData?['PlaybackPositionTicks']),
    played: userData?['Played'] as bool? ?? false,
    favourite: userData?['IsFavorite'] as bool? ?? false,
    imageTag: _primaryImageTag(json),
    imageOwnerId: _imageOwnerId(json),
    seriesId: json['SeriesId'] as String?,
    seriesTitle: json['SeriesName'] as String?,
    seasonNumber: json['ParentIndexNumber'] as int?,
    episodeNumber: json['IndexNumber'] as int?,
  );
}

String? _primaryImageTag(Map<String, dynamic> json) {
  final tags = json['ImageTags'];
  if (tags is Map && tags['Primary'] is String) return tags['Primary'] as String;

  // An episode usually has no artwork of its own; the series' image is what
  // every client shows in its place.
  final parent = json['SeriesPrimaryImageTag'] ?? json['ParentPrimaryImageTag'];
  return parent is String ? parent : null;
}

/// Which item the tag [_primaryImageTag] found belongs to.
///
/// Only a *borrowed* tag changes the owner. An episode that has artwork of
/// its own keeps its own id, and getting this backwards asks the series for a
/// tag it has never heard of.
String? _imageOwnerId(Map<String, dynamic> json) {
  final tags = json['ImageTags'];
  if (tags is Map && tags['Primary'] is String) return json['Id'] as String?;

  if (json['SeriesPrimaryImageTag'] is String) {
    return json['SeriesId'] as String? ?? json['Id'] as String?;
  }
  if (json['ParentPrimaryImageTag'] is String) {
    return json['ParentId'] as String? ?? json['Id'] as String?;
  }
  return json['Id'] as String?;
}

ServerItemKind _kindFrom(String? type) {
  return switch (type) {
    'Movie' => ServerItemKind.movie,
    'Series' => ServerItemKind.series,
    'Season' => ServerItemKind.season,
    'Episode' => ServerItemKind.episode,
    'Video' => ServerItemKind.video,
    'Folder' || 'CollectionFolder' || 'BoxSet' => ServerItemKind.folder,
    _ => ServerItemKind.unknown,
  };
}

/// A library from `/UserViews`.
LibraryView libraryViewFromJson(Map<String, dynamic> json) {
  return LibraryView(
    id: json['Id'] as String? ?? '',
    name: json['Name'] as String? ?? '',
    // `CollectionType` is absent on a plain folder, which is still a library
    // worth listing.
    kind: json['CollectionType'] as String? ?? 'unknown',
    itemCount: json['ChildCount'] as int?,
  );
}

/// The `sortBy` value for a [ServerSort].
String sortByFor(ServerSort sort) {
  return switch (sort) {
    ServerSort.name => 'SortName',
    ServerSort.dateAdded => 'DateCreated',
    ServerSort.datePlayed => 'DatePlayed',
    ServerSort.releaseDate => 'PremiereDate',
    ServerSort.random => 'Random',
  };
}

/// Descending for everything that is "most recent first"; ascending for a
/// name. Sorting names backwards is never what anyone meant.
String sortOrderFor(ServerSort sort) {
  return switch (sort) {
    ServerSort.name || ServerSort.releaseDate => 'Ascending',
    _ => 'Descending',
  };
}

/// Turns a `PlaybackInfo` response into the one decision the player needs.
///
/// The rule Jellyfin actually follows: if the server put a `TranscodingUrl`
/// on the media source, it has decided to re-encode, whatever the
/// `SupportsDirectPlay` flags say. Those flags describe what is *possible*,
/// not what was chosen.
ServerPlayback? playbackFromJson(
  Map<String, dynamic> json, {
  required Uri base,
  required String itemId,
  required String token,
}) {
  final sources = json['MediaSources'];
  if (sources is! List || sources.isEmpty) return null;

  final source = sources.first;
  if (source is! Map) return null;

  final playSessionId = json['PlaySessionId'] as String?;
  final transcodingUrl = source['TranscodingUrl'] as String?;

  if (transcodingUrl != null && transcodingUrl.isNotEmpty) {
    return ServerPlayback(
      // Relative to the server root, and it already carries its own query.
      uri: base.resolve(transcodingUrl),
      isDirectPlay: false,
      playSessionId: playSessionId,
      container: source['Container'] as String?,
      bitrate: source['Bitrate'] as int?,
    );
  }

  final mediaSourceId = source['Id'] as String? ?? itemId;
  final container = source['Container'] as String?;

  return ServerPlayback(
    // `static=true` is what tells the server to hand the file over untouched.
    uri: base.replace(
      pathSegments: <String>[
        ...base.pathSegments.where((s) => s.isNotEmpty),
        'Videos',
        itemId,
        'stream',
      ],
      queryParameters: <String, String>{
        'static': 'true',
        'mediaSourceId': mediaSourceId,
        'playSessionId': ?playSessionId,
        if (container != null && container.isNotEmpty) 'container': container,
        // The stream endpoint predates header auth and is fetched by libmpv,
        // which cannot be given one — so the token rides in the query.
        'api_key': token,
      },
    ),
    isDirectPlay: true,
    playSessionId: playSessionId,
    container: container,
    bitrate: source['Bitrate'] as int?,
  );
}

/// Artwork for an item, or null when it has none.
Uri? imageUrlFor(
  ServerItem item, {
  required Uri base,
  int? maxWidth,
}) {
  final tag = item.imageTag;
  if (tag == null || tag.isEmpty) return null;

  // The tag and its owner travel together: an episode borrowing its series'
  // artwork has to be asked for under the series' id.
  final owner = item.imageOwnerId ?? item.id;

  return base.replace(
    pathSegments: <String>[
      ...base.pathSegments.where((s) => s.isNotEmpty),
      'Items',
      owner,
      'Images',
      'Primary',
    ],
    queryParameters: <String, String>{
      'tag': tag,
      if (maxWidth != null) 'maxWidth': '$maxWidth',
    },
  );
}
