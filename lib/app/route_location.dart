// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:go_router/go_router.dart';

/// The path of the route on top, or an empty string before the first match.
///
/// `state`, not `routerDelegate.currentConfiguration.uri`, which still names
/// the route underneath after a push. The player, `/library` and Now playing
/// are all pushed. `state` throws while nothing is matched, on the first frame.
String topRoutePath(GoRouter router) =>
    router.routerDelegate.currentConfiguration.isEmpty
    ? ''
    : router.state.uri.path;
