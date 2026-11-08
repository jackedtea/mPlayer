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
import 'series_page.dart' show nextEpisodeOf;
import 'server_library.dart';

/// Whether [kind] is a container that plays through its contents: a series
/// its episodes, a collection or folder whatever it holds.
bool _isContainer(ServerItemKind kind) =>
    kind == ServerItemKind.series ||
    kind == ServerItemKind.season ||
    kind.isBrowsable;

bool _isPlayable(ServerItemKind kind) =>
    kind == ServerItemKind.movie ||
    kind == ServerItemKind.episode ||
    kind == ServerItemKind.video ||
    kind == ServerItemKind.audio;

/// The things [items] play, in order: a film as itself, a series as its
/// episodes, a collection or folder as the playable items directly in it.
///
/// A series inside a collection is left out rather than expanded: a box set
/// of films is what collections hold, and fetching every episode of every
/// series in one is a long wait for a queue nobody meant to build.
Future<List<ServerItem>> playableContents(
  WidgetRef ref,
  List<ServerItem> items,
) async {
  final source = ref.read(activeServerProvider);
  if (source == null) return const <ServerItem>[];

  final out = <ServerItem>[];
  for (final ServerItem item in items) {
    if (_isPlayable(item.kind)) {
      out.add(item);
    } else if (item.kind == ServerItemKind.series) {
      out.addAll(await source.episodes(item.id));
    } else if (_isContainer(item.kind)) {
      final children = await source.items(item.id, limit: 1000);
      out.addAll(children.where((c) => _isPlayable(c.kind)));
    }
  }
  return out;
}

/// Plays [items] — one tile from the menu, or a whole selection.
///
/// A single series plays on from where the viewer is, the way its own Play
/// button does, rather than from its first episode.
Future<void> playLibraryItems(
  BuildContext context,
  WidgetRef ref,
  List<ServerItem> items, {
  bool shuffle = false,
}) async {
  final l10n = AppLocalizations.of(context);
  final List<ServerItem> playable;
  try {
    playable = await playableContents(ref, items);
  } on ServerException catch (e) {
    if (context.mounted) reportFailure(context, e.message);
    return;
  }
  if (!context.mounted) return;
  if (playable.isEmpty) {
    reportFailure(context, l10n.nothingToPlay);
    return;
  }

  if (shuffle) {
    await shufflePlay(context, ref, playable);
  } else if (items.length == 1 && items.single.kind == ServerItemKind.series) {
    final next = nextEpisodeOf(playable);
    if (next != null) await playServerItem(context, ref, next.id);
  } else if (playable.length == 1) {
    await playServerItem(context, ref, playable.single.id);
  } else {
    await playServerQueue(context, ref, <String>[
      for (final ServerItem p in playable) p.id,
    ]);
  }
}

/// Whether an item can be put in a collection or a playlist at all. A box
/// set inside a box set is not something either client offers.
bool canCollect(ServerItem item) => !item.kind.isBrowsable;

/// The menu a long press (or a right click) opens on a library tile:
/// Play, Shuffle, then Select, Add to collection, Add to playlist.
///
/// [position] is the global point pressed, where the menu opens. [onSelect]
/// starts the grid's multi-select with this item in it; null leaves Select
/// out.
Future<void> showLibraryItemMenu(
  BuildContext context,
  WidgetRef ref,
  ServerItem item, {
  required Offset position,
  VoidCallback? onSelect,
}) async {
  final l10n = AppLocalizations.of(context);

  final playable = _isPlayable(item.kind) || _isContainer(item.kind);
  final shuffleable = _isContainer(item.kind);
  final collectable = canCollect(item);

  final entries = <_Entry>[
    if (playable)
      (
        Icons.play_arrow_rounded,
        l10n.play,
        () => playLibraryItems(context, ref, <ServerItem>[item]),
      ),
    if (shuffleable)
      (
        Icons.shuffle_rounded,
        l10n.shuffleItems,
        () => playLibraryItems(context, ref, <ServerItem>[item], shuffle: true),
      ),
    if (playable && (onSelect != null || collectable)) null,
    if (onSelect != null)
      (Icons.library_add_check_outlined, l10n.selectItems, onSelect),
    if (collectable) ...<(IconData, String, VoidCallback)>[
      (
        Icons.playlist_add_rounded,
        l10n.addToCollection,
        () => showCollectionSheet(context, ref, itemIds: <String>[item.id]),
      ),
      (
        Icons.playlist_add_rounded,
        l10n.addToPlaylist,
        () => showPlaylistSheet(context, ref, itemIds: <String>[item.id]),
      ),
    ],
  ];
  await _showEntries(context, position, entries);
}

