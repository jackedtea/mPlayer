// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mplayer/app/theme.dart';
import 'package:mplayer/features/player/playback_controller.dart';
import 'package:mplayer/features/player/playback_state.dart';
import 'package:mplayer/features/player/track_dialog.dart';
import 'package:mplayer/l10n/app_localizations.dart';

const _english = MediaTrack(
  id: '1',
  kind: TrackKind.audio,
  label: 'English 5.1',
  language: 'eng',
  isDefault: true,
);
const _japanese = MediaTrack(
  id: '2',
  kind: TrackKind.audio,
  label: 'Japanese',
  language: 'jpn',
);
const _off = MediaTrack(id: 'no', kind: TrackKind.subtitle, label: 'Off');
const _subs = MediaTrack(
  id: '3',
  kind: TrackKind.subtitle,
  label: 'English SDH',
  language: 'vie',
);

/// A player with two audio tracks and one subtitle, no decoder behind it.
class _Player extends PlaybackController {
  @override
  PlaybackState build() => const PlaybackState(
        audioTracks: <MediaTrack>[_english, _japanese],
        subtitleTracks: <MediaTrack>[_off, _subs],
        activeAudio: _english,
        activeSubtitle: _off,
      );

  @override
  Future<void> setAudioTrack(MediaTrack track) async =>
      state = state.copyWith(activeAudio: track);

  @override
  Future<void> setSubtitleTrack(MediaTrack? track) async =>
      state = state.copyWith(activeSubtitle: track ?? _off);
}

Future<List<String>> _open(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);

  final calls = <String>[];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [playbackControllerProvider.overrideWith(_Player.new)],
      child: MaterialApp(
        theme: buildTheme(Brightness.dark),
        localizationsDelegates: const <LocalizationsDelegate<Object>>[
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Consumer(
          builder: (context, ref, _) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () {
                  final player = ref.read(playbackControllerProvider.notifier);
                  showAudioSubtitleDialog(
                    context,
                    onAudio: (t) {
                      calls.add('audio ${t.id}');
                      player.setAudioTrack(t);
                    },
                    onSubtitle: (t) {
                      calls.add('subtitle ${t?.id}');
                      player.setSubtitleTrack(t);
                    },
                    onOpenSubtitleFile: () => calls.add('file'),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return calls;
}

/// The tick beside [label], or nothing.
Finder _tickOn(String label) => find.descendant(
      of: find.widgetWithText(ListTile, label),
      matching: find.byIcon(Icons.check_rounded),
    );

void main() {
  for (final Size size in const <Size>[
    Size(390, 844),
    Size(844, 390),
    Size(1400, 900),
  ]) {
    testWidgets('audio on the left, subtitles on the right at '
        '${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      await _open(tester, size);

      expect(tester.takeException(), isNull);
      expect(find.text('Audio & subtitles'), findsOneWidget);
      expect(
        tester.getCenter(find.text('Japanese')).dx,
        lessThan(tester.getCenter(find.text('English SDH')).dx),
      );
      expect(_tickOn('English 5.1'), findsOneWidget);
      expect(_tickOn('Off'), findsOneWidget);
    });
  }

  testWidgets('a choice applies and the dialog stays for the other side',
      (tester) async {
    final calls = await _open(tester, const Size(844, 390));

    await tester.tap(find.text('Japanese'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English SDH'));
    await tester.pumpAndSettle();

    expect(calls, <String>['audio 2', 'subtitle 3']);
    expect(find.byType(AudioSubtitleDialog), findsOneWidget);
    // The ticks follow the player, not the tap.
    expect(_tickOn('Japanese'), findsOneWidget);
    expect(_tickOn('English 5.1'), findsNothing);
    expect(_tickOn('English SDH'), findsOneWidget);
  });

  testWidgets('opening a subtitle file closes the dialog first',
      (tester) async {
    final calls = await _open(tester, const Size(844, 390));

    await tester.tap(find.text('Open subtitle file…'));
    await tester.pumpAndSettle();

    expect(calls, <String>['file']);
    expect(find.byType(AudioSubtitleDialog), findsNothing);
  });

  testWidgets('each track says its language', (tester) async {
    await _open(tester, const Size(1400, 900));

    // A tag to scan by, whatever the muxer wrote: `eng`, `jpn`, `vie`.
    expect(find.text('EN'), findsOneWidget);
    expect(find.text('JA'), findsOneWidget);
    expect(find.text('VI'), findsOneWidget);
    // The full name, in its own language, where the title does not
    // already carry it...
    expect(find.text('日本語'), findsOneWidget);
    expect(find.text('Tiếng Việt'), findsOneWidget);
    // ...and not where it does: "English 5.1" needs no "English" under it.
    expect(find.text('Default'), findsOneWidget);
    expect(find.textContaining('English ·'), findsNothing);
    // Off has no language to show.
    expect(
      find.descendant(
        of: find.widgetWithText(ListTile, 'Off'),
        matching: find.text('VI'),
      ),
      findsNothing,
    );
  });
}
