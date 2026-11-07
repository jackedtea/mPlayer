// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../servers/media_library_source.dart';
import '../../sources/media_source.dart';
import '../player/playback_controller.dart';
import '../servers/server_library.dart';
import 'audio_session.dart';

/// How many of an artist's tracks "Add to queue" takes. Their Popular list
/// shown in full rather than a discography: a queue is held in memory.
const _artistQueueLimit = 100;

/// The tracks [item] stands for, in the order they would play.
Future<List<ServerItem>> _tracksOf(
  MediaLibrarySource source,
  ServerItem item,
) async {
  return switch (item.kind) {
    ServerItemKind.musicAlbum => source.albumTracks(item.id),
    ServerItemKind.musicArtist => source.artistTopTracks(
      item.id,
      limit: _artistQueueLimit,
    ),
    _ => <ServerItem>[item],
  };
}

/// Puts a track, an album or an artist into the queue: straight after what is
/// playing when [next], otherwise at the end.
///
/// With no music playing there is no queue to add to, so it starts playing:
/// someone asking for this song next does not want silence until they find
/// a Play button.
Future<void> queueMusicItem(
  BuildContext context,
  WidgetRef ref,
  ServerItem item, {
  required bool next,
}) async {
  final source = ref.read(activeServerProvider);
  final profile = source?.profile;
  if (source == null || profile == null) return;

  final messenger = ScaffoldMessenger.of(context);
  final l10n = AppLocalizations.of(context);

  final List<ServerItem> tracks;
  try {
    tracks = await _tracksOf(source, item);
  } on ServerException {
    messenger.showSnackBar(SnackBar(content: Text(l10n.actionFailed)));
    return;
  }
  if (tracks.isEmpty) return;

  if (!ref.read(audioSessionProvider)) {
    if (context.mounted) await playMusicQueue(context, ref, tracks);
    return;
  }

  final playback = ref.read(playbackControllerProvider.notifier);
  final refs = <MediaRef>[
    for (final ServerItem t in tracks)
      MediaRef(sourceId: profile.id, itemId: t.id, title: t.title),
  ];
  // Backwards for "next": each lands straight after the current song, so the
  // last one in goes first and an album keeps its order.
  if (next) {
    refs.reversed.forEach(playback.queueNext);
  } else {
    refs.forEach(playback.addToQueue);
  }
  messenger.showSnackBar(SnackBar(content: Text(l10n.addedToQueue)));
}

/// Replaces the queue with the server's mix built around [itemId]: a track,
/// an album, an artist or a genre.
Future<void> playInstantMix(
  BuildContext context,
  WidgetRef ref,
  String itemId,
) async {
  final source = ref.read(activeServerProvider);
  if (source == null) return;

  final messenger = ScaffoldMessenger.of(context);
  final l10n = AppLocalizations.of(context);

  try {
    final mix = await source.instantMix(itemId);
    if (mix.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.noInstantMix)));
    } else if (context.mounted) {
      await playMusicQueue(context, ref, mix);
    }
  } on ServerException {
    messenger.showSnackBar(SnackBar(content: Text(l10n.actionFailed)));
  }
}
