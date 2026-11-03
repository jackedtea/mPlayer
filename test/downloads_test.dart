// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:mplayer/downloads/download_engine.dart';
import 'package:mplayer/downloads/download_models.dart';
import 'package:mplayer/downloads/download_store.dart';
import 'package:mplayer/downloads/downloads_controller.dart';
import 'package:mplayer/servers/jellyfin_dto.dart';
import 'package:mplayer/servers/media_library_source.dart';

import 'fake_library_source.dart';
import 'file_server.dart';

class _Source extends FakeLibrarySource {
  const _Source(this.base);

  final Uri base;

  @override
  Uri downloadUrl(String itemId) => base.resolve('/Items/$itemId/Download');
}

/// A server that also describes the item: chapters, a segment, an audio
/// track and one external subtitle.
class _DescribedSource extends _Source {
  const _DescribedSource(super.base);

  @override
  Future<ServerItem> item(String itemId) async => ServerItem(
        id: itemId,
        title: 'The Film',
        kind: ServerItemKind.movie,
        runtime: const Duration(minutes: 90),
        position: const Duration(minutes: 5),
        chapters: const <ServerChapter>[
          ServerChapter(index: 0, title: 'Start', start: Duration.zero),
        ],
      );

  @override
  Future<List<MediaSegment>> segments(String itemId) async =>
      const <MediaSegment>[
        MediaSegment(
          kind: MediaSegmentKind.intro,
          start: Duration.zero,
          end: Duration(seconds: 60),
        ),
      ];

  @override
  Future<ServerPlayback> playback(
    String itemId,
    PlaybackCapabilities caps, {
    int? audioStreamIndex,
    int? subtitleStreamIndex,
    String? mediaSourceId,
  }) async =>
      ServerPlayback(
        uri: base.resolve('/stream'),
        isDirectPlay: true,
        defaultAudioIndex: 1,
        streams: const <ServerStream>[
          ServerStream(index: 1, type: ServerStreamType.audio, language: 'eng'),
        ],
        externalSubtitles: <ExternalSubtitle>[
          ExternalSubtitle(
            uri: base.resolve('/Videos/$itemId/Subtitles/3/Stream.srt'),
            label: 'English - SRT',
            index: 3,
          ),
        ],
      );
}

DownloadEntry _entry({String itemId = 'i1'}) => DownloadEntry(
      profileId: 'p1',
      itemId: itemId,
      title: 'The Film',
      createdAt: DateTime.utc(2026, 11, 2),
      kind: ServerItemKind.movie,
    );

