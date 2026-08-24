// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/browse/browser_page.dart';
import '../features/downloads/downloads_page.dart';
import '../features/playback/smoke_test_page.dart';
import '../features/player/player_page.dart';
import '../features/search/search_page.dart';
import '../features/servers/library_grid_page.dart';
import '../features/servers/movie_detail_page.dart';
import '../features/servers/series_page.dart';
import '../features/servers/servers_empty_page.dart';
import '../features/servers/servers_home_page.dart';
import '../features/settings/about_page.dart';
import '../features/settings/appearance_page.dart';
import '../features/settings/audio_settings_page.dart';
import '../features/settings/diagnostics_page.dart';
import '../features/settings/privacy_page.dart';
import '../features/settings/general_settings_page.dart';
import '../features/settings/player_settings_page.dart';
import '../features/settings/settings_index_page.dart';
import '../features/settings/subtitle_settings_page.dart';
import '../features/files/files_page.dart';
import '../sources/local_source.dart';
import '../sources/media_source.dart';
import 'adaptive_scaffold.dart';

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Files is the initial location — the app must never open on a login or a
/// server check.
GoRouter buildRouter() {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/files',
    routes: <RouteBase>[
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AdaptiveScaffold(navigationShell: navigationShell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/files',
                builder: (context, state) => const FilesPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/servers',
                builder: (context, state) => const ServersEmptyPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/search',
                builder: (context, state) => const SearchPage(),
              ),
            ],
          ),
        ],
      ),
      // Settings sits above the shell: it covers the navigation affordance
      // rather than living inside a branch.
      GoRoute(
        path: '/settings',
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const SettingsIndexPage(),
        routes: <RouteBase>[
          GoRoute(
            path: 'appearance',
            builder: (context, state) => const AppearancePage(),
          ),
          GoRoute(
            path: 'general',
            builder: (context, state) => const GeneralSettingsPage(),
          ),
          GoRoute(
            path: 'player',
            builder: (context, state) => const PlayerSettingsPage(),
          ),
          GoRoute(
            path: 'audio',
            builder: (context, state) => const AudioSettingsPage(),
          ),
          GoRoute(
            path: 'subtitle',
            builder: (context, state) => const SubtitleSettingsPage(),
          ),
          GoRoute(
            path: 'about',
            builder: (context, state) => const AboutPage(),
          ),
          GoRoute(
            path: 'diagnostics',
            builder: (context, state) => const DiagnosticsPage(),
          ),
          GoRoute(
            path: 'privacy',
            builder: (context, state) => const PrivacyPage(),
          ),
        ],
      ),
      // Server library screens. They live above the shell rather than inside
      // the Server branch because they are reached from search and from the
      // Files tab too, not only from the servers home.
      GoRoute(
        path: '/servers/home',
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const ServersHomePage(),
      ),
      GoRoute(
        path: '/library',
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const LibraryGridPage(),
        routes: <RouteBase>[
          GoRoute(
            path: 'movie',
            builder: (context, state) => const MovieDetailPage(),
          ),
          GoRoute(
            path: 'series',
            builder: (context, state) => const SeriesPage(),
          ),
        ],
      ),
      // `source` is a configured share's id, `path` a directory within it.
      // Both are query parameters so a folder can be linked to directly.
      GoRoute(
        path: '/browse',
        parentNavigatorKey: _rootKey,
        builder: (context, state) => BrowserPage(
          sourceId: state.uri.queryParameters['source'] ?? LocalSource.sourceId,
          path: state.uri.queryParameters['path'] ?? '',
        ),
      ),
      GoRoute(
        path: '/downloads',
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const DownloadsPage(),
      ),
      // The player is fullscreen and above the shell for every source alike.
      // It takes an already-resolved handle rather than an id, so the title
      // and source line are on screen before the first frame decodes — and so
      // the route cannot be deep-linked into with a stale token.
      GoRoute(
        path: '/player',
        parentNavigatorKey: _rootKey,
        builder: (context, state) {
          final media = state.extra;
          if (media is! PlayableMedia) {
            return const _MissingMediaPage();
          }
          return PlayerPage(media: media);
        },
      ),
      // Kept from Phase 0 — proves the media_kit pipeline end to end on each
      // platform. Superseded by the real player screen in build step 2.
      GoRoute(
        path: '/smoke',
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const SmokeTestPage(),
      ),
    ],
  );
}

/// Reached only if `/player` is entered without a resolved handle — a cold
/// deep link, or a restored route. Better than a black screen that never
/// decodes.
class _MissingMediaPage extends StatelessWidget {
  const _MissingMediaPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: const Center(
        child: Text('Nothing to play — pick a file from Files.'),
      ),
    );
  }
}
