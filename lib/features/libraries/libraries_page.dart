// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/tokens.dart';
import '../../core/models/library_models.dart';
import '../../l10n/app_localizations.dart';
import '../../servers/media_library_source.dart';
import '../../widgets/no_server_note.dart';
import '../servers/server_library.dart';

/// The Libraries tab — every library on the server, one tile each.
///
/// A tile opens the library *inside this tab*, so the navigation bar stays
/// under its Browse, Suggestions, Collections and Playlists tabs.
class LibrariesPage extends ConsumerWidget {
  const LibrariesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.libraries)),
      body: ref.watch(connectedServerProvider) == null
          ? const NoServerNote()
          : const _LibraryGrid(),
    );
  }
}

class _LibraryGrid extends ConsumerWidget {
  const _LibraryGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = context.spacing;
    final scheme = context.colors;
    final request = ref.watch(serverViewsProvider);
    final views = request.value ?? const <LibraryView>[];

    if (views.isEmpty) {
      if (request.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      return Center(
        child: Text(
          AppLocalizations.of(context).noResults,
          style: context.texts.bodyMedium
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(serverViewsProvider);
        ref.invalidate(libraryItemCountProvider);
        await ref.read(serverViewsProvider.future);
      },
      child: GridView.builder(
        padding: EdgeInsets.fromLTRB(
          spacing.screenHorizontal(context.windowSize),
          spacing.sm,
          spacing.screenHorizontal(context.windowSize),
          spacing.xl,
        ),
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 360,
          mainAxisExtent: 76,
          mainAxisSpacing: spacing.md,
          crossAxisSpacing: spacing.md,
        ),
        itemCount: views.length,
        itemBuilder: (context, i) => _LibraryTile(view: views[i]),
      ),
    );
  }
}

class _LibraryTile extends ConsumerWidget {
  const _LibraryTile({required this.view});

  final LibraryView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = context.spacing;
    final scheme = context.colors;
    // A request of its own per library, so the tiles draw immediately and the
    // counts fill in behind them.
    final count = ref.watch(libraryItemCountProvider(view.id)).value;
    final LibrarySection section = librarySectionFrom(view, itemCount: count);

    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: context.radii.cardAll,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/libraries/view', extra: view.id),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing.lg),
          child: Row(
            children: <Widget>[
              Icon(section.icon, color: scheme.primary),
              SizedBox(width: spacing.md),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      section.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.texts.bodyLarge,
                    ),
                    // Nothing at all until the count is known: a library
                    // labelled "0 items" while its tally is in flight reads
                    // as an empty library.
                    if (count != null)
                      Text(
                        AppLocalizations.of(context)
                            .itemCount(section.itemCount),
                        style: context.texts.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}
