// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter_test/flutter_test.dart';

import 'package:mplayer/features/settings/player_settings.dart';
import 'package:mplayer/servers/jellyfin_dto.dart';
import 'package:mplayer/servers/media_library_source.dart';

final _base = Uri.parse('https://media.home.lan');

/// One `/MediaSegments/{id}` answer, as Jellyfin 10.10 sends it.
Map<String, dynamic> _segmentsResponse(List<Map<String, dynamic>> items) =>
    <String, dynamic>{'Items': items, 'TotalRecordCount': items.length};

void main() {
  group('media segments', () {
    test('an intro starting at zero survives the parse', () {
      // The trap this whole endpoint walks into: `ticksToDuration` reads zero
      // as "the server did not say", which is right for a runtime and would
      // silently drop the commonest intro there is.
      final segments = mediaSegmentsFromJson(
        _segmentsResponse(<Map<String, dynamic>>[
          <String, dynamic>{
            'Type': 'Intro',
            'StartTicks': 0,
            'EndTicks': 900000000,
          },
        ]),
      );

      expect(segments, hasLength(1));
      expect(segments.single.kind, MediaSegmentKind.intro);
      expect(segments.single.start, Duration.zero);
      expect(segments.single.end, const Duration(seconds: 90));
    });

    test('every kind the app acts on is recognised', () {
      final segments = mediaSegmentsFromJson(
        _segmentsResponse(<Map<String, dynamic>>[
          for (final MediaSegmentKind kind in supportedSegmentKinds)
            <String, dynamic>{
              'Type': kind.wireName,
              'StartTicks': 10000000,
              'EndTicks': 200000000,
            },
        ]),
      );

      expect(
        segments.map((s) => s.kind).toSet(),
        supportedSegmentKinds.toSet(),
      );
    });

    test('a type this app has never heard of is dropped, not carried', () {
      // Nothing downstream has a label for it, and a pill reading "Unknown"
      // is worse than no pill.
      final segments = mediaSegmentsFromJson(
        _segmentsResponse(<Map<String, dynamic>>[
          <String, dynamic>{
            'Type': 'SponsorRead',
            'StartTicks': 0,
            'EndTicks': 100000000,
          },
        ]),
      );

      expect(segments, isEmpty);
    });

    test('a segment that ends before it begins is refused', () {
      // Seeking to its end would throw the viewer backwards.
      final segments = mediaSegmentsFromJson(
        _segmentsResponse(<Map<String, dynamic>>[
          <String, dynamic>{
            'Type': 'Outro',
            'StartTicks': 900000000,
            'EndTicks': 100000000,
          },
          <String, dynamic>{'Type': 'Intro', 'StartTicks': 0},
        ]),
      );

      expect(segments, isEmpty);
    });

    test('they come back in playback order whatever order they arrived in', () {
      final segments = mediaSegmentsFromJson(
        _segmentsResponse(<Map<String, dynamic>>[
          <String, dynamic>{
            'Type': 'Outro',
            'StartTicks': 13000000000,
            'EndTicks': 14000000000,
          },
          <String, dynamic>{
            'Type': 'Intro',
            'StartTicks': 0,
            'EndTicks': 900000000,
          },
        ]),
      );

      expect(
        segments.map((s) => s.kind).toList(),
        <MediaSegmentKind>[MediaSegmentKind.intro, MediaSegmentKind.outro],
      );
    });

    test('an empty or missing body is no segments, not a failure', () {
      // The answer for most items on most servers, and for every server older
      // than 10.10.
      expect(mediaSegmentsFromJson(<String, dynamic>{}), isEmpty);
      expect(mediaSegmentsFromJson(_segmentsResponse(<Map<String, dynamic>>[])),
          isEmpty);
    });

    test('contains is half-open, so a skip to the end leaves it', () {
      const segment = MediaSegment(
        kind: MediaSegmentKind.intro,
        start: Duration(seconds: 10),
        end: Duration(seconds: 90),
      );

      expect(segment.contains(const Duration(seconds: 10)), isTrue);
      expect(segment.contains(const Duration(seconds: 89)), isTrue);
      // The position an auto-skip lands on. Inclusive here would leave the
      // pill on screen after the thing it offers has already been skipped.
      expect(segment.contains(const Duration(seconds: 90)), isFalse);
    });
  });

  group('segment actions', () {
    test('intro and outro are offered out of the box; the rest are not', () {
      const settings = PlayerSettings();

      expect(settings.actionFor(MediaSegmentKind.intro), SegmentAction.askToSkip);
      expect(settings.actionFor(MediaSegmentKind.outro), SegmentAction.askToSkip);
      // A recap or a preview seeking itself away on a first watch is a scene
      // the viewer never got to decide about.
      expect(settings.actionFor(MediaSegmentKind.recap), SegmentAction.nothing);
      expect(
        settings.actionFor(MediaSegmentKind.preview),
        SegmentAction.nothing,
      );
    });

    test('a choice survives being written out and read back', () {
      const settings = PlayerSettings();
      final changed = settings.copyWith(
        segmentActions: <MediaSegmentKind, SegmentAction>{
          ...settings.segmentActions,
          MediaSegmentKind.intro: SegmentAction.skip,
        },
      );

      final restored = PlayerSettings.fromJson(changed.toJson());

      expect(restored.actionFor(MediaSegmentKind.intro), SegmentAction.skip);
      expect(
        restored.actionFor(MediaSegmentKind.outro),
        SegmentAction.askToSkip,
      );
    });

    test('a map written before a kind existed keeps the choices it has', () {
      // Dropping the whole map for one missing key would silently reset four
      // decisions the user made.
      final restored = PlayerSettings.fromJson(<String, dynamic>{
        'segmentActions': <String, dynamic>{'intro': 'skip'},
      });

      expect(restored.actionFor(MediaSegmentKind.intro), SegmentAction.skip);
      expect(
        restored.actionFor(MediaSegmentKind.outro),
        SegmentAction.askToSkip,
      );
      expect(restored.actionFor(MediaSegmentKind.recap), SegmentAction.nothing);
    });

    test('an unreadable value falls back to the default for that kind', () {
      final restored = PlayerSettings.fromJson(<String, dynamic>{
        'segmentActions': <String, dynamic>{'intro': 'teleport'},
      });

      expect(
        restored.actionFor(MediaSegmentKind.intro),
        SegmentAction.askToSkip,
      );
    });
  });

  group('server chapters', () {
    test('are numbered by position, because the image route is', () {
      final chapters = serverChaptersFromJson(<String, dynamic>{
        'Chapters': <Map<String, dynamic>>[
          <String, dynamic>{
            'StartPositionTicks': 0,
            'Name': 'Cold open',
            'ImageTag': 'aaa',
          },
          <String, dynamic>{
            'StartPositionTicks': 6000000000,
            'Name': 'Titles',
          },
        ],
      });

      expect(chapters.map((c) => c.index).toList(), <int>[0, 1]);
      expect(chapters.first.start, Duration.zero);
      expect(chapters.last.start, const Duration(minutes: 10));
      // Null is ordinary — most servers extract no chapter stills at all.
      expect(chapters.last.imageTag, isNull);
    });

    test('an unnamed chapter is numbered rather than left blank', () {
      final chapters = serverChaptersFromJson(<String, dynamic>{
        'Chapters': <Map<String, dynamic>>[
          <String, dynamic>{'StartPositionTicks': 0, 'Name': '  '},
        ],
      });

      expect(chapters.single.title, 'Chapter 1');
    });

    test('a still is a URL only where the server holds one', () {
      const withTag = ServerChapter(
        index: 3,
        title: 'Titles',
        start: Duration(minutes: 10),
        imageTag: 'abc123',
      );
      const withoutTag = ServerChapter(
        index: 4,
        title: 'Chase',
        start: Duration(minutes: 14),
      );

      final url = chapterImageUrlFor(
        withTag,
        base: _base,
        itemId: 'item-1',
        maxWidth: 480,
      );

      expect(url, isNotNull);
      expect(url!.path, '/Items/item-1/Images/Chapter/3');
      expect(url.queryParameters['tag'], 'abc123');
      expect(url.queryParameters['maxWidth'], '480');

      expect(
        chapterImageUrlFor(withoutTag, base: _base, itemId: 'item-1'),
        isNull,
      );
    });
  });

  group('trickplay', () {
    Map<String, dynamic> item({int width = 320}) => <String, dynamic>{
          'Id': 'item-1',
          'Trickplay': <String, dynamic>{
            'source-1': <String, dynamic>{
              '$width': <String, dynamic>{
                'Width': width,
                'Height': width * 9 ~/ 16,
                'TileWidth': 10,
                'TileHeight': 10,
                'ThumbnailCount': 720,
                'Interval': 10000,
              },
            },
          },
        };

    test('the widest resolution wins', () {
      final json = <String, dynamic>{
        'Id': 'item-1',
        'Trickplay': <String, dynamic>{
          'source-1': <String, dynamic>{
            '160': <String, dynamic>{
              'Width': 160,
              'Height': 90,
              'TileWidth': 10,
              'TileHeight': 10,
              'ThumbnailCount': 720,
              'Interval': 10000,
            },
            '480': <String, dynamic>{
              'Width': 480,
              'Height': 270,
              'TileWidth': 10,
              'TileHeight': 10,
              'ThumbnailCount': 720,
              'Interval': 10000,
            },
          },
        },
      };

      // A preview blown up from 160px is a smear, and the sheets are fetched
      // one per scrub either way.
      expect(trickplayFromJson(json, base: _base, token: 't')!.width, 480);
    });

    test('a position becomes a rectangle inside a numbered sheet', () {
      final trickplay =
          trickplayFromJson(item(), base: _base, token: 'tok')!;

      // 100 thumbnails a sheet, one every 10s: 17m 30s is thumbnail 105,
      // which is the sixth of sheet 1.
      final tile = trickplay.tileFor(const Duration(minutes: 17, seconds: 30))!;

      expect(tile.url.path, '/Videos/item-1/Trickplay/320/1.jpg');
      expect(tile.url.queryParameters['mediaSourceId'], 'source-1');
      // The image loader sends no Authorization header, so the token rides in
      // the query the same way the direct-play URL's does.
      expect(tile.url.queryParameters['api_key'], 'tok');
      expect(tile.left, 5 * 320);
      expect(tile.top, 0);
    });

    test('a position past the last generated thumbnail has no tile', () {
      final trickplay =
          trickplayFromJson(item(), base: _base, token: 'tok')!;

      // 720 thumbnails at ten seconds each stops at two hours.
      expect(trickplay.tileFor(const Duration(hours: 3)), isNull);
    });

    test('an item the server generated nothing for reports nothing', () {
      expect(
        trickplayFromJson(
          <String, dynamic>{'Id': 'item-1'},
          base: _base,
          token: 't',
        ),
        isNull,
      );
      // A manifest missing the numbers the maths needs is the same answer.
      expect(
        trickplayFromJson(
          <String, dynamic>{
            'Id': 'item-1',
            'Trickplay': <String, dynamic>{
              'source-1': <String, dynamic>{
                '320': <String, dynamic>{'Width': 320, 'Height': 180},
              },
            },
          },
          base: _base,
          token: 't',
        ),
        isNull,
      );
    });
  });

  group('external subtitles', () {
    test('only a stream the server delivers separately becomes one', () {
      final subtitles = externalSubtitlesFrom(
        <ServerStream>[
          const ServerStream(
            index: 2,
            type: ServerStreamType.subtitle,
            title: 'English - SRT',
            language: 'eng',
            deliveryUrl: '/Videos/item-1/item-1/Subtitles/2/0/Stream.srt',
          ),
          // Inside the container — the decoder finds this one itself, and
          // fetching it too would put two copies on the screen.
          const ServerStream(index: 3, type: ServerStreamType.subtitle),
          // Not a subtitle at all.
          const ServerStream(
            index: 1,
            type: ServerStreamType.audio,
            deliveryUrl: '/nonsense',
          ),
        ],
        base: _base,
        token: 'tok',
      );

      expect(subtitles, hasLength(1));
      expect(subtitles.single.index, 2);
      expect(subtitles.single.label, 'English - SRT');
      expect(
        subtitles.single.uri.path,
        '/Videos/item-1/item-1/Subtitles/2/0/Stream.srt',
      );
      // libmpv fetches it itself and cannot be handed a header.
      expect(subtitles.single.uri.queryParameters['api_key'], 'tok');
    });

    test('a burned-in or muxed track is not fetched separately', () {
      // The field survives on a stream the server has since decided to burn
      // in; acting on it then would draw subtitles twice.
      final stream = serverStreamFromJson(<String, dynamic>{
        'Index': 2,
        'Type': 'Subtitle',
        'DeliveryMethod': 'Encode',
        'DeliveryUrl': '/Videos/item-1/Subtitles/2/0/Stream.srt',
      });

      expect(stream.isExternal, isFalse);
      expect(
        externalSubtitlesFrom(<ServerStream>[stream], base: _base, token: 't'),
        isEmpty,
      );
    });
  });
}
