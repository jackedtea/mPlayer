// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../servers/media_library_source.dart';
import '../../widgets/poster_tile.dart';
import 'library_view_settings.dart';
import 'server_library.dart';

/// Everything one person appears in.
///
/// Reached by tapping a face in the cast strip. Films and series only — an
/// actor credited on forty episodes of one show should read as that one show,
/// not as forty rows of it, and that filtering happens in the request rather
/// than here.
class PersonPage extends ConsumerWidget {
  const PersonPage({super.key, this.personId, this.name = ''});

  /// Null when the route was opened directly rather than from a face.
  final String? personId;

  /// The server does not need it and the app bar does.
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = context.spacing;
    final l10n = AppLocalizations.of(context);
    final id = personId;

    final request = id == null
        ? const AsyncValue<List<ServerItem>>.data(<ServerItem>[])
        : ref.watch(personItemsProvider(id));
    final items = request.value ?? const <ServerItem>[];

    final columns = columnsForWidth(
      ref.watch(libraryColumnsProvider),
      MediaQuery.sizeOf(context).width,
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: context.colors.surfaceContainerHigh,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(name.isEmpty ? l10n.cast : name),
      ),
      body: request.isLoading && items.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(spacing.xl),
                    child: Text(
                      l10n.nothingHere,
                      style: context.texts.bodyMedium?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        spacing.screenHorizontal(context.windowSize),
                        spacing.md,
                        spacing.screenHorizontal(context.windowSize),
                        spacing.sm,
                      ),
                      child: Text(
                        l10n.itemCount(items.length),
                        style: context.texts.bodySmall?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final gutter =
                              (spacing.screenHorizontal(context.windowSize) -
                                      spacing.hitInset)
                                  .clamp(0.0, double.infinity);
                          final cell =
                              (constraints.maxWidth - gutter * 2) / columns;
                          final posterWidth =
                              (cell - spacing.hitInset * 2).clamp(48.0, 400.0);
                          final posterHeight = posterWidth * 142 / 108;

                          return GridView.builder(
                            padding: EdgeInsets.fromLTRB(
                              gutter,
                              0,
                              gutter,
                              spacing.md,
                            ),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: columns,
                              mainAxisSpacing: spacing.sm,
                              crossAxisSpacing: 0,
                              mainAxisExtent:
                                  PosterTile.outerHeight(context, posterHeight),
                            ),
                            itemCount: items.length,
                            itemBuilder: (context, i) {
                              final entry = items[i];
                              return PosterTile(
                                item: libraryItemFrom(entry),
                                artUrl: artUrlFor(ref, entry, maxWidth: 300),
                                width: posterWidth,
                                posterHeight: posterHeight,
                                onTap: () => context.push(
                                  entry.kind == ServerItemKind.series
                                      ? '/library/series'
                                      : '/library/movie',
                                  extra: entry.id,
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}