void main() {
  late Directory root;
  late DownloadStore store;
  late FileServer server;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('mplayer_downloads_');
    store = DownloadStore(root);
    server = FileServer();
    await server.start();
  });

  tearDown(() async {
    await server.stop();
    if (root.existsSync()) await root.delete(recursive: true);
  });

  group('parsing', () {
    test('the total comes from either form of Content-Range', () {
      expect(rangeTotalOf('bytes 100-199/1234'), 1234);
      expect(rangeTotalOf('bytes */1234'), 1234);
      expect(rangeTotalOf('bytes 0-1/*'), isNull);
      expect(rangeTotalOf(null), isNull);
    });

    test('the extension is taken from the name the server gave', () {
      expect(extensionOfDisposition('attachment; filename="A (2024).MKV"'), '.mkv');
      expect(
        extensionOfDisposition(
          "attachment; filename=x.bin; filename*=UTF-8''%C4%90i%E1%BB%87n.mp4",
        ),
        '.mp4',
      );
      expect(extensionOfDisposition('attachment; filename="no extension"'), '');
      expect(extensionOfDisposition(null), '');
    });

    test('the download URL carries the token in the query', () {
      final url = downloadUrlFor(
        'abc',
        base: Uri.parse('https://media.home.lan/jellyfin'),
        token: 't0k',
      );
      expect(url.toString(), 'https://media.home.lan/jellyfin/Items/abc/Download?api_key=t0k');
    });

    test('an entry survives a round trip through JSON', () {
      final entry = _entry().copyWith(
        status: DownloadStatus.failed,
        receivedBytes: 10,
        totalBytes: 20,
        error: 'nope',
      );
      final back = DownloadEntry.fromJson(entry.toJson())!;
      expect(back.key, entry.key);
      expect(back.kind, ServerItemKind.movie);
      expect(back.status, DownloadStatus.failed);
      expect(back.receivedBytes, 10);
      expect(back.totalBytes, 20);
      expect(back.error, 'nope');
      expect(back.progress, 0.5);
    });
  });

  group('store', () {
    test('a killed download goes back in the queue at the bytes on disk', () async {
      final running = _entry().copyWith(
        status: DownloadStatus.downloading,
        receivedBytes: 999,
      );
      final part = store.partFile(running);
      await part.parent.create(recursive: true);
      await part.writeAsBytes(List<int>.filled(42, 0));

      final gone = _entry(itemId: 'i2').copyWith(
        status: DownloadStatus.completed,
        fileName: 'media.mkv',
      );
      await store.save(<DownloadEntry>[running, gone]);

      final loaded = await store.load();
      expect(loaded, hasLength(1), reason: 'a finished copy with no file is dropped');
      expect(loaded.single.status, DownloadStatus.queued);
      expect(loaded.single.receivedBytes, 42);
    });

    test('an id cannot climb out of the folder', () {
      final entry = DownloadEntry(
        profileId: 'p1',
        itemId: '../../etc',
        title: 'x',
        createdAt: DateTime.utc(2026),
      );
      expect(p.isWithin(root.path, store.itemDir(entry).path), isTrue);
    });
  });

  group('engine', () {
    late DownloadEngine engine;
    setUp(() => engine = DownloadEngine(store: store, client: Dio()));

    Future<DownloadEntry> fetch(DownloadEntry entry, {CancelToken? cancel, void Function(int)? seen}) =>
        engine.fetch(
          entry,
          server.base.resolve('/Items/${entry.itemId}/Download'),
          cancel: cancel,
          onProgress: (received, _) => seen?.call(received),
        );

    test('a fresh download lands under its own name', () async {
      final result = await fetch(_entry());

      expect(result.status, DownloadStatus.completed);
      expect(result.fileName, 'media.mkv');
      expect(result.totalBytes, testFile.length);
      expect(await store.mediaFile(result)!.readAsBytes(), testFile);
      expect(store.partFile(result).existsSync(), isFalse);
      expect(server.ranges.single, isNull);
    });

    test('a partial file is continued from where it stopped', () async {
      final entry = _entry();
      final part = store.partFile(entry);
      await part.parent.create(recursive: true);
      await part.writeAsBytes(testFile.sublist(0, 100000));

      final result = await fetch(entry);

      expect(server.ranges.single, 'bytes=100000-');
      expect(result.status, DownloadStatus.completed);
      expect(await store.mediaFile(result)!.readAsBytes(), testFile);
    });

    test('a server that ignores the range overwrites rather than appends', () async {
      server.honourRange = false;
      final entry = _entry();
      final part = store.partFile(entry);
      await part.parent.create(recursive: true);
      await part.writeAsBytes(testFile.sublist(0, 100000));

      final result = await fetch(entry);

      expect(result.status, DownloadStatus.completed);
      expect(await store.mediaFile(result)!.readAsBytes(), testFile);
    });

    test('a finished partial file whose rename was lost is completed', () async {
      final entry = _entry();
      final part = store.partFile(entry);
      await part.parent.create(recursive: true);
      await part.writeAsBytes(testFile);

      final result = await fetch(entry);

      expect(result.status, DownloadStatus.completed);
      expect(await store.mediaFile(result)!.readAsBytes(), testFile);
    });

    test('a refusal is a sentence, not an exception', () async {
      server.status = 403;
      final result = await fetch(_entry());

      expect(result.status, DownloadStatus.failed);
      expect(result.error, contains('not allowed'));
    });

    test('a cancel pauses and keeps the partial file', () async {
      server.hold = Completer<void>();
      final cancel = CancelToken();

      final result = await fetch(
        _entry(),
        cancel: cancel,
        seen: (received) {
          if (received > 0 && !cancel.isCancelled) cancel.cancel();
        },
      );
      server.hold!.complete();

      expect(result.status, DownloadStatus.paused);
      expect(result.receivedBytes, greaterThan(0));
      expect(store.partFile(result).lengthSync(), result.receivedBytes);
    });
  });

  group('controller', () {
    ProviderContainer container0() {
      final container = ProviderContainer(
        overrides: [
          downloadStoreProvider.overrideWith((ref) async => store),
          downloadEngineProvider.overrideWith(
            (ref) async => DownloadEngine(store: store, client: Dio()),
          ),
          downloadSourceProvider.overrideWithValue(
            (profileId) => profileId == 'p1' ? _Source(server.base) : null,
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    Future<DownloadEntry> settled(ProviderContainer c, String key) async {
      for (var i = 0; i < 500; i++) {
        final e = c.read(downloadsProvider).where((e) => e.key == key).firstOrNull;
        if (e != null && !e.status.isActive) return e;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      fail('the download never settled');
    }

    test('a queued item is fetched and written to the index', () async {
      final c = container0();
      final controller = c.read(downloadsProvider.notifier);
      await controller.ready;

      await controller.enqueue(
        _Source(server.base),
        const ServerItem(id: 'i1', title: 'The Film', kind: ServerItemKind.movie),
      );
      final done = await settled(c, 'p1/i1');

      expect(done.status, DownloadStatus.completed);
      // The index is written just after the state changes, not with it.
      var reloaded = await store.load();
      for (var i = 0; i < 300 && reloaded.single.status != DownloadStatus.completed; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        reloaded = await store.load();
      }
      expect(reloaded.single.status, DownloadStatus.completed);
    });

    test('a series is not something to download on its own', () async {
      final c = container0();
      final controller = c.read(downloadsProvider.notifier);
      await controller.ready;

      await controller.enqueue(
        _Source(server.base),
        const ServerItem(id: 's1', title: 'Show', kind: ServerItemKind.series),
      );
      expect(c.read(downloadsProvider), isEmpty);
    });

    test('a delete removes the entry and its folder', () async {
      final c = container0();
      final controller = c.read(downloadsProvider.notifier);
      await controller.ready;

      await controller.enqueue(
        _Source(server.base),
        const ServerItem(id: 'i1', title: 'The Film', kind: ServerItemKind.movie),
      );
      final done = await settled(c, 'p1/i1');
      await controller.delete(done.key);

      expect(c.read(downloadsProvider), isEmpty);
      expect(store.itemDir(done).existsSync(), isFalse);
      expect(await store.load(), isEmpty);
    });

    test('what the player needs is saved beside the file', () async {
      final container = ProviderContainer(
        overrides: [
          downloadStoreProvider.overrideWith((ref) async => store),
          downloadEngineProvider.overrideWith(
            (ref) async => DownloadEngine(store: store, client: Dio()),
          ),
          downloadSourceProvider.overrideWithValue(
            (profileId) => _DescribedSource(server.base),
          ),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(downloadsProvider.notifier);
      await controller.ready;

      await controller.enqueue(
        _DescribedSource(server.base),
        const ServerItem(id: 'i1', title: 'The Film', kind: ServerItemKind.movie),
      );
      final done = await settled(container, 'p1/i1');
      final meta = await store.readMeta(done);

      expect(meta, isNotNull);
      expect(meta!.runtime, const Duration(minutes: 90));
      expect(meta.position, const Duration(minutes: 5));
      expect(meta.chapters.single.title, 'Start');
      expect(meta.segments.single.kind, MediaSegmentKind.intro);
      expect(meta.streams.single.language, 'eng');
      expect(meta.defaultAudioIndex, 1);
      expect(meta.subtitles.single.fileName, 'sub-3.srt');
      expect(store.subtitleFile(done, 'sub-3.srt').existsSync(), isTrue);
    });
  });
}
