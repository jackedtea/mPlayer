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
import '../../widgets/backdrop_header.dart';
import '../servers/item_actions.dart';
import '../servers/server_library.dart';
import 'music_widgets.dart';

/// One artist: what people play, their albums, what they guest on, and who
/// else sounds like them. Every section is absent until it has something in it.
class ArtistPage extends ConsumerStatefulWidget {
  const ArtistPage({super.key, this.artistId, this.name = ''});

  /// Null when the route was opened directly rather than from a tile.
  final String? artistId;

  /// Shown until the artist's own record lands.
  final String name;

  @override
  ConsumerState<ArtistPage> createState() => _ArtistPageState();
}

class _ArtistPageState extends ConsumerState<ArtistPage> {
  /// How many Popular rows show before "See all".
  static const _collapsedTracks = 5;

  bool _showAllTracks = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final id = widget.artistId;

    if (id == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: l10n.actionBack,
            onPressed: () => context.pop(),
          ),
        ),
        body: MusicNote(text: l10n.nothingHere),
      );
    }

    final artist = ref.watch(serverItemProvider(id)).value;
    final topTracks =
        ref.watch(artistTopTracksProvider(id)).value ?? const <ServerItem>[];
    final albums =
        ref.watch(artistAlbumsProvider(id)).value ?? const <ServerItem>[];
    final appearsOn =
        ref.watch(artistAppearsOnProvider(id)).value ?? const <ServerItem>[];
    // The server's `/Similar` answers for an artist with artists, so the film
    // screens' provider serves here too.
    final similar =
        ref.watch(similarItemsProvider(id)).value ?? const <ServerItem>[];

    final compact = context.windowSize == WindowSize.compact;
    final title = artist?.title ?? widget.name;

    void play(int index) =>
        playMusicQueue(context, ref, topTracks, startIndex: index);
    final onPlay = topTracks.isEmpty ? null : () => play(0);
    final onShuffle = topTracks.isEmpty
        ? null
        : () => shufflePlay(context, ref, topTracks);

    final shownTracks = _showAllTracks
        ? topTracks
        : topTracks.take(_collapsedTracks).toList();

    return Scaffold(
      bottomNavigationBar: compact
          ? MusicPlayBar(onPlay: onPlay, onShuffle: onShuffle)
          : null,
      body: ListView(
        padding: EdgeInsets.only(bottom: spacing.xl + context.systemBottomInset),
        children: <Widget>[
          BackdropHeader(
            seed: title,
            // Most artists have a portrait and no wide picture; a crop of the
            // portrait still beats a gradient.
            artUrl: artist == null
                ? null
                : backdropUrlFor(ref, artist, maxWidth: 1920) ??
                      artUrlFor(ref, artist, maxWidth: 1200),
            height: compact ? 240 : 320,
            actions: <Widget>[
              if (artist != null) _FavouriteControl(artist: artist),
            ],
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.texts.headlineMedium,
            ),
          ),
          if (!compact)
            Padding(
              padding: spacing
                  .screenPadding(context.windowSize)
                  .copyWith(top: spacing.sm),
              child: Align(
                alignment: Alignment.centerLeft,
                child: MusicPlayButtons(onPlay: onPlay, onShuffle: onShuffle),
              ),
            ),
          if (topTracks.isNotEmpty) ...<Widget>[
            Padding(
              padding: spacing
                  .screenPadding(context.windowSize)
                  .copyWith(top: spacing.lg, bottom: spacing.xs),
              child: Text(l10n.popularTracks, style: context.texts.titleMedium),
            ),
            for (final (int i, ServerItem track) in shownTracks.indexed)
              TrackRow(
                track: track,
                showArt: true,
                subtitle: track.album,
                onTap: () => play(i),
              ),
            if (topTracks.length > _collapsedTracks)
              Padding(
                padding: spacing.screenPadding(context.windowSize),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () =>
                        setState(() => _showAllTracks = !_showAllTracks),
                    child: Text(
                      _showAllTracks ? l10n.less : l10n.seeAllTracks,
                    ),
                  ),
                ),
              ),
          ],
          MusicShelf(
            title: l10n.tabAlbums,
            items: albums,
            captionOf: (album) => album.year?.toString(),
          ),
          MusicShelf(
            title: l10n.appearsOn,
            items: appearsOn,
            captionOf: (album) => album.artistLine,
          ),
          MusicShelf(title: l10n.similarArtists, items: similar),
        ],
      ),
    );
  }
}

/// The star on an artist's header. The artist has no row of actions: marking
/// them watched, downloading or adding them to a playlist mean nothing.
class _FavouriteControl extends ConsumerWidget {
  const _FavouriteControl({required this.artist});

  final ServerItem artist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return CircleControl(
      icon: artist.favourite
          ? Icons.favorite_rounded
          : Icons.favorite_border_rounded,
      tooltip: artist.favourite ? l10n.removeFavourite : l10n.addFavourite,
      onPressed: () async {
        final messenger = ScaffoldMessenger.of(context);
        final ok = await setFavourite(
          ref,
          artist.id,
          favourite: !artist.favourite,
        );
        if (!ok) {
          messenger.showSnackBar(SnackBar(content: Text(l10n.actionFailed)));
        }
      },
    );
  }
}
