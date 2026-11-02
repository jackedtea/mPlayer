// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mplayer/app/theme.dart';
import 'package:mplayer/downloads/download_models.dart';
import 'package:mplayer/downloads/download_store.dart';
import 'package:mplayer/downloads/downloads_controller.dart';
import 'package:mplayer/features/downloads/download_ui.dart';
import 'package:mplayer/features/downloads/downloads_page.dart';
import 'package:mplayer/l10n/app_localizations.dart';
import 'package:mplayer/servers/media_library_source.dart';

/// Holds a fixed list and writes down what it was asked to do.
class _Downloads extends DownloadsController {
  _Downloads(this.initial);

  final List<DownloadEntry> initial;
  final List<String> calls = <String>[];

  @override
  List<DownloadEntry> build() => initial;

  @override
  Future<void> pause(String key) async => calls.add('pause $key');

  @override
  Future<void> resume(String key) async => calls.add('resume $key');

  @override
  Future<void> delete(String key) async {
    calls.add('delete $key');
    state = <DownloadEntry>[for (final e in state) if (e.key != key) e];
  }
}

DownloadEntry _e(
  String id,
  DownloadStatus status, {
  String title = 'A title long enough to need more than one line on a phone',
  String? series,
  int? season,
  int? episode,
  int received = 0,
  int? total,
  String? error,
}) =>
    DownloadEntry(
      profileId: 'p1',
      itemId: id,
      title: title,
      createdAt: DateTime.utc(2026, 11, 2),
      kind: series == null ? ServerItemKind.movie : ServerItemKind.episode,
      seriesId: series == null ? null : 'series-$series',
      seriesTitle: series,
      seasonNumber: season,
      episodeNumber: episode,
      status: status,
      receivedBytes: received,
      totalBytes: total,
      error: error,
      fileName: status == DownloadStatus.completed ? 'media.mkv' : null,
    );

final _all = <DownloadEntry>[
  _e('d1', DownloadStatus.downloading,
      series: 'Severance', season: 2, episode: 3, received: 400 << 20, total: 1400 << 20),
  _e('q1', DownloadStatus.queued),
  _e('p1', DownloadStatus.paused, received: 10 << 20, total: 100 << 20),
  _e('f1', DownloadStatus.failed, error: 'This account is not allowed to download from the server.'),
  _e('c2', DownloadStatus.completed, series: 'Severance', season: 1, episode: 2, received: 900 << 20),
  _e('c1', DownloadStatus.completed, series: 'Severance', season: 1, episode: 1, received: 900 << 20),
  _e('m1', DownloadStatus.completed, title: 'Dune', received: 3 << 30),
];

Future<_Downloads> _pump(
  WidgetTester tester,
  List<DownloadEntry> entries, {
  Size size = const Size(400, 800),
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);

  final fake = _Downloads(entries);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        downloadsProvider.overrideWith(() => fake),
        downloadStoreProvider.overrideWith(
          (ref) async => DownloadStore(Directory('does-not-exist')),
        ),
        downloadSourceProvider.overrideWithValue((_) => null),
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
        home: const DownloadsPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return fake;
}

void main() {
  test('sizes read in the unit a person would say', () {
    expect(formatBytes(512), '512 B');
    expect(formatBytes(860 * 1024), '860 KB');
    expect(formatBytes(412 << 20), '412 MB');
    expect(formatBytes((1.4 * (1 << 30)).round()), '1.4 GB');
  });

  testWidgets('nothing downloaded says how to download something', (tester) async {
    await _pump(tester, const <DownloadEntry>[]);
    expect(find.text('Nothing downloaded'), findsOneWidget);
  });

  for (final size in const <Size>[Size(400, 800), Size(900, 1000), Size(1400, 900)]) {
    testWidgets('every status lays out at ${size.width.toInt()} wide', (tester) async {
      await _pump(tester, _all, size: size);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('unfinished copies lead, then films, then each series in airing order',
      (tester) async {
    await _pump(tester, _all, size: const Size(400, 2400));

    double top(Finder f) => tester.getTopLeft(f).dy;
    final progress = find.text('In progress');
    final films = find.text('Films');
    final series = find.text('Severance');
    final first = find.textContaining('S1E1');
    final second = find.textContaining('S1E2');

    expect(top(progress), lessThan(top(films)));
    expect(top(films), lessThan(top(series)));
    expect(top(first), lessThan(top(second)));
    // Under its own series' heading the name is not repeated; in the queue,
    // among other shows, it is.
    expect(find.textContaining('Severance · S2E3'), findsOneWidget);
    expect(find.textContaining('Severance · S1E1'), findsNothing);
  });

  testWidgets('a failure shows the sentence the engine wrote', (tester) async {
    await _pump(tester, _all, size: const Size(400, 2400));
    expect(find.text('This account is not allowed to download from the server.'), findsOneWidget);
    expect(find.text('Waiting for the server to sign in'), findsOneWidget);
  });

  testWidgets('pause, resume and cancel reach the controller', (tester) async {
    final fake = await _pump(tester, <DownloadEntry>[
      _e('d1', DownloadStatus.downloading, received: 1, total: 2),
      _e('p1', DownloadStatus.paused),
    ]);

    await tester.tap(find.byTooltip('Pause'));
    await tester.tap(find.byTooltip('Resume download'));
    await tester.tap(find.byTooltip('Cancel').first);
    await tester.pumpAndSettle();

    expect(fake.calls, <String>['pause p1/d1', 'resume p1/p1', 'delete p1/d1']);
  });

  testWidgets('removing a finished copy asks first', (tester) async {
    final fake = await _pump(tester, <DownloadEntry>[
      _e('m1', DownloadStatus.completed, title: 'Dune', received: 1),
    ]);

    await tester.tap(find.byTooltip('Remove download'));
    await tester.pumpAndSettle();
    expect(find.text('Remove this download?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(fake.calls, isEmpty);

    await tester.tap(find.byTooltip('Remove download'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(fake.calls, <String>['delete p1/m1']);
    expect(find.text('Nothing downloaded'), findsOneWidget);
  });
}
