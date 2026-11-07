// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:math' show Random;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../servers/media_library_source.dart';
import '../../downloads/download_models.dart';
import '../../downloads/downloads_controller.dart';
import '../downloads/download_ui.dart';
import '../music/music_actions.dart';
import 'server_library.dart';

/// The playlists the signed-in user owns.
final playlistsProvider = FutureProvider<List<ServerItem>>((ref) async {
  final source = ref.watch(activeServerProvider);
  if (source == null) return const <ServerItem>[];
  try {
    return await source.playlists();
  } on ServerException {
    // A server without the playlist feature costs the sheet its list, not
    // the screen its actions.
    return const <ServerItem>[];
  }
});

/// One playlist's contents, so the sheet can show which ones already hold
/// this item and offer to take it out again.
final playlistContentsProvider =
    FutureProvider.family<List<ServerItem>, String>((ref, playlistId) async {
  final source = ref.watch(activeServerProvider);
  if (source == null) return const <ServerItem>[];
  try {
    return await source.playlistItems(playlistId);
  } on ServerException {
    return const <ServerItem>[];
  }
});

/// Everything that changed when watch state or favourites did.
///
/// One place, because the same edit shows up on four screens: the shelves on
/// the server home, the grid behind it, the detail screen itself and the
/// episode list under it. Missing one leaves a tick showing on a screen the
/// user just came from.
void invalidateItemViews(WidgetRef ref, {String? itemId, String? seriesId}) {
  if (itemId != null) ref.invalidate(serverItemProvider(itemId));
  if (seriesId != null) {
    ref.invalidate(seriesEpisodesProvider(seriesId));
    ref.invalidate(serverItemProvider(seriesId));
  }
  ref.invalidate(serverResumeProvider);
  ref.invalidate(serverNextUpProvider);
  ref.invalidate(serverLatestProvider);
  ref.invalidate(libraryItemsProvider);
  // A star added or taken away anywhere shows on Home and the Favorites page
  // the next time they are drawn, not after a pull to refresh.
  ref.invalidate(homeFavouritesProvider);
  ref.invalidate(favouriteItemsProvider);
  // Track menus read their own favourite flag from these lists.
  ref.invalidate(albumTracksProvider);
  ref.invalidate(artistTopTracksProvider);
  ref.invalidate(musicPageProvider);
}

/// Marks [itemId] watched or unwatched on the server.
///
/// Returns false when it could not be done, which the caller reports — a tick
/// that silently fails to stick is worse than an error.
Future<bool> setWatched(
  WidgetRef ref,
  String itemId, {
  required bool watched,
  String? seriesId,
}) async {
  final source = ref.read(activeServerProvider);
  if (source == null) return false;

  try {
    await source.setPlayed(itemId, played: watched);
    invalidateItemViews(ref, itemId: itemId, seriesId: seriesId);
    return true;
  } on ServerException {
    return false;
  }
}

Future<bool> setFavourite(
  WidgetRef ref,
  String itemId, {
  required bool favourite,
  String? seriesId,
}) async {
  final source = ref.read(activeServerProvider);
  if (source == null) return false;

  try {
    await source.setFavourite(itemId, favourite: favourite);
    invalidateItemViews(ref, itemId: itemId, seriesId: seriesId);
    return true;
  } on ServerException {
    return false;
  }
}

/// Plays [items] in a random order.
///
/// Shuffled here rather than asked of the server: `sortBy=Random` would give
/// a fresh order on every request, so the queue the player holds and the list
/// the screen shows would disagree about what comes next.
Future<void> shufflePlay(
  BuildContext context,
  WidgetRef ref,
  List<ServerItem> items,
) async {
  if (items.isEmpty) return;

  if (items.first.kind.isMusic) {
    await playMusicQueue(context, ref, items, shuffle: true);
    return;
  }

  final shuffled = List<ServerItem>.of(items)..shuffle(Random());
  await playServerQueue(
    context,
    ref,
    shuffled.map((i) => i.id).toList(),
  );
}

/// The sheet behind "Add to playlist".
///
/// Lists the user's playlists with a tick against the ones already holding
/// [itemIds], so the same sheet both adds and removes rather than needing a
/// separate screen to undo an accident.
Future<void> showPlaylistSheet(
  BuildContext context,
  WidgetRef ref, {
  required List<String> itemIds,
  bool audio = false,
}) async {
  if (itemIds.isEmpty) return;

  await showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (sheetContext) => _PlaylistSheet(itemIds: itemIds, audio: audio),
  );
}

class _PlaylistSheet extends ConsumerWidget {
  const _PlaylistSheet({required this.itemIds, required this.audio});

  final List<String> itemIds;

