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

/// The same conversion, for a **position** rather than a length.
///
/// [ticksToDuration] reads zero as "the server did not say", which is right
/// for a runtime and wrong here: a segment or a chapter starting at 0:00 is
/// the commonest one there is, and treating it as missing drops the opening
/// titles — exactly the thing the user wanted skipped.
Duration? ticksToPosition(Object? ticks) {
  final value = switch (ticks) {
    final int i => i,
    final num n => n.toInt(),
    _ => null,
  };
  if (value == null || value < 0) return null;
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
///
/// [base] and [token] are only needed to build the URLs behind the chapter
/// stills and the trickplay sheets, which only the detail fetch asks for.
/// A listing calls this without them and gets the same item minus two fields
/// it would have thrown away.
ServerItem serverItemFromJson(
  Map<String, dynamic> json, {
  Uri? base,
  String? token,
}) {
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
    backdropTag: _backdropImageTag(json),
    backdropOwnerId: _backdropOwnerId(json),
    originalTitle: (json['OriginalTitle'] as String?)?.trim().isNotEmpty ??
            false
        ? (json['OriginalTitle'] as String).trim()
        : null,
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
    chapters: serverChaptersFromJson(json),
    trickplay: base == null
        ? null
        : trickplayFromJson(json, base: base, token: token ?? ''),
  );
}

/// The `Chapters` field, numbered as the image route expects.
///
/// The index is the whole reason this keeps a counter: a chapter still is
/// fetched as `/Items/{id}/Images/Chapter/{n}`, so a chapter that lost its
/// position in the list loses its picture with it.
List<ServerChapter> serverChaptersFromJson(Map<String, dynamic> json) {
  final raw = json['Chapters'];
  if (raw is! List) return const <ServerChapter>[];

  final chapters = <ServerChapter>[];
  for (var i = 0; i < raw.length; i++) {
    final entry = raw[i];
    if (entry is! Map) continue;

    final start = ticksToPosition(entry['StartPositionTicks']);
    if (start == null) continue;

    final name = (entry['Name'] as String?)?.trim();
    chapters.add(
      ServerChapter(
        index: i,
        // Jellyfin generates "Chapter 1" itself for a file whose container
        // named nothing, but an empty string does turn up.
        title: name == null || name.isEmpty ? 'Chapter ${i + 1}' : name,
        start: start,
        imageTag: entry['ImageTag'] as String?,
      ),
    );
  }

  // A container can list them out of order; the scrubber and the sheet both
  // assume otherwise, and `end` is derived from the neighbour.
  chapters.sort((a, b) => a.start.compareTo(b.start));
  return chapters;
}

/// The `Trickplay` field, or null where the server has generated nothing.
///
/// Its shape is two maps deep — media source id, then thumbnail width — and
/// both keys are strings the client has to pick from rather than values it
/// can ask for. The **widest** resolution wins: a preview blown up from 160px
/// is a smear, and the sheets are fetched one per scrub either way.
ServerTrickplay? trickplayFromJson(
  Map<String, dynamic> json, {
  required Uri base,
  required String token,
}) {
  final itemId = json['Id'] as String?;
  final bySource = json['Trickplay'];
  if (itemId == null || itemId.isEmpty || bySource is! Map) return null;

  for (final Object? sourceKey in bySource.keys) {
    final byWidth = bySource[sourceKey];
    if (byWidth is! Map || byWidth.isEmpty) continue;

    Map? widest;
    var widestWidth = -1;
    for (final Object? info in byWidth.values) {
      if (info is! Map) continue;
      final width = info['Width'] as int? ?? 0;
      if (width > widestWidth) {
        widest = info;
        widestWidth = width;
      }
    }
    if (widest == null || widestWidth <= 0) continue;

    final height = widest['Height'] as int? ?? 0;
    final tileWidth = widest['TileWidth'] as int? ?? 0;
    final tileHeight = widest['TileHeight'] as int? ?? 0;
    final interval = widest['Interval'] as int? ?? 0;
    if (height <= 0 || tileWidth <= 0 || tileHeight <= 0 || interval <= 0) {
      continue;
    }

    final mediaSourceId = sourceKey is String ? sourceKey : itemId;

    return ServerTrickplay(
      width: widestWidth,
      height: height,
      tileWidth: tileWidth,
      tileHeight: tileHeight,
      interval: interval,
      thumbnailCount: widest['ThumbnailCount'] as int? ?? 0,
      tileUrl: (int index) => base.replace(
        pathSegments: <String>[
          ...base.pathSegments.where((s) => s.isNotEmpty),
          'Videos',
          itemId,
          'Trickplay',
          '$widestWidth',
          '$index.jpg',
        ],
        queryParameters: <String, String>{
          'mediaSourceId': mediaSourceId,
          // Fetched by the image loader, which sends no Authorization
          // header — the same reason the direct-play URL carries one.
          if (token.isNotEmpty) 'api_key': token,
        },
      ),
    );
  }

  return null;
}

/// One `MediaSegmentDto` from `/MediaSegments/{itemId}`.
///
/// A segment whose type this app does not act on is dropped here rather than
/// carried as `unknown`: everything downstream would have to check for it,
/// and there is nothing sensible to label a pill with.
List<MediaSegment> mediaSegmentsFromJson(Map<String, dynamic> json) {
  final items = json['Items'];
  if (items is! List) return const <MediaSegment>[];

  final segments = <MediaSegment>[];
  for (final Object? entry in items) {
    if (entry is! Map) continue;

    final kind = MediaSegmentKind.fromWire(entry['Type'] as String?);
    if (!supportedSegmentKinds.contains(kind)) continue;

    final start = ticksToPosition(entry['StartTicks']);
    final end = ticksToPosition(entry['EndTicks']);
    // A segment that ends before it begins is not a segment; seeking to its
    // end would jump the user backwards.
    if (start == null || end == null || end <= start) continue;

    segments.add(MediaSegment(kind: kind, start: start, end: end));
  }

  segments.sort((a, b) => a.start.compareTo(b.start));
  return segments;
}


