// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../servers/media_library_source.dart';
import 'item_actions.dart';

/// The primary button plus the row of things that can be done to an item.
///
/// Shared between the series and the episode screens because the list is the
/// same one in both places, and two copies would drift: the series version
/// grew "download all" and the episode version "media info", and everything
/// else — watch state, favourites, shuffle, playlists — is identical.
class ItemActionRow extends ConsumerWidget {
  const ItemActionRow({
    super.key,
    required this.item,
    required this.onPlay,
    this.onStartOver,
    this.shuffleFrom = const <ServerItem>[],
    this.playlistIds = const <String>[],
    this.seriesId,
    this.downloadsAll = false,
    this.onMediaInfo,
  });

  final ServerItem item;

  /// Resume where the server says the user got to.
  final VoidCallback onPlay;

  /// Play from the beginning. Null hides it — there is nothing to start over
  /// when nothing was started.
  final VoidCallback? onStartOver;

  /// What "shuffle" draws from: a series' episodes, or a season's.
  final List<ServerItem> shuffleFrom;

  /// What a playlist action operates on. A series adds all its episodes; an
  /// episode adds itself.
  final List<String> playlistIds;

  /// Which series' episode lists to refresh after a watch-state change.
  final String? seriesId;

  /// Labels the download action "Download all" rather than "Download".
  final bool downloadsAll;

  /// Opens the stream list. Null on screens that have no such panel.
  final VoidCallback? onMediaInfo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = context.spacing;
    final radii = context.radii;
    final l10n = AppLocalizations.of(context);

    final started = (item.position ?? Duration.zero) > Duration.zero;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: SizedBox(
                height: 52,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(radii.action),
                    ),
                  ),
                  onPressed: onPlay,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(
                    started ? l10n.continueWatching : l10n.play,
                  ),
                ),
              ),
            ),
            if (started && onStartOver != null) ...<Widget>[
              SizedBox(width: spacing.md),
              _Square(
                icon: Icons.replay_rounded,
                tooltip: l10n.startOver,
                onPressed: onStartOver!,
              ),
            ],
          ],
        ),
        SizedBox(height: spacing.md),
        // One scrolling row rather than a wrap: the list grows by one every
        // time a feature lands, and a wrap turns that into a second row of
        // buttons pushing the description off the screen.
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: <Widget>[
              _Action(
                icon: item.played
                    ? Icons.check_circle_rounded
                    : Icons.check_circle_outline_rounded,
                label: item.played ? l10n.markUnwatched : l10n.markWatched,
                selected: item.played,
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final ok = await setWatched(
                    ref,
                    item.id,
                    watched: !item.played,
                    seriesId: seriesId,
                  );
                  if (!ok) {
                    messenger.showSnackBar(
                      SnackBar(content: Text(l10n.actionFailed)),
                    );
                  }
                },
              ),
              SizedBox(width: spacing.sm),
              _Action(
                icon: item.favourite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                label: item.favourite
                    ? l10n.removeFavourite
                    : l10n.addFavourite,
                selected: item.favourite,
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final ok = await setFavourite(
                    ref,
                    item.id,
                    favourite: !item.favourite,
                    seriesId: seriesId,
                  );
                  if (!ok) {
                    messenger.showSnackBar(
                      SnackBar(content: Text(l10n.actionFailed)),
                    );
                  }
                },
              ),
              if (shuffleFrom.isNotEmpty) ...<Widget>[
                SizedBox(width: spacing.sm),
                _Action(
                  icon: Icons.shuffle_rounded,
                  label: l10n.shufflePlay,
                  onPressed: () => shufflePlay(context, ref, shuffleFrom),
                ),
              ],
              if (playlistIds.isNotEmpty) ...<Widget>[
                SizedBox(width: spacing.sm),
                _Action(
                  icon: Icons.playlist_add_rounded,
                  label: l10n.addToPlaylist,
                  onPressed: () =>
                      showPlaylistSheet(context, ref, itemIds: playlistIds),
                ),
              ],
              if (onMediaInfo != null) ...<Widget>[
                SizedBox(width: spacing.sm),
                _Action(
                  icon: Icons.info_outline_rounded,
                  label: l10n.mediaInfo,
                  onPressed: onMediaInfo!,
                ),
              ],
              SizedBox(width: spacing.sm),
              _Action(
                icon: Icons.download_for_offline_outlined,
                label: downloadsAll ? l10n.downloadAll : l10n.download,
                // Offline copies are a whole subsystem — a store, a queue, a
                // resolver that keeps working when the server is gone — and
                // none of it exists yet. Shown and honest rather than hidden,
                // because the design's screen for it already exists.
                onPressed: () => reportFailure(
                  context,
                  l10n.notImplemented(l10n.download),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return ActionChip(
      avatar: Icon(
        icon,
        size: 18,
        color: selected ? scheme.onSecondaryContainer : scheme.onSurfaceVariant,
      ),
      label: Text(label),
      backgroundColor: selected ? scheme.secondaryContainer : null,
      onPressed: onPressed,
    );
  }
}

class _Square extends StatelessWidget {
  const _Square({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(context.radii.action),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: 52,
            height: 52,
            child: Icon(icon, color: scheme.onPrimaryContainer),
          ),
        ),
      ),
    );
  }
}
