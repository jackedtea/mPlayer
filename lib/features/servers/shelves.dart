// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

/// The two horizontal rows every server screen is built out of.
///
/// Extracted when the library screen grew a Suggestions tab: the server home
/// (1d) and that tab draw exactly the same shelves from different queries, and
/// two copies of the ink-inset arithmetic below is two places to get it wrong.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../servers/media_library_source.dart';
import '../../servers/server_registry.dart';
import '../../widgets/continue_watching_card.dart';
import '../../widgets/poster_tile.dart';
import 'server_library.dart';

/// A row of resume cards, or nothing at all.
///
/// An empty shelf renders as zero height rather than as an empty state: two
/// "nothing here" panels stacked above each other on a fresh server is worse
/// than a screen that simply starts at the next section. A shelf that has not
/// *arrived* yet is a different thing and shows a spinner — over a slow
/// connection that is what the user is actually looking at.
class ServerCardShelf extends ConsumerWidget {
  const ServerCardShelf({super.key, required this.items});

  final AsyncValue<List<ServerItem>> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = context.spacing;
    final inset = spacing.hitInset;
    final side = (spacing.screenHorizontal(context.windowSize) - inset)
        .clamp(0.0, double.infinity);
    final gap = (spacing.cardGap - inset * 2).clamp(0.0, double.infinity);

    final resolved = items.value ?? const <ServerItem>[];
    if (resolved.isEmpty) {
      return items.isLoading
          ? SizedBox(
              height: ContinueWatchingCard.outerHeight(context),
              child: const Center(child: CircularProgressIndicator()),
            )
          : const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context);
    final serverName = ref.watch(serverRegistryProvider).active?.name ?? '';

    return SizedBox(
      height: ContinueWatchingCard.outerHeight(context),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: side),
        itemCount: resolved.length,
        separatorBuilder: (_, _) => SizedBox(width: gap),
        itemBuilder: (context, i) => ContinueWatchingCard(
          item: resumeItemFrom(resolved[i], l10n, serverLabel: serverName),
          artUrl: artUrlFor(ref, resolved[i], maxWidth: 400),
          // The card opens the item; the glyph in the middle of it resumes.
          // These shelves exist to carry on watching, so the play button has
          // to be the short way there rather than a third tap into it.
          onTap: () => openServerItem(context, resolved[i]),
          onPlay: () => playServerItem(context, ref, resolved[i].id),
        ),
      ),
    );
  }
}

/// A row of posters — recently added, or a shelf of suggestions.
class ServerPosterShelf extends ConsumerWidget {
  const ServerPosterShelf({super.key, required this.items});

  final AsyncValue<List<ServerItem>> items;

  static const posterWidth = 104.0;
  static const posterHeight = 156.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = context.spacing;
    final inset = spacing.hitInset;
    final side = (spacing.screenHorizontal(context.windowSize) - inset)
        .clamp(0.0, double.infinity);
    final gap = (spacing.cardGap - inset * 2).clamp(0.0, double.infinity);

    final resolved = items.value ?? const <ServerItem>[];
    if (resolved.isEmpty) {
      if (!items.isLoading) return const SizedBox.shrink();
      return SizedBox(
        height: PosterTile.outerHeight(context, posterHeight),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return SizedBox(
      height: PosterTile.outerHeight(context, posterHeight),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: side),
        itemCount: resolved.length,
        separatorBuilder: (_, _) => SizedBox(width: gap),
        itemBuilder: (context, i) => PosterTile(
          item: libraryItemFrom(resolved[i]),
          artUrl: artUrlFor(ref, resolved[i], maxWidth: 300),
          width: posterWidth,
          posterHeight: posterHeight,
          onTap: () => openServerItem(context, resolved[i]),
        ),
      ),
    );
  }
}