/// One menu row: its glyph, its label and what it does. Null is a divider.
typedef _Entry = (IconData, String, VoidCallback)?;

/// Opens [entries] as a popup menu at the global [position].
Future<void> _showEntries(
  BuildContext context,
  Offset position,
  List<_Entry> entries,
) async {
  if (entries.isEmpty) return;
  final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;

  final chosen = await showMenu<int>(
    context: context,
    position: RelativeRect.fromRect(
      position & const Size(1, 1),
      Offset.zero & overlay.size,
    ),
    items: <PopupMenuEntry<int>>[
      for (final (int i, _Entry e) in entries.indexed)
        if (e == null)
          const PopupMenuDivider()
        else
          PopupMenuItem<int>(
            value: i,
            child: Row(
              children: <Widget>[
                Icon(e.$1, size: 20),
                SizedBox(width: context.spacing.md),
                Expanded(child: Text(e.$2)),
              ],
            ),
          ),
    ],
  );
  if (chosen == null) return;
  entries[chosen]?.$3();
}

/// The menu a long press (or a right click) on a season tab opens.
///
/// [seasons] is every season's episodes in tab order and [index] the one
/// pressed. Play carries on inside the season — the part-watched episode,
/// else the first unwatched — and the queue stops at its end; "Play all from
/// here" runs on through every season after it. Everything else acts on the
/// season's episodes: a playlist holds episodes, a collection the season
/// itself where the server named it.
Future<void> showSeasonMenu(
  BuildContext context,
  WidgetRef ref, {
  required Offset position,
  required List<List<ServerItem>> seasons,
  required int index,
  VoidCallback? onSelect,
}) async {
  if (index >= seasons.length || seasons[index].isEmpty) return;
  final l10n = AppLocalizations.of(context);
  final season = seasons[index];
  final ids = <String>[for (final ServerItem e in season) e.id];
  final seasonId = season.first.seasonId;

  void play() {
    final next = nextEpisodeOf(season);
    playServerQueue(
      context,
      ref,
      ids,
      startIndex: next == null ? 0 : season.indexOf(next),
    );
  }

  void playOn() => playServerQueue(context, ref, <String>[
    for (final List<ServerItem> s in seasons.skip(index))
      for (final ServerItem e in s) e.id,
  ]);

  await _showEntries(context, position, <_Entry>[
    (Icons.play_arrow_rounded, l10n.play, play),
    if (index < seasons.length - 1)
      (Icons.playlist_play_rounded, l10n.playAllFromHere, playOn),
    (
      Icons.shuffle_rounded,
      l10n.shuffleItems,
      () => shufflePlay(context, ref, season),
    ),
    null,
    if (onSelect != null)
      (Icons.library_add_check_outlined, l10n.selectItems, onSelect),
    (
      Icons.library_add_outlined,
      l10n.addToCollection,
      () => showCollectionSheet(
        context,
        ref,
        itemIds: seasonId == null ? ids : <String>[seasonId],
      ),
    ),
    (
      Icons.playlist_add_rounded,
      l10n.addToPlaylist,
      () => showPlaylistSheet(context, ref, itemIds: ids),
    ),
    (
      Icons.download_for_offline_outlined,
      l10n.downloadAll,
      () => downloadAllAction(context, ref, season).onSelected(),
    ),
  ]);
}

/// The collections on the server, for the sheet behind "Add to collection".
final allCollectionsProvider = FutureProvider.autoDispose<List<ServerItem>>((
  ref,
) async {
  final source = ref.watch(activeServerProvider);
  if (source == null) return const <ServerItem>[];
  return source.allCollections();
});

/// The sheet behind "Add to collection": every collection on the server and
/// "New collection" under them. Picking one adds [itemIds] and closes.
Future<void> showCollectionSheet(
  BuildContext context,
  WidgetRef ref, {
  required List<String> itemIds,
}) async {
  if (itemIds.isEmpty) return;

  await showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (sheetContext) => _CollectionSheet(itemIds: itemIds),
  );
}

class _CollectionSheet extends ConsumerWidget {
  const _CollectionSheet({required this.itemIds});

