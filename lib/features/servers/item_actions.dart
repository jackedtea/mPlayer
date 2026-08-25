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
}) async {
  if (itemIds.isEmpty) return;

  await showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (sheetContext) => _PlaylistSheet(itemIds: itemIds),
  );
}

class _PlaylistSheet extends ConsumerWidget {
  const _PlaylistSheet({required this.itemIds});

  final List<String> itemIds;

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
      await source.createPlaylist(name, itemIds);
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

/// Reports an action that could not be carried out.
void reportFailure(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
