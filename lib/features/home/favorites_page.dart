// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_localizations.dart';
import '../../servers/media_library_source.dart';
import '../search/kind_sections.dart';
import '../servers/server_library.dart';

/// Everything the user has starred, across every library, the way Jellyfin's
/// web client lays out its Favorites tab: Movies, Shows, Episodes, People.
///
/// Reached from the Home row's "See all". Inside the Home branch, so the
/// navigation bar stays under it.
class FavoritesPage extends ConsumerWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: context.canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: l10n.actionBack,
                onPressed: () => context.pop(),
              )
            : null,
        title: Text(l10n.favourites),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(favouriteItemsProvider);
          ref.invalidate(favouritePeopleProvider);
          await ref.read(favouritePeopleProvider.future);
        },
        child: KindSections(
          movies: ref.watch(favouriteItemsProvider(ServerItemKind.movie)),
          shows: ref.watch(favouriteItemsProvider(ServerItemKind.series)),
          episodes: ref.watch(favouriteItemsProvider(ServerItemKind.episode)),
          people: ref.watch(favouritePeopleProvider),
          emptyText: l10n.noFavouritesYet,
        ),
      ),
    );
  }
}

/// Whether Home shows its Favorites row.
///
/// On this device, unlike the library rows beside it: those are the server's
/// `LatestItemsExcludes`, which has no entry for favourites to go in.
final homeShowFavouritesProvider =
    AsyncNotifierProvider<HomeShowFavourites, bool>(HomeShowFavourites.new);

class HomeShowFavourites extends AsyncNotifier<bool> {
  static const _prefsKey = 'home_show_favourites';

  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsKey) ?? true;
  }

  Future<void> set(bool shown) async {
    state = AsyncValue<bool>.data(shown);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, shown);
  }
}
