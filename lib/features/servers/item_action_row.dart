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
/// same one in both places. The choices themselves come from
/// [itemActionsFor], which the episode row's menu renders too — this widget
/// only decides that they are drawn as chips.
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
  final Future<void> Function()? onMediaInfo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = context.spacing;
    final radii = context.radii;
    final l10n = AppLocalizations.of(context);

    final started = (item.position ?? Duration.zero) > Duration.zero;
    final actions = itemActionsFor(
      context,
      ref,
      item: item,
      seriesId: seriesId,
      shuffleFrom: shuffleFrom,
      playlistIds: playlistIds,
      downloadsAll: downloadsAll,
      onMediaInfo: onMediaInfo,
    );

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
                  label: Text(started ? l10n.continueWatching : l10n.play),
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
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: actions.length,
            separatorBuilder: (_, _) => SizedBox(width: spacing.sm),
            itemBuilder: (context, i) {
              final action = actions[i];
              return _Chip(action: action);
            },
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.action});

  final ItemAction action;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return ActionChip(
      avatar: Icon(
        action.icon,
        size: 18,
        color: action.selected
            ? scheme.onSecondaryContainer
            : scheme.onSurfaceVariant,
      ),
      label: Text(action.label),
      backgroundColor: action.selected ? scheme.secondaryContainer : null,
      onPressed: () => action.onSelected(),
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

/// The same choices as [ItemActionRow], as an overflow menu.
///
/// What an episode row has room for: a list of rows cannot each carry six
/// chips, and the row already spends its width on a still, a title and a
/// description.
class ItemActionMenu extends ConsumerWidget {
  const ItemActionMenu({
    super.key,
    required this.item,
    this.seriesId,
    this.shuffleFrom = const <ServerItem>[],
    this.onMediaInfo,
  });

  final ServerItem item;
  final String? seriesId;
  final List<ServerItem> shuffleFrom;
  final Future<void> Function()? onMediaInfo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = itemActionsFor(
      context,
      ref,
      item: item,
      seriesId: seriesId,
      shuffleFrom: shuffleFrom,
      playlistIds: <String>[item.id],
      onMediaInfo: onMediaInfo,
    );

    return PopupMenuButton<int>(
      icon: const Icon(Icons.more_vert_rounded),
      tooltip: MaterialLocalizations.of(context).showMenuTooltip,
      onSelected: (i) => actions[i].onSelected(),
      itemBuilder: (context) => <PopupMenuEntry<int>>[
        for (final (int i, ItemAction action) in actions.indexed)
          PopupMenuItem<int>(
            value: i,
            child: Row(
              children: <Widget>[
                Icon(action.icon, size: 20),
                SizedBox(width: context.spacing.md),
                Expanded(child: Text(action.label)),
              ],
            ),
          ),
      ],
    );
  }
}
