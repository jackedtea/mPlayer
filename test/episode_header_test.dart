// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_library_source.dart';

import 'package:mplayer/app/app.dart';
import 'package:mplayer/app/router.dart';
import 'package:mplayer/features/servers/episode_page.dart';
import 'package:mplayer/features/servers/item_action_row.dart';
import 'package:mplayer/features/servers/server_library.dart';
import 'package:mplayer/servers/media_library_source.dart';
import 'package:mplayer/widgets/backdrop_header.dart';

const _title =
    'Em-Shade! Operation 1: The Seven Shadows Want Their Mission to Succeed';

/// The episode from the report: a long title, under a tall status bar.
class _Server extends FakeLibrarySource {
  _Server();

  @override
  Future<ServerItem> item(String itemId) async => ServerItem(
    id: 'e1',
    title: _title,
    kind: ServerItemKind.episode,
    seriesId: 's1',
    seriesTitle: 'The Eminence in Shadow',
    seasonNumber: 1,
    episodeNumber: 0,
    runtime: const Duration(minutes: 2),
    originalTitle: '陰の実力者になりたくて！',
    premiereDate: _aired,
    rating: 7.7,
  );

  @override
  Future<ServerPlayback> playback(
    String itemId,
    PlaybackCapabilities caps, {
    int? audioStreamIndex,
    int? subtitleStreamIndex,
    String? mediaSourceId,
  }) async => ServerPlayback(
    uri: Uri.parse('https://media.home.lan/Videos/$itemId/stream'),
    isDirectPlay: true,
    streams: const <ServerStream>[
      ServerStream(
        index: 0,
        type: ServerStreamType.video,
        codec: 'hevc',
        width: 1920,
        height: 1080,
        videoRange: 'SDR',
      ),
    ],
  );
}

final _aired = DateTime(2013, 7, 6);

Future<void> _open(WidgetTester tester, {double textScale = 1.0}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(400, 860);
  tester.view.padding = const FakeViewPadding(top: 48, bottom: 24);
  tester.view.viewPadding = const FakeViewPadding(top: 48, bottom: 24);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  final router = buildRouter();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [activeServerProvider.overrideWithValue(_Server())],
      child: MPlayerApp(router: router),
    ),
  );
  await tester.pumpAndSettle();
  router.push('/library/episode', extra: 'e1');
  await tester.pumpAndSettle();
}

void main() {
  for (final scale in <double>[1.0, 1.4]) {
    testWidgets('the title clears the back button at text scale $scale', (
      tester,
    ) async {
      await _open(tester, textScale: scale);

      final back = tester.getRect(find.byTooltip('Back').first);
      final series = tester.getRect(find.text('The Eminence in Shadow'));
      final title = tester.getRect(find.text(_title));

      expect(series.top, greaterThanOrEqualTo(back.bottom));
      expect(title.top, greaterThan(series.top));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the title sits on the faded foot of the artwork', (
    tester,
  ) async {
    await _open(tester);

    final header = tester.getRect(find.byType(BackdropHeader));
    final series = tester.getRect(find.text('The Eminence in Shadow'));

    // 220 of artwork; the title block may reach only [overlap] into it.
    expect(
      series.top - header.top,
      greaterThanOrEqualTo(220 - BackdropHeader.overlap - 0.5),
    );
  });

  testWidgets('a phone gets the glyph row, not scrolling chips', (
    tester,
  ) async {
    await _open(tester);

    expect(find.byType(ItemActionIcons), findsOneWidget);
    expect(find.byType(ItemActionRow), findsNothing);
    expect(find.text('Mark as watched'), findsNothing);
  });

  testWidgets('the header carries the facts the server filled in', (
    tester,
  ) async {
    await _open(tester);

    expect(find.text('陰の実力者になりたくて！'), findsOneWidget);
    expect(find.text('S1E0'), findsOneWidget);
    expect(find.text('7/6/2013'), findsOneWidget);
    expect(find.text('2m'), findsOneWidget);
    expect(find.text('7.7'), findsOneWidget);
    expect(find.textContaining('Ends at '), findsOneWidget);
    expect(find.text('1080p HEVC SDR'), findsOneWidget);
  });

  group('videoSummary', () {
    ServerStream video({int? w, int? h, String? codec, String? range}) =>
        ServerStream(
          index: 0,
          type: ServerStreamType.video,
          width: w,
          height: h,
          codec: codec,
          videoRange: range,
        );

    test('names the class, the codec and the range', () {
      expect(
        videoSummary(video(w: 3840, h: 2160, codec: 'hevc', range: 'HDR10')),
        '4K HEVC HDR10',
      );
      expect(videoSummary(video(w: 1280, h: 720, codec: 'h264')), '720p H.264');
    });

    test('a scope film is the 1080p it is, not 800p', () {
      expect(videoSummary(video(w: 1920, h: 800, codec: 'av1')), '1080p AV1');
    });

    test('says nothing it was not told', () {
      expect(videoSummary(video()), '');
    });
  });
}
