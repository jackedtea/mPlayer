// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mplayer/app/theme.dart';
import 'package:mplayer/downloads/download_engine.dart';
import 'package:mplayer/downloads/download_models.dart';
import 'package:mplayer/downloads/download_store.dart';
import 'package:mplayer/downloads/downloads_controller.dart';
import 'package:mplayer/downloads/offline_media_source.dart';
import 'package:mplayer/downloads/offline_meta.dart';
import 'package:mplayer/features/servers/servers_empty_page.dart';
import 'package:mplayer/l10n/app_localizations.dart';
import 'package:mplayer/servers/jellyfin_media_source.dart';
import 'package:mplayer/servers/media_library_source.dart';
import 'package:mplayer/sources/media_source.dart';

import 'fake_library_source.dart';

/// A server that is either there or not, and remembers what it was told.
class _Server extends FakeLibrarySource {
  _Server({this.reachable = true, this.position});

  bool reachable;
  final Duration? position;
  final List<String> stopped = <String>[];

  @override
  Future<ServerItem> item(String itemId) async {
    if (!reachable) throw const ServerException('Could not reach the server.');
    return ServerItem(id: itemId, title: itemId, position: position);
  }

  @override
  Future<void> reportStopped(
    String itemId, {
    required Duration position,
    String? playSessionId,
  }) async {
    if (!reachable) throw const ServerException('Could not reach the server.');
    stopped.add('$itemId@${position.inSeconds}');
  }
}

DownloadEntry _copy(
  String id, {
  String? series,
  int? season,
  int? episode,
  DownloadStatus status = DownloadStatus.completed,
}) =>
    DownloadEntry(
      profileId: 'p1',
      itemId: id,
      title: 'Title $id',
      createdAt: DateTime.utc(2026, 11, 2),
      kind: series == null ? ServerItemKind.movie : ServerItemKind.episode,
      seriesId: series,
      seriesTitle: series,
      seasonNumber: season,
      episodeNumber: episode,
      status: status,
      receivedBytes: 4,
      totalBytes: 4,
      fileName: status == DownloadStatus.completed ? 'media.mkv' : null,
    );

