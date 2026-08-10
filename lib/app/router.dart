// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/playback/smoke_test_page.dart';
import '../features/search/search_page.dart';
import '../features/server/server_empty_page.dart';
import '../features/settings/settings_index_page.dart';
import '../features/storage/storage_page.dart';
import 'adaptive_scaffold.dart';

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Storage is the initial location — the app must never open on a login or a
/// server check.
GoRouter buildRouter() {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/storage',
    routes: <RouteBase>[
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AdaptiveScaffold(navigationShell: navigationShell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/storage',
                builder: (context, state) => const StoragePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/server',
                builder: (context, state) => const ServerEmptyPage(),
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
