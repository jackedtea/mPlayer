// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../servers/media_library_source.dart';
import '../../widgets/section_header.dart';
import '../music/music_widgets.dart';
import '../servers/detail_sections.dart';
import '../servers/server_library.dart';
import '../servers/shelves.dart';

/// Movies, Shows, Episodes and People, each a row that scrolls sideways —
/// the layout Jellyfin's web client gives both search results and the
/// Favorites page, and the one both use here.
///
/// A kind with nothing in it is not drawn. With nothing at all, [emptyText]
/// is said once every kind has answered, and a spinner until then: "nothing"
/// while three requests are still out is wrong more often than it is right.
///
/// Music only where the caller asks for it, which Search does and the
/// Favorites page does not yet.
class KindSections extends ConsumerWidget {
  const KindSections({
    super.key,
    required this.movies,
    required this.shows,
    required this.episodes,
    required this.people,
    required this.emptyText,
    this.albums = _nothing,
    this.artists = _nothing,
    this.songs = _nothing,
  });

  static const _nothing = AsyncValue<List<ServerItem>>.data(<ServerItem>[]);

  final AsyncValue<List<ServerItem>> movies;
  final AsyncValue<List<ServerItem>> shows;
  final AsyncValue<List<ServerItem>> episodes;
  final AsyncValue<List<ServerPerson>> people;
  final AsyncValue<List<ServerItem>> albums;
  final AsyncValue<List<ServerItem>> artists;
  final AsyncValue<List<ServerItem>> songs;
  final String emptyText;

  static bool _has<T>(AsyncValue<List<T>> v) => v.value?.isNotEmpty ?? false;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;

    final loading = movies.isLoading ||
        shows.isLoading ||
        episodes.isLoading ||
        people.isLoading ||
        albums.isLoading ||
        artists.isLoading ||
        songs.isLoading;
    final anything =
        _has(movies) ||
        _has(shows) ||
        _has(episodes) ||
        _has(people) ||
        _has(albums) ||
        _has(artists) ||
        _has(songs);

    if (!anything) {
      return loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: spacing.screenHorizontal(context.windowSize),
                ),
                child: Text(
                  emptyText,
                  textAlign: TextAlign.center,
                  style: context.texts.bodyMedium
                      ?.copyWith(color: context.colors.onSurfaceVariant),
                ),
              ),
            );
    }

    Widget section(String title, Widget shelf) => Padding(
          padding: EdgeInsets.only(bottom: spacing.sectionGap),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[SectionHeader(title: title), shelf],
          ),
        );

    return ListView(
      padding: EdgeInsets.only(
        top: spacing.sm,
        bottom: spacing.xl + context.systemBottomInset,
      ),
      children: <Widget>[
        if (_has(movies))
          section(l10n.searchMovies, ServerPosterShelf(items: movies)),
        if (_has(shows))
          section(l10n.searchShows, ServerPosterShelf(items: shows)),
        if (_has(episodes))
          section(l10n.searchEpisodes, ServerCardShelf(items: episodes)),
        if (_has(people))
          section(l10n.searchPeople, PeopleStrip(people: people.value!)),
        if (_has(albums))
          section(
            l10n.tabAlbums,
            MusicShelf(
              items: albums.value!,
              captionOf: (album) => album.artistLine,
            ),
          ),
        if (_has(artists))
          section(l10n.tabArtists, MusicShelf(items: artists.value!)),
        if (_has(songs))
          section(
            l10n.tabSongs,
            MusicShelf(
              items: songs.value!,
              captionOf: (song) => song.artistLine,
              // Played, unlike the tiles above: a song found by name is
              // wanted now, and its album is one more tap away from that.
              onTap: (i) =>
                  playMusicQueue(context, ref, songs.value!, startIndex: i),
            ),
          ),
        // A section still on its way, under the ones that have arrived.
        if (loading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}