void main() {
  late Directory root;
  late DownloadStore store;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('mplayer_offline_');
    store = DownloadStore(root);
  });

  tearDown(() async {
    if (root.existsSync()) await root.delete(recursive: true);
  });

  /// Writes [entries] to disk as finished copies, then opens a controller
  /// over them with [signedIn] as the server for p1.
  Future<DownloadsController> controllerOver(
    List<DownloadEntry> entries, {
    MediaLibrarySource? signedIn,
  }) async {
    for (final e in entries) {
      if (e.status != DownloadStatus.completed) continue;
      final file = store.mediaFile(e)!;
      await file.parent.create(recursive: true);
      await file.writeAsBytes(<int>[1, 2, 3, 4]);
    }
    await store.save(entries);

    final container = ProviderContainer(
      overrides: [
        downloadStoreProvider.overrideWith((ref) async => store),
        downloadEngineProvider.overrideWith(
          (ref) async => DownloadEngine(store: store, client: Dio()),
        ),
        downloadSourceProvider.overrideWithValue(
          (profileId) => profileId == 'p1' ? signedIn : null,
        ),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(downloadsProvider.notifier);
    await controller.ready;
    return controller;
  }

  test('the saved description survives a round trip', () {
    const meta = OfflineMeta(
      runtime: Duration(minutes: 50),
      position: Duration(minutes: 12),
      chapters: <OfflineChapter>[
        OfflineChapter(title: 'Cold open', start: Duration.zero),
      ],
      segments: <MediaSegment>[
        MediaSegment(
          kind: MediaSegmentKind.intro,
          start: Duration.zero,
          end: Duration(seconds: 90),
        ),
      ],
      streams: <ServerStream>[
        ServerStream(
          index: 1,
          type: ServerStreamType.audio,
          language: 'eng',
          title: 'English - Dolby Digital - 5.1',
          channels: 6,
        ),
      ],
      subtitles: <OfflineSubtitle>[
        OfflineSubtitle(fileName: 'sub-3.srt', label: 'English - SRT', index: 3),
      ],
      defaultAudioIndex: 1,
      defaultSubtitleIndex: -1,
    );

    final back = OfflineMeta.fromJson(meta.toJson());
    expect(back.runtime, meta.runtime);
    expect(back.position, meta.position);
    expect(back.chapters.single.title, 'Cold open');
    expect(back.segments.single, meta.segments.single);
    expect(back.streams.single.label, 'English - Dolby Digital - 5.1');
    expect(back.streams.single.type, ServerStreamType.audio);
    expect(back.subtitles.single.index, 3);
    expect(back.defaultSubtitleIndex, -1);
  });

  test('chapters end where the next begins, the last at the runtime', () {
    const meta = OfflineMeta(
      chapters: <OfflineChapter>[
        OfflineChapter(title: 'A', start: Duration.zero),
        OfflineChapter(title: 'B', start: Duration(minutes: 10)),
      ],
    );
    final chapters = chaptersOf(meta, runtime: const Duration(minutes: 40));
    expect(chapters.first.end, const Duration(minutes: 10));
    expect(chapters.last.end, const Duration(minutes: 40));
  });

  group('offline source', () {
    test('a whole copy plays from the file with what was saved beside it', () async {
      final entry = _copy('m1');
      final controller = await controllerOver(<DownloadEntry>[entry]);
      await store.writeMeta(
        entry,
        const OfflineMeta(
          position: Duration(minutes: 7),
          defaultAudioIndex: 1,
          subtitles: <OfflineSubtitle>[
            OfflineSubtitle(fileName: 'sub-3.srt', label: 'English'),
            OfflineSubtitle(fileName: 'sub-4.srt', label: 'Gone'),
          ],
        ),
      );
      await store.subtitleFile(entry, 'sub-3.srt').writeAsString('1\n');

      final source = OfflineMediaSource(profileId: 'p1', downloads: controller);
      final media = await source.resolve(
        const MediaRef(sourceId: 'p1', itemId: 'm1', title: ''),
      );

      expect(media.uri.scheme, 'file');
      expect(media.uri.toFilePath(), store.mediaFile(entry)!.path);
      expect(media.startPosition, const Duration(minutes: 7));
      expect(media.defaultAudioIndex, 1);
      expect(media.isDirectPlay, isTrue);
      expect(
        media.externalSubtitles.map((s) => s.label),
        <String>['English'],
        reason: 'a subtitle whose file is missing is left out',
      );
    });

    test('nothing downloaded and no server is a sentence', () async {
      final controller = await controllerOver(const <DownloadEntry>[]);
      final source = OfflineMediaSource(profileId: 'p1', downloads: controller);

      expect(
        source.resolve(const MediaRef(sourceId: 'p1', itemId: 'x', title: '')),
        throwsA(isA<MediaSourceException>()),
      );
    });

    test('an unfinished copy streams from the server instead', () async {
      final controller = await controllerOver(<DownloadEntry>[
        _copy('m1', status: DownloadStatus.paused),
      ]);
      final source = OfflineMediaSource(
        profileId: 'p1',
        downloads: controller,
        online: JellyfinMediaSource(_Server()),
      );

      final media = await source.resolve(
        const MediaRef(sourceId: 'p1', itemId: 'm1', title: ''),
      );
      expect(media.uri.scheme, 'https');
    });

    test('the server has the last word on where to start, when it answers', () async {
      final controller = await controllerOver(<DownloadEntry>[_copy('m1')]);
      final source = OfflineMediaSource(
        profileId: 'p1',
        downloads: controller,
        online: JellyfinMediaSource(_Server(position: const Duration(minutes: 30))),
      );

      final media = await source.resolve(
        const MediaRef(sourceId: 'p1', itemId: 'm1', title: ''),
      );
      expect(media.uri.scheme, 'file');
      expect(media.startPosition, const Duration(minutes: 30));
    });

    test('a stop played here outranks what the server has not heard yet', () async {
      final controller = await controllerOver(<DownloadEntry>[_copy('m1')]);
      await controller.recordUnreported('p1', 'm1', const Duration(minutes: 44));
      final source = OfflineMediaSource(
        profileId: 'p1',
        downloads: controller,
        online: JellyfinMediaSource(_Server(reachable: false)),
      );

      final media = await source.resolve(
        const MediaRef(sourceId: 'p1', itemId: 'm1', title: ''),
      );
      expect(media.startPosition, const Duration(minutes: 44));
    });

    test('offline, next and previous walk the episodes on the device', () async {
      final controller = await controllerOver(<DownloadEntry>[
        _copy('e3', series: 's', season: 1, episode: 3),
        _copy('e1', series: 's', season: 1, episode: 1),
        _copy('m1'),
        _copy('e2', series: 's', season: 1, episode: 2, status: DownloadStatus.paused),
      ]);
      final source = OfflineMediaSource(profileId: 'p1', downloads: controller);

      final run = await source.siblingsOf(
        const MediaRef(sourceId: 'p1', itemId: 'e3', title: ''),
      );
      expect(run.items.map((m) => m.itemId), <String>['e1', 'e3']);
      expect(run.index, 1);
    });

    test('a stop the server cannot hear is kept, then handed over at sign-in', () async {
      final server = _Server(reachable: false);
      final controller = await controllerOver(<DownloadEntry>[_copy('m1')]);
      final source = OfflineMediaSource(
        profileId: 'p1',
        downloads: controller,
        online: JellyfinMediaSource(server),
      );
      await source.resolve(const MediaRef(sourceId: 'p1', itemId: 'm1', title: ''));

      await source.reportStopped('m1', position: const Duration(seconds: 600));
      expect(server.stopped, isEmpty);
      expect(controller.unreportedPosition('p1', 'm1'), const Duration(seconds: 600));
      expect(await store.readPendingReports(), hasLength(1));

      // A later launch, signed in to a server that answers.
      final online = _Server();
      await controllerOver(<DownloadEntry>[_copy('m1')], signedIn: online);
      for (var i = 0; i < 100 && online.stopped.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(online.stopped, <String>['m1@600']);
      // Forgotten once delivered — written just after, not with, the report.
      var pending = await store.readPendingReports();
      for (var i = 0; i < 100 && pending.isNotEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        pending = await store.readPendingReports();
      }
      expect(pending, isEmpty);
    });
  });

  testWidgets('with something downloaded, the server-less Home offers it', (tester) async {
    Future<void> pump(Set<String> profiles) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            downloadedProfilesProvider.overrideWithValue(profiles),
          ],
          child: MaterialApp(
            theme: buildTheme(Brightness.dark),
            locale: const Locale('en'),
            localizationsDelegates: const <LocalizationsDelegate<Object>>[
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: const ServersEmptyPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pump(const <String>{});
    expect(find.text('Watch downloads'), findsNothing);

    await pump(const <String>{'p1'});
    expect(find.text('Watch downloads'), findsOneWidget);
  });
}
