// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:math' show min;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../servers/media_library_source.dart';
import '../../widgets/gradient_art.dart';
import '../../widgets/remote_art.dart';
import '../../widgets/section_header.dart';
import '../servers/detail_sections.dart';
import '../servers/item_action_row.dart';
import '../servers/item_actions.dart';
import '../servers/server_library.dart';
import 'music_widgets.dart';

/// One album: its cover, who made it, and its tracks by disc.
class AlbumPage extends ConsumerWidget {
  const AlbumPage({super.key, this.albumId});

  /// Null when the route was opened directly rather than from a tile.
  final String? albumId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final id = albumId;

    final request = id == null
        ? const AsyncValue<ServerItem?>.data(null)
        : ref.watch(serverItemProvider(id));
    final album = request.value;

    final backButton = IconButton(
      icon: const Icon(Icons.arrow_back_rounded),
      tooltip: l10n.actionBack,
      onPressed: () => context.pop(),
    );

    if (id == null || album == null) {
      return Scaffold(
        appBar: AppBar(leading: backButton),
        body: request.isLoading
            ? const Center(child: CircularProgressIndicator())
            : MusicNote(text: l10n.nothingHere),
      );
    }

    final tracksRequest = ref.watch(albumTracksProvider(id));
    final tracks = tracksRequest.value ?? const <ServerItem>[];
    final compact = context.windowSize == WindowSize.compact;

    void play(int index) =>
        playMusicQueue(context, ref, tracks, startIndex: index);
    final onPlay = tracks.isEmpty ? null : () => play(0);
    final onShuffle = tracks.isEmpty
        ? null
        : () => shufflePlay(context, ref, tracks);

    // More than one disc is what earns the headings: "Disc 1" over the only
    // disc there is says nothing.
    final discs = tracks.map((t) => t.discNumber ?? 1).toSet();

    return Scaffold(
      appBar: AppBar(leading: backButton),
      bottomNavigationBar: compact
          ? MusicPlayBar(onPlay: onPlay, onShuffle: onShuffle)
          : null,
      body: ListView(
        padding: EdgeInsets.only(bottom: spacing.xl + context.systemBottomInset),
        children: <Widget>[
          _AlbumHeader(
            album: album,
            tracks: tracks,
            onPlay: onPlay,
            onShuffle: onShuffle,
          ),
          SizedBox(height: spacing.md),
          if (tracks.isEmpty)
            tracksRequest.isLoading
                ? Padding(
                    padding: EdgeInsets.all(spacing.xl),
                    child: const Center(child: CircularProgressIndicator()),
                  )
                : MusicNote(
                    text: tracksRequest.hasError
                        ? l10n.musicLoadFailed
                        : l10n.noSongs,
                  ),
          for (final (int i, ServerItem track) in tracks.indexed) ...<Widget>[
            if (discs.length > 1 &&
                (i == 0 ||
                    tracks[i - 1].discNumber != track.discNumber))
              SectionHeader(title: l10n.discNumber(track.discNumber ?? 1)),
            TrackRow(
              track: track,
              // Only where it adds something: the feature on one track, not
              // the album's own artist thirteen times over.
              subtitle: track.artistLine == album.artistLine
                  ? null
                  : track.artistLine,
              onTap: () => play(i),
            ),
          ],
        ],
      ),
    );
  }
}

/// The cover and what is known about the album: stacked on a phone, side by
/// side where there is room.
class _AlbumHeader extends ConsumerWidget {
  const _AlbumHeader({
    required this.album,
    required this.tracks,
    required this.onPlay,
    required this.onShuffle,
  });

  final ServerItem album;
  final List<ServerItem> tracks;
  final VoidCallback? onPlay;
  final VoidCallback? onShuffle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = context.spacing;
    final l10n = AppLocalizations.of(context);
    final compact = context.windowSize == WindowSize.compact;
    final gutter = spacing.screenHorizontal(context.windowSize);
    final align = compact ? CrossAxisAlignment.center : CrossAxisAlignment.start;
    final textAlign = compact ? TextAlign.center : TextAlign.start;

    final runtime = tracks.fold<Duration>(
      Duration.zero,
      (sum, t) => sum + (t.runtime ?? Duration.zero),
    );
    final facts = <String>[
      if (album.year != null) '${album.year}',
      if (tracks.isNotEmpty) l10n.trackCount(tracks.length),
      if (runtime > Duration.zero) durationLabel(runtime),
    ].join(' · ');

    final details = Column(
      crossAxisAlignment: align,
      children: <Widget>[
        Text(
          album.title,
          textAlign: textAlign,
          style: context.texts.headlineSmall,
        ),
        _ArtistLinks(artists: album.albumArtists, centred: compact),
        if (facts.isNotEmpty)
          Text(
            facts,
            textAlign: textAlign,
            style: context.texts.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        SizedBox(height: spacing.sm),
        if (!compact) ...<Widget>[
          MusicPlayButtons(onPlay: onPlay, onShuffle: onShuffle),
          SizedBox(height: spacing.sm),
        ],
        // Waits for the tracks: until they land, Download has nothing to fetch
        // but the album itself, which is a folder and has no file.
        if (tracks.isNotEmpty)
          ItemActionIcons(
            item: album,
            primary: false,
            alignment: compact ? WrapAlignment.center : WrapAlignment.start,
            onPlay: onPlay ?? () {},
            playlistIds: tracks.map((t) => t.id).toList(),
            downloadAll: tracks,
          ),
        SizedBox(height: spacing.sm),
        TagStrip(tags: album.genres),
      ],
    );

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: gutter),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final side = compact
              ? min(constraints.maxWidth * 0.62, 280.0)
              : min(constraints.maxWidth * 0.3, 280.0);
          final cover = ClipRRect(
            borderRadius: context.radii.cardAll,
            child: SizedBox.square(
              dimension: side,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  GradientArt(seed: album.title, icon: Icons.album_rounded),
                  RemoteArt(url: artUrlFor(ref, album, maxWidth: 800)),
                ],
              ),
            ),
          );

          return compact
              ? Column(
                  children: <Widget>[
                    cover,
                    SizedBox(height: spacing.lg),
                    details,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    cover,
                    SizedBox(width: spacing.xl),
                    Expanded(child: details),
                  ],
                );
        },
      ),
    );
  }
}

/// The album's artists, each opening their own page.
///
/// An artist with no id cannot be opened, so it is plain text: "Various
/// Artists" often comes back that way.
class _ArtistLinks extends StatelessWidget {
  const _ArtistLinks({required this.artists, required this.centred});

  final List<ServerArtistRef> artists;
  final bool centred;

  @override
  Widget build(BuildContext context) {
    if (artists.isEmpty) return const SizedBox.shrink();

    return Wrap(
      alignment: centred ? WrapAlignment.center : WrapAlignment.start,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        for (final ServerArtistRef artist in artists)
          artist.id == null
              ? Padding(
                  padding: EdgeInsets.all(context.spacing.sm),
                  child: Text(artist.name),
                )
              : TextButton(
                  onPressed: () => openMusicArtist(context, artist),
                  child: Text(artist.name),
                ),
      ],
    );
  }
}
