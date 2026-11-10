// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/admin/admin_activity_page.dart';
import '../features/admin/admin_add_library_page.dart';
import '../features/admin/admin_api_keys_page.dart';
import '../features/admin/admin_dashboard_page.dart';
import '../features/admin/admin_item_page.dart';
import '../features/admin/admin_libraries_page.dart';
import '../features/admin/admin_logs_page.dart';
import '../features/admin/admin_plugins_page.dart';
import '../features/admin/admin_storage_page.dart';
import '../features/admin/admin_tasks_page.dart';
import '../features/admin/admin_user_page.dart';
import '../features/admin/admin_users_page.dart';
import '../features/downloads/download_settings_page.dart';
import '../features/downloads/downloads_page.dart';
import '../features/home/favorites_page.dart';
import '../features/home/home_page.dart';
import '../features/libraries/libraries_page.dart';
import '../features/playback/smoke_test_page.dart';
import '../features/player/playback_controller.dart';
import '../features/player/playback_state.dart';
import '../features/player/player_page.dart';
import '../features/remote/remote_page.dart';
import '../features/search/search_page.dart';
import '../features/music/album_page.dart';
import '../features/music/artist_page.dart';
import '../features/music/now_playing_page.dart';
import '../features/servers/episode_page.dart';
import '../features/servers/library_grid_page.dart';
import '../features/servers/person_page.dart';
import '../features/servers/movie_detail_page.dart';
import '../features/servers/series_page.dart';
import '../features/settings/about_page.dart';
import '../features/settings/appearance_page.dart';
import '../features/settings/audio_settings_page.dart';
import '../features/settings/diagnostics_page.dart';
import '../features/settings/privacy_page.dart';
import '../features/settings/general_settings_page.dart';
import '../features/settings/player_settings_page.dart';
import '../features/settings/settings_index_page.dart';
import '../features/settings/subtitle_settings_page.dart';
import '../sources/media_source.dart';
import 'adaptive_scaffold.dart';

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Home is the initial location, and it is still not a login wall: with
/// nothing configured it is an empty state that offers to add one, and with a
/// server not opened yet it is the server list. See [HomeTabPage].
///
/// The branches are in [AppBranch] order.
GoRouter buildRouter() {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/home',
    routes: <RouteBase>[
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AdaptiveScaffold(navigationShell: navigationShell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeTabPage(),
                routes: <RouteBase>[
                  // Inside the branch, so the navigation bar stays under it.
                  GoRoute(
                    path: 'favorites',
                    builder: (context, state) => const FavoritesPage(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/libraries',
                // Opens straight into the last library browsed; the films and
                // series it opens cover the shell through `/library/...`.
                builder: (context, state) => const LibrariesPage(),
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
          // Not built yet; the tab holds its place in the bar.
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/downloads',
                builder: (context, state) => const DownloadsPage(),
              ),
            ],
          ),
          // **Settings is a destination, not an app-bar button.**
          //
          // It used to sit above the shell, reached by an icon in the
          // top-right corner of two screens — the one corner of a tall phone
          // a thumb cannot reach without shifting grip.
          //
          // Its sub-pages are nested *inside* the branch on purpose: the
          // navigation bar stays visible while the user is in them, so
          // leaving Settings is one thumb-press on another destination rather
          // than a reach for the back arrow.
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/settings',
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
                    path: 'downloads',
                    builder: (context, state) => const DownloadSettingsPage(),
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
            ],
          ),
        ],
      ),
      // Administration. Above the shell like the library screens, because it
      // is reached from Settings and replaces the whole window rather than
      // living inside a tab.
      //
      // Every screen behind these guards itself: the route being reachable is
      // not permission, and a link pasted by someone who is not an
      // administrator lands on a sentence saying so rather than on a blank
      // dashboard that 403s in the background.
      GoRoute(
        path: '/admin',
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const AdminDashboardPage(),
        routes: <RouteBase>[
          GoRoute(
            path: 'libraries',
            builder: (context, state) => const AdminLibrariesPage(),
            routes: <RouteBase>[
              GoRoute(
                path: 'new',
                builder: (context, state) => const AdminAddLibraryPage(),
              ),
            ],
          ),
          // One item's metadata editor, opened from the item's own ⋮. The
          // title rides in the query for the app bar before the item loads.
          GoRoute(
            path: 'item/:id',
            builder: (context, state) => AdminItemPage(
              itemId: state.pathParameters['id']!,
              title: state.uri.queryParameters['title'] ?? '',
            ),
          ),
          GoRoute(
            path: 'storage',
            builder: (context, state) => const AdminStoragePage(),
          ),
          GoRoute(
            path: 'logs',
            builder: (context, state) => const AdminLogsPage(),
            routes: <RouteBase>[
              // The file name rides in the query: log names carry dots and
              // dashes a path segment would not mind, but a slash would.
              GoRoute(
                path: 'view',
                builder: (context, state) => AdminLogViewerPage(
                  name: state.uri.queryParameters['name'] ?? '',
                ),
              ),
            ],
          ),
          GoRoute(
            path: 'keys',
            builder: (context, state) => const AdminApiKeysPage(),
          ),
          GoRoute(
            path: 'tasks',
            builder: (context, state) => const AdminTasksPage(),
          ),
          GoRoute(
            path: 'users',
            builder: (context, state) => const AdminUsersPage(),
            routes: <RouteBase>[
              GoRoute(
                path: ':id',
                builder: (context, state) =>
                    AdminUserPage(userId: state.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(
            path: 'activity',
            builder: (context, state) => const AdminActivityPage(),
          ),
          GoRoute(
            path: 'plugins',
            builder: (context, state) => const AdminPluginsPage(),
          ),
        ],
      ),
      // Server library screens. They live above the shell rather than inside
      // one branch because they are reached from Home, Libraries and Search
      // alike. The Libraries tab shows its library in place, which keeps the
      // bar; this one is a box set or playlist drilled into, and what every
      // tile opens.
      GoRoute(
        path: '/library',
        parentNavigatorKey: _rootKey,
        // `extra` carries the library's id. Null means the route was opened
        // directly rather than from a tile, and the screen says so instead of
        // guessing at a library.
        // `title` in the query is what a collection passes: its name is not
        // in `/UserViews`, so the screen cannot look it up the way it looks up
        // a library's.
        // `browse` says whether this is a library — which carries the tab
        // bar — or a drill-down into one box set or playlist, which does not.
        builder: (context, state) => LibraryGridPage(
          viewId: state.extra as String?,
          title: state.uri.queryParameters['title'] ?? 'Library',
          browse: LibraryBrowse.fromQuery(state.uri.queryParameters['browse']),
          // A genre tile's grid: the library, narrowed to that genre.
          genre: state.uri.queryParameters['genre'],
          genreId: state.uri.queryParameters['genreId'],
        ),
        routes: <RouteBase>[
          GoRoute(
            path: 'movie',
            builder: (context, state) =>
                MovieDetailPage(itemId: state.extra as String?),
          ),
          GoRoute(
            path: 'person',
            // `extra` is the person's id; the name rides in the query because
            // the screen needs it for its app bar before any request lands.
            builder: (context, state) => PersonPage(
              personId: state.extra as String?,
              name: state.uri.queryParameters['name'] ?? '',
            ),
          ),
          GoRoute(
            path: 'episode',
            builder: (context, state) =>
                EpisodePage(episodeId: state.extra as String?),
          ),
          GoRoute(
            path: 'album',
            builder: (context, state) =>
                AlbumPage(albumId: state.extra as String?),
          ),
          GoRoute(
            path: 'artist',
            // Like a person: the id in `extra`, the name in the query for the
            // header to show before any request lands.
            builder: (context, state) => ArtistPage(
              artistId: state.extra as String?,
              name: state.uri.queryParameters['name'] ?? '',
            ),
          ),
          GoRoute(
            path: 'series',
            builder: (context, state) =>
                SeriesPage(seriesId: state.extra as String?),
          ),
        ],
      ),
      // The player is fullscreen and above the shell for every source alike.
      // It takes an already-resolved handle rather than an id, so the title
      // and source line are on screen before the first frame decodes — and so
      // the route cannot be deep-linked into with a stale token.
      GoRoute(
        path: '/player',
        parentNavigatorKey: _rootKey,
        builder: (context, state) {
          // Either a bare resolved item, or one with the queue its caller
          // assembled around it.
          final extra = state.extra;
          if (extra is PlayerLaunch) {
            return PlayerPage(media: extra.media, queue: extra.queue);
          }
          if (extra is PlayableMedia) {
            return PlayerPage(media: extra);
          }

          // `extra` is the weakest thing this route stands on. It lives in the
          // router's match list rather than in the URL, so anything that
          // rebuilds this route from its location alone — a restoration, a
          // router rebuilt under it — arrives here with nothing, and the
          // screen used to answer that by telling the user to go and pick a
          // file, however plainly a film was already playing.
          //
          // The controller remembers. If something is open, that is what this
          // route is for.
          return const _PlayerFromController();
        },
      ),
      // The music player's full-screen face. It takes nothing: the session
      // already holds what is playing, and leaving does not stop it.
      GoRoute(
        path: '/now-playing',
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const NowPlayingPage(),
      ),
      // Above the shell like the player: the remote is a screen of its own
      // in the hand, not a tab, and its connection outlives it anyway.
      GoRoute(
        path: '/remote',
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const RemotePage(),
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
/// The player for whatever is already open.
///
/// Not a guess: the controller only holds media once something has been
/// resolved and handed to the decoder, so reaching this with a non-null
/// `media` means playback is genuinely under way and the route simply lost
/// the argument it was pushed with.
class _PlayerFromController extends ConsumerWidget {
  const _PlayerFromController();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = ref.watch(playbackControllerProvider).media;
    if (media == null) return const _MissingMediaPage();

    return PlayerPage(media: media);
  }
}

class _MissingMediaPage extends StatelessWidget {
  const _MissingMediaPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: const Center(
        child: Text('Nothing to play — pick something from a server.'),
      ),
    );
  }
}
