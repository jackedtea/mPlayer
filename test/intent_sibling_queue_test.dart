// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter_test/flutter_test.dart';

import 'package:mplayer/core/models/library_models.dart';
import 'package:mplayer/core/models/media_models.dart';
import 'package:mplayer/sources/media_source.dart';
import 'package:mplayer/sources/media_store_source.dart';

/// Stands in for the media index the way it answers a *path* question.
///
/// The real driver is Android-only, so what is exercised here is the contract
/// `siblingVideosOf` holds it to: a bucket id lists, an item URI does not.
class _IndexLike implements BrowsableSource {
  _IndexLike(this.byBucket);

  final Map<String, List<String>> byBucket;

  @override
  String get id => MediaStoreSource.sourceId;

  @override
  SourceKind get kind => SourceKind.device;

  @override
  SourceCapabilities get capabilities => SourceCapabilities.local;

  @override
  String get rootLabel => 'This device';

  @override
  String parentOf(String path) => const MediaStoreSource().parentOf(path);

  @override
  Future<BrowseListing> listDirectory(String path) async {
    // Exactly what the SQL does: a bucket id matches rows, anything else
    // matches none.
    final uris = byBucket[path] ?? const <String>[];
    return BrowseListing(
      path: path,
      entries: <BrowseEntry>[
        for (final String uri in uris)
          BrowseEntry(
            name: uri.split('/').last,
            kind: BrowseEntryKind.video,
            path: uri,
          ),
      ],
    );
  }

  @override
  Future<PlayableMedia> resolve(MediaRef ref) async => throw UnimplementedError();
}

void main() {
  group('MediaStoreSource.parentOf', () {
    test('never answers "every video on the device"', () {
      // An empty string is what `listDirectory` reads as "the whole library".
      // Returning it here is what made a folder step walk every video the
      // device holds instead of the ten beside the one that was opened.
      const source = MediaStoreSource();

      expect(source.parentOf('content://media/external/video/media/42'),
          isNot(''));
      expect(source.parentOf('content://com.mixplorer.fileprovider/x/ep01.mkv'),
          isNot(''));
    });
  });

  group('a hand-off from another app', () {
    test('finds no run by path, so the index fallback gets its turn',
        () async {
      final index = _IndexLike(<String, List<String>>{
        '1234': <String>[
          'content://media/external/video/media/1',
          'content://media/external/video/media/2',
          'content://media/external/video/media/3',
        ],
      });

      // The URI a file manager hands over. No bucket id can be read out of
      // it, so the path route must come back with the single file rather
      // than with the wrong folder.
      const handoff = MediaRef(
        sourceId: MediaStoreSource.sourceId,
        itemId: 'content://com.mixplorer.fileprovider/external_files/ep02.mkv',
        title: 'ep02.mkv',
      );

      final found = await siblingVideosOf(index, handoff);

      expect(found.items, hasLength(1));
      expect(found.index, 0);
    });

    test('a bucket id still lists the folder it names', () async {
      final index = _IndexLike(<String, List<String>>{
        '1234': <String>[
          'content://media/external/video/media/1',
          'content://media/external/video/media/2',
        ],
      });

      final listing = await index.listDirectory('1234');
      expect(listing.entries, hasLength(2));
      expect(listing.entries.every((e) => e.isPlayable), isTrue);
    });
  });
}
