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
///
/// On a phone the detail screens pass `primary: false` and put Play in an
/// [ItemPrimaryActionBar] pinned to the bottom of the scaffold instead. The
/// reason is reach: this row sits under a 268dp backdrop, so on a tall phone
/// the one button the screen exists for lands in the middle of the display
/// and scrolls away entirely once the user reads the overview.
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
    this.primary = true,
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

  /// Whether to draw the Play button and Start-over beside it.
  ///
  /// False leaves only the chip strip, because an [ItemPrimaryActionBar] at
  /// the foot of the screen is carrying the primary action. [onPlay] is still
  /// required either way — the widget stays one thing to construct, and a
  /// caller that passes `primary: false` without a bar to go with it has a
  /// screen with no way to play, which is louder than a null check.
  final bool primary;

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
        if (primary) ...<Widget>[
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
        ],
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

/// The same actions as [ItemActionRow], drawn as one centred row of glyphs.
///
/// What the series header uses. A full-width filled button and a scrolling
/// strip of labelled chips is the right shape under a wide backdrop with the
/// title on it; under a poster with the title beside it there is no full
/// width to fill, and the row reads as a toolbar for the thing above it.
///
/// Everything past [visible] goes into the overflow menu rather than off the
/// edge, so the row stays the same width whatever the server supports.
class ItemActionIcons extends ConsumerWidget {
  const ItemActionIcons({
    super.key,
    required this.item,
    required this.onPlay,
    this.shuffleFrom = const <ServerItem>[],
    this.playlistIds = const <String>[],
    this.seriesId,
    this.downloadsAll = false,
    this.onMediaInfo,
    this.visible = 4,
    this.primary = true,
  });

  final ServerItem item;

  /// Resume where the server says the user got to.
  final VoidCallback onPlay;

  final List<ServerItem> shuffleFrom;
  final List<String> playlistIds;
  final String? seriesId;
  final bool downloadsAll;
  final Future<void> Function()? onMediaInfo;

  /// How many actions are drawn as glyphs before the overflow menu.
  final int visible;

  /// Whether the Play glyph leads the row. False on a phone, where an
  /// [ItemPrimaryActionBar] carries it at the foot of the screen instead.
  final bool primary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = context.spacing;
    final scheme = context.colors;
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

    final shown = actions.take(visible).toList();
    final rest = actions.skip(visible).toList();

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: spacing.sm,
      runSpacing: spacing.xs,
      children: <Widget>[
        // Play carries no label here, so it carries the tooltip instead: the
        // difference between starting a series and resuming one is the only
        // thing the row cannot say in a glyph.
        if (primary)
          IconButton(
            icon: const Icon(Icons.play_arrow_rounded),
            iconSize: 30,
            color: scheme.onSurface,
            tooltip: started ? l10n.continueWatching : l10n.play,
            onPressed: onPlay,
          ),
        for (final ItemAction action in shown)
          IconButton(
            icon: Icon(action.icon),
            iconSize: 26,
            color: action.selected ? scheme.primary : scheme.onSurface,
            tooltip: action.label,
            onPressed: () => action.onSelected(),
          ),
        if (rest.isNotEmpty)
          PopupMenuButton<int>(
            icon: const Icon(Icons.more_vert_rounded),
            iconSize: 26,
            color: scheme.surfaceContainerHigh,
            tooltip: MaterialLocalizations.of(context).showMenuTooltip,
            onSelected: (i) => rest[i].onSelected(),
            itemBuilder: (context) => <PopupMenuEntry<int>>[
              for (final (int i, ItemAction action) in rest.indexed)
                PopupMenuItem<int>(
                  value: i,
                  child: Row(
                    children: <Widget>[
                      Icon(action.icon, size: 20),
                      SizedBox(width: spacing.md),
                      Expanded(child: Text(action.label)),
                    ],
                  ),
                ),
            ],
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

/// The primary action, pinned to the foot of a detail screen.
///
/// **This exists for one-handed use.** The detail screens lead with a 268dp
/// backdrop, so the Play button in [ItemActionRow] lands near the middle of a
/// tall phone and leaves the screen as soon as the user scrolls into the
/// overview or the cast list. A bar in the scaffold's `bottomNavigationBar`
/// slot is in the thumb's arc and stays there whatever the list is doing.
///
/// Only the primary action is here, never the chips: those are still inline,
/// and duplicating them would put the same button in two places on one
/// screen. The chips are also the ones a user presses once a month, which is
/// exactly what a reach is affordable for.
class ItemPrimaryActionBar extends StatelessWidget {
  const ItemPrimaryActionBar({
    super.key,
    required this.item,
    required this.onPlay,
    this.onStartOver,
    this.caption,
  });

  final ServerItem item;

  /// Resume where the server says the user got to.
  final VoidCallback onPlay;

  /// A second line on the button saying what it will play — the episode a
  /// series resolves to, which the button alone cannot say. Null for one
  /// line.
  final String? caption;

  /// Play from the beginning. Null hides it.
  final VoidCallback? onStartOver;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final radii = context.radii;
    final scheme = context.colors;
    final l10n = AppLocalizations.of(context);

    final started = (item.position ?? Duration.zero) > Duration.zero;

    return Material(
      // A surface of its own, so the bar reads as chrome rather than as the
      // last row of the list scrolling under it.
      color: scheme.surfaceContainer,
      child: SafeArea(
        // The scaffold's own inset handles the top; this is the bottom edge,
        // where the navigation bar or the gesture pill is.
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            spacing.lg,
            spacing.md,
            spacing.lg,
            spacing.md,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: SizedBox(
                  height: caption == null ? 52 : 56,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(radii.action),
                      ),
                    ),
                    onPressed: onPlay,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: caption == null
                        ? Text(started ? l10n.continueWatching : l10n.play)
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(started ? l10n.continueWatching : l10n.play),
                              Text(
                                caption!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.texts.labelSmall?.copyWith(
                                  color: scheme.onPrimary.withValues(
                                    alpha: 0.85,
                                  ),
                                ),
                              ),
                            ],
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
        ),
      ),
    );
  }
}
