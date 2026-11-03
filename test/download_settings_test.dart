// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mplayer/downloads/download_engine.dart';
import 'package:mplayer/downloads/download_models.dart';
import 'package:mplayer/downloads/download_platform.dart';
import 'package:mplayer/downloads/download_settings.dart';
import 'package:mplayer/downloads/download_store.dart';
import 'package:mplayer/downloads/downloads_controller.dart';
import 'package:mplayer/servers/media_library_source.dart';

import 'fake_library_source.dart';
import 'file_server.dart';

class _Source extends FakeLibrarySource {
  const _Source(this.base);

  final Uri base;

  @override
  Uri downloadUrl(String itemId) => base.resolve('/Items/$itemId/Download');
}

/// Writes down what the notification was told.
class _Platform extends DownloadPlatform {
  final List<String> calls = <String>[];

  @override
  bool get enabled => true;

  @override
  Future<void> show({required String title, required String text, int? percent}) async =>
      calls.add('show $title');

  @override
  Future<void> hide() async => calls.add('hide');
}

const _film = ServerItem(id: 'i1', title: 'The Film', kind: ServerItemKind.movie);

void main() {
  late Directory root;
  late DownloadStore store;
  late FileServer server;
  late StreamController<DownloadNetwork> network;
  late _Platform platform;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    root = await Directory.systemTemp.createTemp('mplayer_dlsettings_');
    store = DownloadStore(root);
    server = FileServer();
    await server.start();
    network = StreamController<DownloadNetwork>.broadcast();
    platform = _Platform();
  });

  tearDown(() async {
    await network.close();
    await server.stop();
    // Best effort: a write the disposed controller had in flight can still
    // hold a file in the folder for a moment on Windows.
    try {
      if (root.existsSync()) await root.delete(recursive: true);
    } on FileSystemException catch (_) {}
  });

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [
        downloadStoreProvider.overrideWith((ref) async => store),
        downloadEngineProvider.overrideWith(
          (ref) async => DownloadEngine(store: store, client: Dio()),
        ),
        downloadSourceProvider.overrideWithValue((_) => _Source(server.base)),
        downloadNetworkProvider.overrideWith((ref) => network.stream),
        downloadPlatformProvider.overrideWithValue(platform),
      ],
    );
    addTearDown(c.dispose);
    // Kept alive and listening, as the running app keeps it.
    c.listen(downloadHoldProvider, (_, _) {});
    return c;
  }

  Future<DownloadEntry> until(
    ProviderContainer c,
    bool Function(DownloadEntry e) done,
  ) async {
    for (var i = 0; i < 500; i++) {
      final e = c.read(downloadsProvider).where((e) => e.key == 'p1/i1').firstOrNull;
      if (e != null && done(e)) return e;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    fail('never got there: ${c.read(downloadsProvider).map((e) => e.status)}');
  }

  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 30));

  test('cellular is metered, Wi-Fi and Ethernet are not', () {
    expect(downloadNetworkFrom(<ConnectivityResult>[ConnectivityResult.wifi]),
        DownloadNetwork.unmetered);
    expect(downloadNetworkFrom(<ConnectivityResult>[ConnectivityResult.ethernet]),
        DownloadNetwork.unmetered);
    expect(downloadNetworkFrom(<ConnectivityResult>[ConnectivityResult.mobile]),
        DownloadNetwork.metered);
    expect(
      downloadNetworkFrom(<ConnectivityResult>[ConnectivityResult.vpn, ConnectivityResult.mobile]),
      DownloadNetwork.metered,
    );
    expect(downloadNetworkFrom(<ConnectivityResult>[ConnectivityResult.none]),
        DownloadNetwork.none);
  });

  test('on mobile data the queue waits, and moves when Wi-Fi comes', () async {
    final c = container();
    final controller = c.read(downloadsProvider.notifier);
    await controller.ready;
    network.add(DownloadNetwork.metered);
    await settle();
    expect(c.read(downloadHoldProvider), DownloadHold.waitingForWifi);

    await controller.enqueue(_Source(server.base), _film);
    await settle();
    expect(c.read(downloadsProvider).single.status, DownloadStatus.queued);
    expect(server.ranges, isEmpty, reason: 'nothing was fetched on mobile data');

    network.add(DownloadNetwork.unmetered);
    final done = await until(c, (e) => e.status == DownloadStatus.completed);
    expect(await store.mediaFile(done)!.readAsBytes(), testFile);
  });

  test('turning Wi-Fi-only off lets mobile data download', () async {
    final c = container();
    final controller = c.read(downloadsProvider.notifier);
    await controller.ready;
    network.add(DownloadNetwork.metered);
    await c.read(downloadSettingsProvider.notifier).setWifiOnly(false);
    await settle();

    expect(c.read(downloadHoldProvider), isNull);
    await controller.enqueue(_Source(server.base), _film);
    await until(c, (e) => e.status == DownloadStatus.completed);
  });

  test('losing Wi-Fi mid-file puts it back in the queue, and it resumes', () async {
    final c = container();
    final controller = c.read(downloadsProvider.notifier);
    await controller.ready;
    network.add(DownloadNetwork.unmetered);
    await settle();

    server.hold = Completer<void>();
    await controller.enqueue(_Source(server.base), _film);
    await until(c, (e) => e.status == DownloadStatus.downloading);
    await Future<void>.delayed(const Duration(milliseconds: 100));

    network.add(DownloadNetwork.metered);
    final waiting = await until(c, (e) => e.status == DownloadStatus.queued);
    server.hold!.complete();
    server.hold = null;
    expect(store.partFile(waiting).existsSync(), isTrue);

    network.add(DownloadNetwork.unmetered);
    final done = await until(c, (e) => e.status == DownloadStatus.completed);
    expect(server.ranges.last, startsWith('bytes='), reason: 'resumed, not restarted');
    expect(await store.mediaFile(done)!.readAsBytes(), testFile);
  });

  test('the notification follows the file under way and goes when it is done', () async {
    final c = container();
    final controller = c.read(downloadsProvider.notifier);
    await controller.ready;
    network.add(DownloadNetwork.unmetered);
    await settle();

    await controller.enqueue(_Source(server.base), _film);
    await until(c, (e) => e.status == DownloadStatus.completed);
    await settle();

    expect(platform.calls.first, 'show The Film');
    expect(platform.calls.last, 'hide');
  });

  group('removing watched copies', () {
    Future<DownloadsController> withCopy(ProviderContainer c) async {
      final entry = DownloadEntry.fromItem(
        'p1',
        const ServerItem(
          id: 'i1',
          title: 'The Film',
          kind: ServerItemKind.movie,
          runtime: Duration(minutes: 100),
        ),
      ).copyWith(status: DownloadStatus.completed, fileName: 'media.mkv');
      final file = store.mediaFile(entry)!;
      await file.parent.create(recursive: true);
      await file.writeAsBytes(<int>[1]);
      await store.save(<DownloadEntry>[entry]);

      final controller = c.read(downloadsProvider.notifier);
      await controller.ready;
      return controller;
    }

    test('only when asked, and only past nine tenths', () async {
      final c = container();
      final controller = await withCopy(c);

      await controller.watchedTo('p1', 'i1', const Duration(minutes: 99));
      expect(c.read(downloadsProvider), hasLength(1), reason: 'the setting is off');

      await c.read(downloadSettingsProvider.notifier).setRemoveWatched(true);
      await controller.watchedTo('p1', 'i1', const Duration(minutes: 50));
      expect(c.read(downloadsProvider), hasLength(1), reason: 'half-watched stays');

      await controller.watchedTo('p1', 'i1', const Duration(minutes: 95));
      expect(c.read(downloadsProvider), isEmpty);
      expect(Directory('${root.path}/p1/i1').existsSync(), isFalse);
    });

    test('remove all empties the list and the disk', () async {
      final c = container();
      final controller = await withCopy(c);

      await controller.deleteAll();
      expect(c.read(downloadsProvider), isEmpty);
      expect(Directory('${root.path}/p1/i1').existsSync(), isFalse);
    });
  });
}