  /// What a playlist made from this sheet is filed as.
  final bool audio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = context.spacing;
    final l10n = AppLocalizations.of(context);
    final request = ref.watch(playlistsProvider);
    final playlists = request.value ?? const <ServerItem>[];

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
            child: Text(l10n.addToPlaylist, style: context.texts.titleMedium),
          ),
          if (request.isLoading && playlists.isEmpty)
            Padding(
              padding: EdgeInsets.all(spacing.xl),
              child: const Center(child: CircularProgressIndicator()),
            )
          else
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: <Widget>[
                  for (final ServerItem playlist in playlists)
                    _PlaylistRow(playlist: playlist, itemIds: itemIds),
                ],
              ),
            ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.playlist_add_rounded),
            title: Text(l10n.newPlaylist),
            onTap: () => _createPlaylist(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _createPlaylist(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController();
    final navigator = Navigator.of(context);

    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.newPlaylist),
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

    if (name == null || name.isEmpty) return;

    final source = ref.read(activeServerProvider);
    if (source == null) return;

    try {
      await source.createPlaylist(name, itemIds, audio: audio);
      ref.invalidate(playlistsProvider);
    } on ServerException {
      // Nothing was created, and the sheet closing on its own would suggest
      // otherwise; leave it open so the user can try again.
      return;
    }
    navigator.pop();
  }
}

class _PlaylistRow extends ConsumerWidget {
  const _PlaylistRow({required this.playlist, required this.itemIds});

  final ServerItem playlist;
  final List<String> itemIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contents =
        ref.watch(playlistContentsProvider(playlist.id)).value ??
            const <ServerItem>[];

    // "Holds all of them" rather than "holds one": adding a whole series to a
    // playlist that already has its first episode should still read as an
    // add, not as something to undo.
    final entries = <String>[
      for (final ServerItem e in contents)
        if (itemIds.contains(e.id)) e.playlistEntryId ?? e.id,
    ];
    final present = entries.length >= itemIds.length;

    return ListTile(
      leading: Icon(
        present ? Icons.playlist_add_check_rounded : Icons.queue_music_rounded,
      ),
      title: Text(playlist.title),
      trailing: present ? const Icon(Icons.check_rounded) : null,
      onTap: () async {
        final source = ref.read(activeServerProvider);
        if (source == null) return;

        try {
          if (present) {
            await source.removeFromPlaylist(playlist.id, entries);
          } else {
            await source.addToPlaylist(playlist.id, itemIds);
          }
          ref.invalidate(playlistContentsProvider(playlist.id));
        } on ServerException {
          return;
        }
      },
    );
  }
}

/// One thing that can be done to an item.
///
/// The list is built once and rendered twice — as chips under a detail
/// screen's play button, and as a menu on an episode row. Two hand-written
/// copies of the same six choices is how one of them ends up missing
/// "favourite" a month from now.
@immutable
class ItemAction {
  const ItemAction({
    required this.icon,
    required this.label,
    required this.onSelected,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final Future<void> Function() onSelected;

  /// On, in the sense a toggle is on: watched, or a favourite. Drawn as a
  /// filled chip, and it is why the label reads "Mark as unwatched".
  final bool selected;
}

/// Everything offered for [item], in the order both presentations use.
List<ItemAction> itemActionsFor(
  BuildContext context,
  WidgetRef ref, {
  required ServerItem item,
  String? seriesId,
  List<ServerItem> shuffleFrom = const <ServerItem>[],
  List<String> playlistIds = const <String>[],
  List<ServerItem> downloadAll = const <ServerItem>[],
  Future<void> Function()? onMediaInfo,
}) {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);

  Future<void> report(bool ok) async {
    if (!ok) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.actionFailed)));
    }
  }

  return <ItemAction>[
    // Nobody marks a song as watched: its play count is the server's to keep.
    if (!item.kind.isMusic)
      ItemAction(
        icon: item.played
            ? Icons.check_circle_rounded
            : Icons.check_circle_outline_rounded,
        label: item.played ? l10n.markUnwatched : l10n.markWatched,
        selected: item.played,
        onSelected: () async => report(
          await setWatched(
            ref,
            item.id,
            watched: !item.played,
            seriesId: seriesId,
          ),
        ),
      ),
    ItemAction(
      icon: item.favourite
          ? Icons.favorite_rounded
          : Icons.favorite_border_rounded,
      label: item.favourite ? l10n.removeFavourite : l10n.addFavourite,
      selected: item.favourite,
      onSelected: () async => report(
        await setFavourite(
          ref,
          item.id,
          favourite: !item.favourite,
          seriesId: seriesId,
        ),
      ),
    ),
    if (item.kind.isMusic) ...<ItemAction>[
      ItemAction(
        icon: Icons.queue_play_next_rounded,
        label: l10n.playNextInQueue,
        onSelected: () => queueMusicItem(context, ref, item, next: true),
      ),
      ItemAction(
        icon: Icons.add_to_queue_rounded,
        label: l10n.addToQueue,
        onSelected: () => queueMusicItem(context, ref, item, next: false),
      ),
      ItemAction(
        icon: Icons.auto_awesome_rounded,
        label: l10n.instantMix,
        onSelected: () => playInstantMix(context, ref, item.id),
      ),
    ],
    if (shuffleFrom.isNotEmpty)
      ItemAction(
        icon: Icons.shuffle_rounded,
        label: l10n.shufflePlay,
        onSelected: () => shufflePlay(context, ref, shuffleFrom),
      ),
    if (playlistIds.isNotEmpty)
      ItemAction(
        icon: Icons.playlist_add_rounded,
        label: l10n.addToPlaylist,
        onSelected: () => showPlaylistSheet(
          context,
          ref,
          itemIds: playlistIds,
          audio: item.kind.isMusic,
        ),
      ),
    if (onMediaInfo != null)
      ItemAction(
        icon: Icons.info_outline_rounded,
        label: l10n.mediaInfo,
        onSelected: onMediaInfo,
      ),
    // An artist is not a file, and "everything by them" is not a thing to
    // start with one press.
    if (item.kind != ServerItemKind.musicArtist)
      downloadAll.isEmpty
          ? _downloadAction(context, ref, item)
          : _downloadAllAction(context, ref, downloadAll),
  ];
}

