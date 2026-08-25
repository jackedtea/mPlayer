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
/// strict about the shape: a quoted value per field, comma separated.
///
/// **Every value is percent-encoded**, and the server decodes it while
/// parsing. This is not tidiness — it is what makes the header sendable at
/// all. A device name is whatever the OS reports, so "Điện thoại của Nam" or
/// "Bjørn PC" is entirely ordinary, and `dart:io` **throws** on a header value
/// above 0x7F rather than sending it. Encoding also disposes of the
/// characters the header's own grammar has no escape for: quotes, commas and
/// `=` inside a value.
///
/// The token is absent until the user has signed in: sending `Token=""` is
/// read as a malformed request rather than an anonymous one.
String authorizationHeader({
  required String client,
  required String device,
  required String deviceId,
  required String version,
  String? token,
}) {
  String field(String name, String value) =>
      '$name="${Uri.encodeComponent(value)}"';

  // Both Jellyfin and Emby refuse to create a session without a client, a
  // device and a version, so each falls back to something non-empty rather
  // than being sent blank.
  final resolvedClient = _meaningful(client).isEmpty
      ? 'mPlayer'
      : _meaningful(client);
  final resolvedDevice =
      _meaningful(device).isEmpty ? resolvedClient : _meaningful(device);
  final resolvedVersion =
      _meaningful(version).isEmpty ? '1.0' : _meaningful(version);
  final id = _meaningful(deviceId);
  final resolvedToken = _meaningful(token ?? '');

  return 'MediaBrowser ${<String>[
    field('Client', resolvedClient),
    field('Device', resolvedDevice),
    // Omitted rather than sent empty: on an authenticated request the server
    // recovers it from the token, and an empty field is a parse error.
    if (id.isNotEmpty) field('DeviceId', id),
    field('Version', resolvedVersion),
    if (resolvedToken.isNotEmpty) field('Token', resolvedToken),
  ].join(', ')}';
}

final _controlCharacters = RegExp(r'[\x00-\x1f\x7f-\x9f]');

/// Percent-encoding makes any byte transportable, so the only thing worth
/// stripping is what carries no identity at all — a name of control
/// characters would reach the server's device list as `%00` noise instead of
/// falling back to something readable.
String _meaningful(String value) =>
    value.replaceAll(_controlCharacters, '').trim();

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
    rating: (json['CommunityRating'] as num?)?.toDouble(),
    certificate: json['OfficialRating'] as String?,
    genres: <String>[
      for (final Object? g in (json['Genres'] as List?) ?? const <Object?>[])
        if (g is String) g,
    ],
    people: <ServerPerson>[
      for (final Object? p in (json['People'] as List?) ?? const <Object?>[])
        if (p is Map)
          ServerPerson(
            name: p['Name'] as String? ?? '',
            // `Role` is the character; `Type` is the job. A director has no
            // role, and showing "Director" beats showing nothing.
            role: (p['Role'] as String?)?.trim().isNotEmpty ?? false
                ? (p['Role'] as String).trim()
                : (p['Type'] as String? ?? ''),
            id: p['Id'] as String?,
            imageTag: p['PrimaryImageTag'] as String?,
          ),
    ],
    childCount: json['ChildCount'] as int?,
    tags: <String>[
      for (final Object? t in (json['Tags'] as List?) ?? const <Object?>[])
        if (t is String) t,
    ],
    studios: <String>[
      for (final Object? s in (json['Studios'] as List?) ?? const <Object?>[])
        if (s is Map && s['Name'] is String) s['Name'] as String,
    ],
    status: json['Status'] as String?,
    // The server dates the end rather than numbering the year, so it is the
    // one field here that has to be parsed out of a timestamp.
    endYear: DateTime.tryParse(json['EndDate'] as String? ?? '')?.year,
    playlistEntryId: json['PlaylistItemId'] as String?,
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
    'BoxSet' => ServerItemKind.collection,
    'Folder' || 'CollectionFolder' => ServerItemKind.folder,
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

  final streams = <ServerStream>[
    for (final Object? s in (source['MediaStreams'] as List?) ?? const <Object?>[])
      if (s is Map<String, dynamic>) serverStreamFromJson(s),
  ];
  final defaultAudio = source['DefaultAudioStreamIndex'] as int?;
  final defaultSubtitle = source['DefaultSubtitleStreamIndex'] as int?;
  final transcodes = source['SupportsTranscoding'] as bool? ?? false;
  final sourceId = source['Id'] as String? ?? itemId;

  if (transcodingUrl != null && transcodingUrl.isNotEmpty) {
    return ServerPlayback(
      // Relative to the server root, and it already carries its own query.
      uri: base.resolve(transcodingUrl),
      isDirectPlay: false,
      playSessionId: playSessionId,
      container: source['Container'] as String?,
      bitrate: source['Bitrate'] as int?,
      streams: streams,
      mediaSourceId: sourceId,
      defaultAudioIndex: defaultAudio,
      defaultSubtitleIndex: defaultSubtitle,
      supportsTranscoding: transcodes,
    );
  }

  final mediaSourceId = sourceId;
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
    streams: streams,
    mediaSourceId: mediaSourceId,
    defaultAudioIndex: defaultAudio,
    defaultSubtitleIndex: defaultSubtitle,
    supportsTranscoding: transcodes,
  );
}

