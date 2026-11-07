// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

/// The pieces the music screens share: a square tile, a shelf of them, a track
/// row and the Play and Shuffle buttons.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/television.dart';
import '../../app/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../servers/media_library_source.dart';
import '../../widgets/focus_ring.dart';
import '../../widgets/gradient_art.dart';
import '../../widgets/poster_tile.dart';
import '../../widgets/remote_art.dart';
import '../servers/item_action_row.dart';
import '../servers/server_library.dart';
import '../servers/shelves.dart';

/// What an album or an artist shows when the server holds no picture.
IconData musicPlaceholderIcon(ServerItem item) =>
    item.kind == ServerItemKind.musicArtist
    ? Icons.person_rounded
    : Icons.album_rounded;

/// An album or an artist as a square tile.
///
/// A [PosterTile] given a square to fill: album art is 1:1, and in a film's
/// 108x142 box it would lose its sides.
class MusicTile extends ConsumerWidget {
  const MusicTile({
    super.key,
    required this.item,
    required this.side,
    this.caption,
    this.artWidth = 300,
    this.onTap,
  });

  final ServerItem item;
  final double side;

  /// The line under the title. Null reserves none.
  final String? caption;

  /// How wide a picture to ask the server for.
  final int artWidth;

  /// Null opens the item. A row of songs plays instead.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PosterTile(
      item: libraryItemFrom(item),
      artUrl: artUrlFor(ref, item, maxWidth: artWidth),
      width: side,
      posterHeight: side,
      caption: caption,
      placeholderIcon: musicPlaceholderIcon(item),
      onTap: onTap ?? () => openServerItem(context, item),
    );
  }
}

/// A row of square tiles under a heading, or nothing at all.
///
/// The heading is drawn here because it goes with the row: a title over blank
/// space reads as a shelf that failed to load.
class MusicShelf extends ConsumerWidget {
  const MusicShelf({
    super.key,
    required this.items,
    this.title,
    this.captionOf,
    this.onTap,
  });

  /// Null where the caller draws its own heading.
  final String? title;
  final List<ServerItem> items;

  /// What tapping the tile at an index does. Null opens the item.
  final void Function(int index)? onTap;

  /// The line under each tile's title. Null reserves none.
  final String? Function(ServerItem item)? captionOf;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) return const SizedBox.shrink();

    final spacing = context.spacing;
    final television = ref.watch(isTelevisionProvider);
    final caption = captionOf;
    final heading = title;
    final tap = onTap;

    return Padding(
      padding: EdgeInsets.only(top: heading == null ? 0 : spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (heading != null) ...<Widget>[
            Padding(
              padding: spacing.screenPadding(context.windowSize),
              child: Text(heading, style: context.texts.titleMedium),
            ),
            SizedBox(height: spacing.sm),
          ],
          LayoutBuilder(
            builder: (context, constraints) {
              final m = ShelfMetrics.of(
                context,
                width: constraints.maxWidth,
                television: television,
              );
              final side = m.posterWidth;

              return ShelfRow(
                height:
                    PosterTile.outerHeight(
                      context,
                      side,
                      withCaption: caption != null,
                    ) +
                    m.focusRoom * 2,
                focusRoom: m.focusRoom,
                itemCount: items.length,
                itemBuilder: (context, i) => FocusRing(
                  radius: context.radii.chip + spacing.hitInset,
                  child: MusicTile(
                    item: items[i],
                    side: side,
                    // An empty string rather than null, so a tile without the
                    // fact stays as tall as its neighbours.
                    caption: caption == null ? null : caption(items[i]) ?? '',
                    artWidth: 400,
                    onTap: tap == null ? null : () => tap(i),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// One track in a list: its number or its cover, its title and artist, its
/// length and its menu.
class TrackRow extends ConsumerWidget {
  const TrackRow({
    super.key,
    required this.track,
    required this.onTap,
    this.showArt = false,
    this.subtitle,
  });

  final ServerItem track;
  final VoidCallback onTap;

  /// The cover instead of the track number: a list of songs from all over has
  /// no running order for the number to mean anything in.
  final bool showArt;

  /// The line under the title. Null draws none, which on an album is most
  /// tracks: the artist is already in the header.
  final String? subtitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = context.spacing;
    final scheme = context.colors;
    final runtime = track.runtime;
    final number = track.trackNumber;
    final line = subtitle;

    return ListTile(
      contentPadding: EdgeInsetsDirectional.only(
        start: spacing.screenHorizontal(context.windowSize),
        // The menu's own ink supplies the rest of the gutter.
        end: spacing.xs,
      ),
      leading: showArt
          ? ClipRRect(
              borderRadius: BorderRadius.circular(context.radii.thumb),
              child: SizedBox.square(
                dimension: 48,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    GradientArt(seed: track.album ?? track.title),
                    RemoteArt(url: artUrlFor(ref, track, maxWidth: 144)),
                  ],
                ),
              ),
            )
          : SizedBox(
              width: 28,
              child: Center(
                widthFactor: 1,
                child: Text(
                  number == null ? '' : '$number',
                  style: context.texts.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
      title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: line == null
          ? null
          : Text(
              line,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (runtime != null)
            Text(
              trackDuration(runtime),
              style: context.texts.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ItemActionMenu(item: track),
        ],
      ),
      onTap: onTap,
    );
  }
}

/// Play and Shuffle, pinned to the foot of a music screen on a phone.
///
/// [ItemPrimaryActionBar]'s reason, one-handed reach, with [ItemPrimaryActionBar]'s
/// second button swapped: nothing resumes on a record, and it is shuffled far
/// more often than a film is started over.
class MusicPlayBar extends StatelessWidget {
  const MusicPlayBar({super.key, required this.onPlay, required this.onShuffle});

  /// Null while there is nothing to play yet.
  final VoidCallback? onPlay;
  final VoidCallback? onShuffle;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final l10n = AppLocalizations.of(context);

    return Material(
      color: context.colors.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.all(spacing.md).copyWith(
            left: spacing.lg,
            right: spacing.lg,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          context.radii.action,
                        ),
                      ),
                    ),
                    onPressed: onPlay,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(l10n.play),
                  ),
                ),
              ),
              SizedBox(width: spacing.md),
              SizedBox.square(
                dimension: 52,
                child: IconButton.filledTonal(
                  tooltip: l10n.shufflePlay,
                  onPressed: onShuffle,
                  icon: const Icon(Icons.shuffle_rounded),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The same two buttons in line, for a window nothing holds in one hand.
class MusicPlayButtons extends StatelessWidget {
  const MusicPlayButtons({
    super.key,
    required this.onPlay,
    required this.onShuffle,
  });

  final VoidCallback? onPlay;
  final VoidCallback? onShuffle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        FilledButton.icon(
          onPressed: onPlay,
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text(l10n.play),
        ),
        SizedBox(width: context.spacing.sm),
        IconButton(
          tooltip: l10n.shufflePlay,
          onPressed: onShuffle,
          icon: const Icon(Icons.shuffle_rounded),
        ),
      ],
    );
  }
}

/// A centred sentence where a list would be.
class MusicNote extends StatelessWidget {
  const MusicNote({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(context.spacing.xl),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: context.texts.bodyMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