/// Reports an action that could not be carried out.
void reportFailure(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

/// Download, and what becomes of the button once there is a copy.
///
/// One action whatever the state, so the row keeps its shape: it starts a
/// copy, shows how far one has got, picks a stopped one back up, and once
/// the copy is whole it is the way to remove it again — drawn selected, the
/// way a favourite is.
ItemAction _downloadAction(
  BuildContext context,
  WidgetRef ref,
  ServerItem item,
) {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final download = watchDownload(ref, item.id);

  if (download == null) {
    return ItemAction(
      icon: Icons.download_for_offline_outlined,
      label: l10n.download,
      onSelected: () async {
        final source = ref.read(activeServerProvider);
        if (source == null) {
          messenger.showSnackBar(SnackBar(content: Text(l10n.actionFailed)));
          return;
        }
        await ref.read(downloadsProvider.notifier).enqueue(source, item);
        messenger.showSnackBar(SnackBar(content: Text(l10n.addedToDownloads)));
      },
    );
  }

  final controller = ref.read(downloadsProvider.notifier);
  return switch (download.status) {
    DownloadStatus.queued => ItemAction(
        icon: Icons.downloading_rounded,
        label: l10n.downloadQueued,
        onSelected: () => controller.pause(download.key),
      ),
    DownloadStatus.downloading => ItemAction(
        icon: Icons.downloading_rounded,
        label: l10n.downloadingPercent(download.percent),
        onSelected: () => controller.pause(download.key),
      ),
    DownloadStatus.paused || DownloadStatus.failed => ItemAction(
        icon: Icons.download_for_offline_outlined,
        label: l10n.resumeDownload,
        onSelected: () => controller.resume(download.key),
      ),
    DownloadStatus.completed => ItemAction(
        icon: Icons.download_done_rounded,
        label: l10n.removeDownload,
        selected: true,
        onSelected: () => confirmRemoveDownload(
          context,
          ref,
          key: download.key,
          title: item.title,
          completed: true,
        ),
      ),
  };
}

/// "Download all" on a series: every episode not already on its way.
///
/// Asks first, with the count, because a long series is a lot of disk and
/// one press should not commit to it unseen. The listing carries no file
/// sizes, so the count is the honest figure there is.
ItemAction _downloadAllAction(
  BuildContext context,
  WidgetRef ref,
  List<ServerItem> episodes,
) {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);

  return ItemAction(
    icon: Icons.download_for_offline_outlined,
    label: l10n.downloadAll,
    onSelected: () async {
      final source = ref.read(activeServerProvider);
      if (source == null) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.actionFailed)));
        return;
      }
      final controller = ref.read(downloadsProvider.notifier);
      await controller.ready;

      final missing = <ServerItem>[
        for (final ServerItem e in episodes)
          if (switch (controller.entryFor(source.profile.id, e.id)?.status) {
            null || DownloadStatus.paused || DownloadStatus.failed => true,
            _ => false,
          })
            e,
      ];
      if (missing.isEmpty) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.allDownloaded)));
        return;
      }
      if (!context.mounted) return;

      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.downloadAllTitle(missing.length)),
          content: Text(l10n.downloadAllBody),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.download),
            ),
          ],
        ),
      );
      if (ok != true) return;

      for (final ServerItem e in missing) {
        await controller.enqueue(source, e);
      }
      messenger.showSnackBar(SnackBar(content: Text(l10n.addedToDownloads)));
    },
  );
}
