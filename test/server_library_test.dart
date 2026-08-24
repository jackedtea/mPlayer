// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mplayer/core/models/media_models.dart';
import 'package:mplayer/features/servers/server_library.dart';
import 'package:mplayer/l10n/app_localizations.dart';
import 'package:mplayer/servers/media_library_source.dart';

Future<AppLocalizations> english() =>
    AppLocalizations.delegate.load(const Locale('en'));

void main() {
  group('duration labels', () {
    test('read the way the design writes them', () {
      expect(durationLabel(const Duration(hours: 2, minutes: 16)), '2h 16m');
      expect(durationLabel(const Duration(minutes: 48)), '48m');
      // A whole number of hours drops the minutes rather than saying "2h 0m".
      expect(durationLabel(const Duration(hours: 2)), '2h');
    });

    test('never says 0m', () {
      // Under a minute left reads as finished, and the caller checks for
      // that separately — a "0m" card would say the opposite.
      expect(durationLabel(const Duration(seconds: 20)), '1m');
    });
  });

  group('remaining', () {
    test('an item in progress reports what is left, not what was watched',
        () async {
      final l10n = await english();
      final item = ServerItem(
        id: 'a1',
        title: 'Dune',
        runtime: const Duration(minutes: 155),
        position: const Duration(minutes: 114),
      );

      expect(remainingLabel(item, l10n), '41m left');
    });

    test('an item never started reports its whole runtime', () async {
      final l10n = await english();
      final item = ServerItem(
        id: 'a2',
        title: 'Arrival',
        runtime: const Duration(minutes: 116),
      );

      expect(remainingLabel(item, l10n), '1h 56m left');
    });

    test('a finished item says nothing rather than a negative', () async {
      final l10n = await english();
      final item = ServerItem(
        id: 'a3',
        title: 'Done',
        runtime: const Duration(minutes: 90),
        position: const Duration(minutes: 92),
      );

      expect(remainingLabel(item, l10n), '');
    });

    test('an item with no runtime says nothing', () async {
      final l10n = await english();

      expect(remainingLabel(const ServerItem(id: 'a4', title: 'Live'), l10n), '');
    });
  });

  group('resume cards', () {
    test('an episode is named by its series and number', () async {
      // "The Bicameral Mind" on its own tells the user nothing about what
      // they are resuming.
      final l10n = await english();
      final card = resumeItemFrom(
        const ServerItem(
          id: 'e1',
          title: 'The Bicameral Mind',
          kind: ServerItemKind.episode,
          seriesTitle: 'Westworld',
          seasonNumber: 1,
          episodeNumber: 10,
          runtime: Duration(minutes: 90),
          position: Duration(minutes: 45),
        ),
        l10n,
        serverLabel: 'Home',
      );

      expect(card.title, 'Westworld · S1E10');
      expect(card.progress, closeTo(0.5, 0.01));
      expect(card.sourceKind, SourceKind.jellyfin);
      expect(card.sourceLabel, 'Home');
    });

    test('a film keeps its own title', () async {
      final l10n = await english();
      final card = resumeItemFrom(
        const ServerItem(id: 'a1', title: 'Dune', kind: ServerItemKind.movie),
        l10n,
        serverLabel: 'Home',
      );

      expect(card.title, 'Dune');
      expect(card.progress, 0);
    });

    test('quality is left empty rather than guessed', () async {
      // The server states no tier, and deriving "4K HDR" from a height would
      // be a guess presented as a fact.
      final l10n = await english();
      final card = resumeItemFrom(
        const ServerItem(id: 'a1', title: 'Dune'),
        l10n,
        serverLabel: 'Home',
      );

      expect(card.quality, '');
    });
  });

  group('library tiles', () {
    test('a year the server did not state leaves the line empty', () {
      final tile = libraryItemFrom(const ServerItem(id: 'a1', title: 'Dune'));

      expect(tile.year, '');
      expect(tile.watched, isFalse);
    });

    test('played carries through to the tick', () {
      final tile = libraryItemFrom(
        const ServerItem(id: 'a1', title: 'Dune', year: 2021, played: true),
      );

      expect(tile.year, '2021');
      expect(tile.watched, isTrue);
    });
  });

  group('library sections', () {
    test('each collection type gets its own icon', () {
      expect(iconForLibrary('movies'), Icons.movie_rounded);
      expect(iconForLibrary('tvshows'), Icons.live_tv_rounded);
      expect(iconForLibrary('music'), Icons.library_music_rounded);
    });

    test('a type this build has never heard of still gets a tile', () {
      expect(iconForLibrary('livetv'), Icons.folder_rounded);
      expect(iconForLibrary('unknown'), Icons.folder_rounded);
    });

    test('a view with no count reports zero rather than failing', () {
      final section = librarySectionFrom(
        const LibraryView(id: 'v1', name: 'Odds', kind: 'unknown'),
      );

      expect(section.name, 'Odds');
      expect(section.itemCount, 0);
    });
  });
}
