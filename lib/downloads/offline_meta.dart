// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/foundation.dart';

import '../servers/media_library_source.dart';

/// What the player needs about a copy beyond its bytes, taken from the
/// server while it could still be asked.
///
/// The server's track list, chapters, labelled segments and default tracks
/// are what make an offline copy play like a streamed one — the audio
/// picker named "English - Dolby Digital - 5.1" rather than "Track 2", the
/// skip-intro pill, the chapter list. All of it comes from the *original*
/// file's direct-play answer, so the indexes line up one for one with the
/// file on disk, which is that same original.
///
/// Written as `meta.json` beside the file. A copy without one still plays;
/// it just plays like a file the server never described.
@immutable
class OfflineMeta {
  const OfflineMeta({
    this.runtime,
    this.position,
    this.chapters = const <OfflineChapter>[],
    this.segments = const <MediaSegment>[],
    this.streams = const <ServerStream>[],
    this.subtitles = const <OfflineSubtitle>[],
    this.defaultAudioIndex,
    this.defaultSubtitleIndex,
  });

  final Duration? runtime;

  /// Where the server had the user at the moment the copy was taken — the
  /// last word on it there is, while the device stays offline.
  final Duration? position;

  final List<OfflineChapter> chapters;
  final List<MediaSegment> segments;
  final List<ServerStream> streams;
  final List<OfflineSubtitle> subtitles;
  final int? defaultAudioIndex;
  final int? defaultSubtitleIndex;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'runtimeMs': ?runtime?.inMilliseconds,
        'positionMs': ?position?.inMilliseconds,
        'chapters': <Map<String, dynamic>>[
          for (final c in chapters)
            <String, dynamic>{'title': c.title, 'startMs': c.start.inMilliseconds},
        ],
        'segments': <Map<String, dynamic>>[
          for (final s in segments)
            <String, dynamic>{
              'kind': s.kind.wireName,
              'startMs': s.start.inMilliseconds,
              'endMs': s.end.inMilliseconds,
            },
        ],
        'streams': <Map<String, dynamic>>[
          for (final s in streams)
            <String, dynamic>{
              'index': s.index,
              'type': s.type.name,
              'codec': ?s.codec,
              'language': ?s.language,
              'title': ?s.title,
              'isDefault': s.isDefault,
              'isForced': s.isForced,
              'bitrate': ?s.bitrate,
              'width': ?s.width,
              'height': ?s.height,
              'channels': ?s.channels,
              'deliveryUrl': ?s.deliveryUrl,
            },
        ],
        'subtitles': <Map<String, dynamic>>[
          for (final s in subtitles)
            <String, dynamic>{
              'fileName': s.fileName,
              'label': s.label,
              'language': ?s.language,
              'index': ?s.index,
            },
        ],
        'defaultAudioIndex': ?defaultAudioIndex,
        'defaultSubtitleIndex': ?defaultSubtitleIndex,
      };

  /// Lenient: a field that does not parse is left out rather than costing
  /// the copy everything else the file holds.
  static OfflineMeta fromJson(Map<String, dynamic> json) {
    Duration? ms(Object? v) => v is int ? Duration(milliseconds: v) : null;
    List<Map<String, dynamic>> list(Object? v) => <Map<String, dynamic>>[
          if (v is List)
            for (final Object? e in v)
              if (e is Map<String, dynamic>) e,
        ];

    return OfflineMeta(
      runtime: ms(json['runtimeMs']),
      position: ms(json['positionMs']),
      chapters: <OfflineChapter>[
        for (final c in list(json['chapters']))
          if (ms(c['startMs']) case final Duration start)
            OfflineChapter(title: c['title'] as String? ?? '', start: start),
      ],
      segments: <MediaSegment>[
        for (final s in list(json['segments']))
          if ((ms(s['startMs']), ms(s['endMs'])) case (final Duration a, final Duration b))
            MediaSegment(
              kind: MediaSegmentKind.fromWire(s['kind'] as String?),
              start: a,
              end: b,
            ),
      ],
      streams: <ServerStream>[
        for (final s in list(json['streams']))
          if (s['index'] case final int index)
            ServerStream(
              index: index,
              type: ServerStreamType.values.firstWhere(
                (t) => t.name == s['type'],
                orElse: () => ServerStreamType.unknown,
              ),
              codec: s['codec'] as String?,
              language: s['language'] as String?,
              title: s['title'] as String?,
              isDefault: s['isDefault'] as bool? ?? false,
              isForced: s['isForced'] as bool? ?? false,
              bitrate: s['bitrate'] as int?,
              width: s['width'] as int?,
              height: s['height'] as int?,
              channels: s['channels'] as int?,
              deliveryUrl: s['deliveryUrl'] as String?,
            ),
      ],
      subtitles: <OfflineSubtitle>[
        for (final s in list(json['subtitles']))
          if (s['fileName'] case final String name)
            OfflineSubtitle(
              fileName: name,
              label: s['label'] as String? ?? name,
              language: s['language'] as String?,
              index: s['index'] as int?,
            ),
      ],
      defaultAudioIndex: json['defaultAudioIndex'] as int?,
      defaultSubtitleIndex: json['defaultSubtitleIndex'] as int?,
    );
  }
}

/// A server chapter without its still: the stills are a request each, and
/// a chapter list reads fine without them.
@immutable
class OfflineChapter {
  const OfflineChapter({required this.title, required this.start});

  final String title;
  final Duration start;
}

/// An external subtitle saved beside the file, under [fileName].
@immutable
class OfflineSubtitle {
  const OfflineSubtitle({
    required this.fileName,
    required this.label,
    this.language,
    this.index,
  });

  final String fileName;
  final String label;
  final String? language;

  /// The server stream index, as on [ExternalSubtitle.index].
  final int? index;
}
