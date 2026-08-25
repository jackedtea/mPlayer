// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/tokens.dart';
import '../../servers/media_library_source.dart';
import '../../widgets/poster_tile.dart';
import '../../widgets/remote_art.dart';
import 'server_library.dart';

/// Genres, as one horizontally scrolling row.
///
/// A `Wrap` was the obvious layout and the wrong one: wrapped at full chip
/// size these pushed the cast and the media info a screen and a half down.
/// One row that scrolls costs a fixed 34 points however many there are.
///
/// The server's keywords used to ride along here and no longer do. A series
/// carries dozens — "affectation", "co-workers relationship" — and none of
/// them answer the question a genre answers, so they only made "Comedy"
/// something to scroll for.
class TagStrip extends StatelessWidget {
  const TagStrip({
    super.key,
    required this.tags,
    this.padding = EdgeInsets.zero,
  });

  final List<String> tags;
  final EdgeInsetsGeometry padding;

  /// The row's height, which callers reserve.
  static const height = 34.0;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();

    final spacing = context.spacing;
    final scheme = context.colors;

    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        itemCount: tags.length,
        separatorBuilder: (_, _) => SizedBox(width: spacing.sm),
        itemBuilder: (context, i) => Container(
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(horizontal: spacing.md),
          decoration: BoxDecoration(
            border: Border.all(color: scheme.outlineVariant),
            borderRadius: BorderRadius.circular(TagStrip.height / 2),
          ),
          child: Text(
            tags[i],
            style: context.texts.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// The cast, with headshots where the server has them.
class PeopleStrip extends ConsumerWidget {
  const PeopleStrip({super.key, required this.people});

  final List<ServerPerson> people;

  static const height = 132.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (people.isEmpty) return const SizedBox.shrink();

    final spacing = context.spacing;
    final scheme = context.colors;
    final source = ref.watch(activeServerProvider);

    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: spacing.screenPadding(context.windowSize),
        itemCount: people.length,
        separatorBuilder: (_, _) => SizedBox(width: spacing.lg),
        itemBuilder: (context, i) {
          final person = people[i];
          final url = source?.personImageUrl(person, maxWidth: 160);

          return SizedBox(
            width: 76,
            child: Column(
              children: <Widget>[
                ClipOval(
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        // The initial stays underneath rather than being
                        // replaced: `RemoteArt` draws nothing while it loads
                        // and nothing when there is no headshot, so this is
                        // what the strip falls back to on both counts.
                        ColoredBox(
                          color: scheme.surfaceContainerHighest,
                          child: Center(
                            child: Text(
                              person.name.isEmpty
                                  ? '?'
                                  : person.name.characters.first,
                              style: TextStyle(
                                fontSize: 22,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                        RemoteArt(url: url),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: spacing.sm - 2),
                Text(
                  person.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: context.texts.labelSmall?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: scheme.onSurface,
                  ),
                ),
                if (person.role.isNotEmpty)
                  Text(
                    person.role,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: context.texts.labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// "More like this" — what the server thinks resembles [itemId].
///
/// Draws nothing at all when the server has no suggestions, rather than a
/// heading over an empty strip.
class SimilarStrip extends ConsumerWidget {
  const SimilarStrip({super.key, required this.itemId, required this.title});

  final String itemId;
  final String title;

  static const _posterHeight = 150.0;
  static const _posterWidth = 108.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = context.spacing;
    final items = ref.watch(similarItemsProvider(itemId)).value ??
        const <ServerItem>[];
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: spacing.screenPadding(context.windowSize),
          child: Text(title, style: context.texts.titleMedium),
        ),
        SizedBox(
          height: PosterTile.outerHeight(context, _posterHeight),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(
              horizontal:
                  (spacing.screenHorizontal(context.windowSize) -
                          spacing.hitInset)
                      .clamp(0.0, double.infinity),
            ),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final entry = items[i];
              return PosterTile(
                item: libraryItemFrom(entry),
                artUrl: artUrlFor(ref, entry, maxWidth: 300),
                width: _posterWidth,
                posterHeight: _posterHeight,
                onTap: () => context.push(
                  entry.kind == ServerItemKind.series
                      ? '/library/series'
                      : '/library/movie',
                  extra: entry.id,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