/// The `/Movies/Recommendations` answer — a bare array of titled rows.
///
/// Each carries the reason and the thing it reasoned from, never a sentence:
/// "SimilarToRecentlyPlayed" plus "Dune" becomes "Because you watched Dune"
/// on the screen, where there is a locale to say it in.
List<ServerShelf> serverShelvesFromJson(List<Object?> json) {
  final shelves = <ServerShelf>[];

  for (final Object? entry in json) {
    if (entry is! Map) continue;

    final items = <ServerItem>[
      for (final Object? i in (entry['Items'] as List?) ?? const <Object?>[])
        if (i is Map<String, dynamic>) serverItemFromJson(i),
    ];
    // A reason with nothing behind it is a heading over blank space.
    if (items.isEmpty) continue;

    shelves.add(
      ServerShelf(
        kind: SuggestionKind.fromWire(entry['RecommendationType'] as String?),
        subject: (entry['BaselineItemName'] as String?)?.trim() ?? '',
        items: items,
      ),
    );
  }

  return shelves;
}

/// A chapter still, or null where the server generated none.
Uri? chapterImageUrlFor(
  ServerChapter chapter, {
  required Uri base,
  required String itemId,
  int? maxWidth,
}) {
  final tag = chapter.imageTag;
  if (tag == null || tag.isEmpty) return null;

  return base.replace(
    pathSegments: <String>[
      ...base.pathSegments.where((s) => s.isNotEmpty),
      'Items',
      itemId,
      'Images',
      'Chapter',
      '${chapter.index}',
    ],
    queryParameters: <String, String>{
      'tag': tag,
      if (maxWidth != null) 'maxWidth': '$maxWidth',
    },
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

/// The first entry of `BackdropImageTags`, or the parent's where the item
/// has none of its own.
///
/// A list, because a server can hold several — the header draws one, and the
/// first is the one every other client treats as the default.
String? _backdropImageTag(Map<String, dynamic> json) {
  final own = json['BackdropImageTags'];
  if (own is List && own.isNotEmpty && own.first is String) {
    return own.first as String;
  }

  final parent = json['ParentBackdropImageTags'];
  if (parent is List && parent.isNotEmpty && parent.first is String) {
    return parent.first as String;
  }
  return null;
}

/// Which item the tag [_backdropImageTag] found belongs to.
String? _backdropOwnerId(Map<String, dynamic> json) {
  final own = json['BackdropImageTags'];
  if (own is List && own.isNotEmpty && own.first is String) {
    return json['Id'] as String?;
  }

  final parent = json['ParentBackdropImageTags'];
  if (parent is List && parent.isNotEmpty && parent.first is String) {
    // The server names the owner outright here rather than leaving it to be
    // guessed from the parent chain, which for an episode is the season and
    // not the series that holds the picture.
    return json['ParentBackdropItemId'] as String? ?? json['Id'] as String?;
  }
  return null;
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
  final externalSubtitles =
      externalSubtitlesFrom(streams, base: base, token: token);
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
      externalSubtitles: externalSubtitles,
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
    externalSubtitles: externalSubtitles,
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
    // Present on subtitles the server keeps beside the video rather than
    // inside it. `DeliveryMethod` is checked too: the field survives on a
    // stream the server has since decided to burn in or to mux into an HLS
    // playlist, and fetching it then would add a second copy of subtitles
    // already on screen.
    deliveryUrl: json['DeliveryMethod'] == 'External'
        ? json['DeliveryUrl'] as String?
        : null,
  );
}

/// The subtitle files a [ServerPlayback] has to load by hand.
///
/// Relative URLs as they arrive, resolved here against the server root and
/// given the token: the player hands them to libmpv, which fetches them
/// itself and cannot be given a header.
List<ExternalSubtitle> externalSubtitlesFrom(
  List<ServerStream> streams, {
  required Uri base,
  required String token,
}) {
  final subtitles = <ExternalSubtitle>[];

  for (final ServerStream stream in streams) {
    if (stream.type != ServerStreamType.subtitle || !stream.isExternal) {
      continue;
    }

    final resolved = base.resolve(stream.deliveryUrl!);
    subtitles.add(
      ExternalSubtitle(
        uri: token.isEmpty
            ? resolved
            : resolved.replace(
                queryParameters: <String, String>{
                  ...resolved.queryParameters,
                  'api_key': token,
                },
              ),
        label: stream.label,
        language: stream.language,
        index: stream.index,
      ),
    );
  }

  return subtitles;
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

/// The wide artwork behind a detail header, or null when the item has none.
Uri? backdropImageUrlFor(
  ServerItem item, {
  required Uri base,
  int? maxWidth,
}) {
  final tag = item.backdropTag;
  final owner = item.backdropOwnerId;
  if (tag == null || tag.isEmpty || owner == null || owner.isEmpty) return null;

  // Indexed as well as tagged: the backdrop route is the *n*th picture of an
  // item, and the tag alone will not fetch it. Zero is the one the tag came
  // from — the first of `BackdropImageTags`.
  return base.replace(
    pathSegments: <String>[
      ...base.pathSegments.where((s) => s.isNotEmpty),
      'Items',
      owner,
      'Images',
      'Backdrop',
      '0',
    ],
    queryParameters: <String, String>{
      'tag': tag,
      if (maxWidth != null) 'maxWidth': '$maxWidth',
    },
  );
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
