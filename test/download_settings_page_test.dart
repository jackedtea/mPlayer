// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mplayer/app/theme.dart';
import 'package:mplayer/downloads/download_models.dart';
import 'package:mplayer/downloads/downloads_controller.dart';
import 'package:mplayer/features/downloads/download_settings_page.dart';
import 'package:mplayer/l10n/app_localizations.dart';
import 'package:mplayer/servers/media_library_source.dart';

const _film = ServerItem(id: 'i1', title: 'The Film', kind: ServerItemKind.movie);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('the settings page toggles and asks before removing all', (tester) async {
    final entries = <DownloadEntry>[
      DownloadEntry.fromItem('p1', _film).copyWith(
        status: DownloadStatus.completed,
        receivedBytes: 3 << 30,
      ),
    ];
    final removed = <String>[];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          downloadsProvider.overrideWith(() => _Fixed(entries, removed)),
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
          home: const DownloadSettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('3.0 GB on this device'), findsOneWidget);

    final wifi = find.widgetWithText(SwitchListTile, 'Download on Wi-Fi only');
    expect(tester.widget<SwitchListTile>(wifi).value, isTrue);
    await tester.tap(wifi);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(wifi).value, isFalse);

    await tester.tap(find.text('Remove all downloads'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(removed, isEmpty);

    await tester.tap(find.text('Remove all downloads'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(removed, <String>['all']);
    expect(find.text('Nothing is downloaded on this device.'), findsOneWidget);
  });
}

class _Fixed extends DownloadsController {
  _Fixed(this.initial, this.removed);

  final List<DownloadEntry> initial;
  final List<String> removed;

  @override
  List<DownloadEntry> build() => initial;

  @override
  Future<void> deleteAll() async {
    removed.add('all');
    state = const <DownloadEntry>[];
  }
}