/// The body of a `PlaybackInfo` request.
///
/// A device profile is how a Jellyfin client says what it can and cannot
/// play, and it is the **only** thing that makes a quality cap take effect:
/// the server re-encodes when the file breaks one of these conditions, and
/// with no profile at all it concludes the client can play anything and hands
/// the file over untouched whatever the query said.
///
/// An empty body when nothing is capped, deliberately. "Original" means never
/// re-encode, and the surest way to get that is to state no conditions the
/// file could fail — a profile written to be permissive is still a list of
/// codecs, and any file outside it would be transcoded against the user's
/// wishes.
Map<String, dynamic> deviceProfileFor(PlaybackCapabilities caps) {
  if (caps.maxBitrate == null && caps.maxHeight == null) {
    return const <String, dynamic>{};
  }

  return <String, dynamic>{
    'DeviceProfile': <String, dynamic>{
      if (caps.maxBitrate != null) ...<String, dynamic>{
        'MaxStreamingBitrate': caps.maxBitrate,
        'MaxStaticBitrate': caps.maxBitrate,
      },
      // What libmpv opens without help. Broad, because the point of a cap is
      // the bitrate rather than the container — a 720p MKV the phone can
      // decode should still be handed over whole.
      'DirectPlayProfiles': <Map<String, dynamic>>[
        <String, dynamic>{
          'Container': 'mp4,mkv,webm,avi,mov,ts,m4v,flv,wmv',
          'Type': 'Video',
          'VideoCodec': 'h264,hevc,vp8,vp9,av1,mpeg4,mpeg2video',
          'AudioCodec': 'aac,ac3,eac3,mp3,opus,flac,vorbis,dts,truehd,pcm',
        },
      ],
      // HLS, because a re-encode that can be seeked has to be segmented.
      'TranscodingProfiles': <Map<String, dynamic>>[
        <String, dynamic>{
          'Container': 'ts',
          'Type': 'Video',
          'VideoCodec': 'h264',
          'AudioCodec': 'aac',
          'Protocol': 'hls',
          'Context': 'Streaming',
          'MaxAudioChannels': '2',
          'MinSegments': 1,
          // Without this the server only cuts at key frames, and a seek lands
          // wherever the previous one was rather than where it was asked for.
          'BreakOnNonKeyFrames': true,
        },
      ],
      'CodecProfiles': <Map<String, dynamic>>[
        <String, dynamic>{
          'Type': 'Video',
          'Conditions': <Map<String, dynamic>>[
            if (caps.maxHeight != null)
              <String, dynamic>{
                'Condition': 'LessThanEqual',
                'Property': 'Height',
                'Value': '${caps.maxHeight}',
                'IsRequired': true,
              },
            if (caps.maxBitrate != null)
              <String, dynamic>{
                'Condition': 'LessThanEqual',
                'Property': 'VideoBitrate',
                'Value': '${caps.maxBitrate}',
                'IsRequired': true,
              },
          ],
        },
      ],
    },
  };
}

/// One entry of `MediaStreams`.
ServerStream serverStreamFromJson(Map<String, dynamic> json) {
  return ServerStream(
    index: json['Index'] as int? ?? -1,
    type: switch (json['Type']) {
      'Video' => ServerStreamType.video,
      'Audio' => ServerStreamType.audio,
      'Subtitle' => ServerStreamType.subtitle,
      _ => ServerStreamType.unknown,
    },
    codec: json['Codec'] as String?,
    language: json['Language'] as String?,
    // `DisplayTitle` is the server's own assembled description and is better
    // than anything reassembled here — it knows about commentary tracks,
    // hearing-impaired flags and channel layouts this app does not model.
    title: json['DisplayTitle'] as String? ?? json['Title'] as String?,
    isDefault: json['IsDefault'] as bool? ?? false,
    isForced: json['IsForced'] as bool? ?? false,
    bitrate: json['BitRate'] as int?,
    width: json['Width'] as int?,
    height: json['Height'] as int?,
    channels: json['Channels'] as int?,
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

  return _primaryImageUrl(base, owner, tag, maxWidth);
}

/// A person's headshot. Same route as an item's — a person *is* an item to
/// the server — but the tag lives on the credit rather than in `ImageTags`.
Uri? personImageUrlFor(
  ServerPerson person, {
  required Uri base,
  int? maxWidth,
}) {
  final tag = person.imageTag;
  final id = person.id;
  if (tag == null || tag.isEmpty || id == null || id.isEmpty) return null;

  return _primaryImageUrl(base, id, tag, maxWidth);
}

Uri _primaryImageUrl(Uri base, String owner, String tag, int? maxWidth) {
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