  final List<String> itemIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = context.spacing;
    final l10n = AppLocalizations.of(context);
    final request = ref.watch(allCollectionsProvider);
    final collections = request.value ?? const <ServerItem>[];

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.fromLTRB(
              spacing.lg,
              spacing.lg,
              spacing.lg,
              spacing.sm,
            ),
            child: Text(l10n.addToCollection, style: context.texts.titleMedium),
          ),
          if (request.isLoading && collections.isEmpty)
            Padding(
              padding: EdgeInsets.all(spacing.xl),
              child: const Center(child: CircularProgressIndicator()),
            )
          else
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: <Widget>[
                  for (final ServerItem c in collections)
                    ListTile(
                      leading: const Icon(Icons.collections_bookmark_outlined),
                      title: Text(c.title),
                      onTap: () => _add(context, ref, c),
                    ),
                ],
              ),
            ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.add_rounded),
            title: Text(l10n.newCollection),
            onTap: () => _create(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _add(
    BuildContext context,
    WidgetRef ref,
    ServerItem collection,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final source = ref.read(activeServerProvider);
    if (source == null) return;

    try {
      await source.addToCollection(collection.id, itemIds);
    } on ServerException catch (e) {
      // Most likely an account without permission to manage collections;
      // the sentence says so, and the sheet stays for another choice.
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }
    _invalidate(ref);
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.addedToCollection(collection.title))),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final controller = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.newCollection),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: l10n.playlistName),
          onSubmitted: (v) => Navigator.of(dialogContext).pop(v.trim()),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: Text(l10n.create),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;

    final source = ref.read(activeServerProvider);
    if (source == null) return;

    try {
      await source.createCollection(name, itemIds);
    } on ServerException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }
    _invalidate(ref);
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.addedToCollection(name))),
    );
  }

  /// A collection gained members, or came into being: the lists that show
  /// collections ask again.
  void _invalidate(WidgetRef ref) {
    ref.invalidate(allCollectionsProvider);
    ref.invalidate(libraryCollectionsProvider);
  }
}

/// What can be done to the whole selection, at the foot of the screen where
/// a thumb already is. Shared by the library grid and the episode list.
class SelectionBar extends StatelessWidget {
  const SelectionBar({
    super.key,
    required this.count,
    required this.onClear,
    required this.onSelectAll,
    required this.onPlay,
    required this.onShuffle,
    required this.onAddToCollection,
    required this.onAddToPlaylist,
    this.onDownload,
  });

  final int count;
  final VoidCallback onClear;
  final VoidCallback onSelectAll;
  final VoidCallback onPlay;
  final VoidCallback onShuffle;
  final VoidCallback onAddToCollection;
  final VoidCallback onAddToPlaylist;

  /// Download all of them; null leaves the button out.
  final VoidCallback? onDownload;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;

    return Material(
      color: context.colors.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing.xs),
          child: Row(
            children: <Widget>[
              IconButton(
                tooltip: l10n.clearSelection,
                icon: const Icon(Icons.close_rounded),
                onPressed: onClear,
              ),
              Text(
                l10n.selectedCount(count),
                maxLines: 1,
                style: context.texts.titleSmall,
              ),
              SizedBox(width: spacing.sm),
              // Up to seven glyphs do not fit a narrow phone beside the
              // count, so they scroll — right-aligned while they fit.
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  reverse: true,
                  child: Row(
                    children: <Widget>[
                      IconButton(
                        tooltip: l10n.selectAll,
                        icon: const Icon(Icons.select_all_rounded),
                        onPressed: onSelectAll,
                      ),
                      IconButton(
                        tooltip: l10n.play,
                        icon: const Icon(Icons.play_arrow_rounded),
                        onPressed: onPlay,
                      ),
                      IconButton(
                        tooltip: l10n.shuffleItems,
                        icon: const Icon(Icons.shuffle_rounded),
                        onPressed: onShuffle,
                      ),
                      IconButton(
                        tooltip: l10n.addToCollection,
                        icon: const Icon(Icons.library_add_outlined),
                        onPressed: onAddToCollection,
                      ),
                      IconButton(
                        tooltip: l10n.addToPlaylist,
                        icon: const Icon(Icons.playlist_add_rounded),
                        onPressed: onAddToPlaylist,
                      ),
                      if (onDownload != null)
                        IconButton(
                          tooltip: l10n.downloadAll,
                          icon: const Icon(Icons.download_for_offline_outlined),
                          onPressed: onDownload,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
