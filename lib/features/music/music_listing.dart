// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../servers/media_library_source.dart';
import '../../widgets/poster_tile.dart';
import '../servers/library_view_settings.dart';
import '../servers/server_library.dart';
import 'music_widgets.dart';

/// Albums, artists or songs: a music library's first three tabs.
///
/// Fetched a page at a time as it is scrolled. The film grid can show one page
/// and call it a start, but a music library's songs run to tens of thousands,
/// and stopping at the hundredth would hide most of it.
class MusicListingView extends ConsumerStatefulWidget {
  const MusicListingView({
    super.key,
    required this.listing,
    required this.query,
  });

  final MusicListing listing;
  final LibraryQuery query;

  @override
  ConsumerState<MusicListingView> createState() => _MusicListingViewState();
}

class _MusicListingViewState extends ConsumerState<MusicListingView>
    with AutomaticKeepAliveClientMixin {
  /// How many pages are wanted so far.
  int _pages = 1;

  /// Kept alive so that a look at the next tab does not lose the place, and
  /// every page with it, in a list of thousands.
  @override
  bool get wantKeepAlive => true;

  @override
  void didUpdateWidget(MusicListingView old) {
    super.didUpdateWidget(old);
    if (old.query != widget.query) _pages = 1;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context);

    final items = <ServerItem>[];
    var loading = false;
    var failed = false;
    var finished = false;

    for (var page = 0; page < _pages; page++) {
      final request = ref.watch(
        musicPageProvider((
          query: widget.query,
          listing: widget.listing,
          page: page,
        )),
      );
      final value = request.value;
      if (value == null) {
        loading = request.isLoading;
        failed = request.hasError;
        break;
      }
      items.addAll(value);
      // One page only for Random: the server deals a new order on every
      // request, so the second page would repeat some of the first and skip
      // others.
      if (value.length < libraryPageSize ||
          widget.query.sort == ServerSort.random) {
        finished = true;
        break;
      }
    }

    if (items.isEmpty) {
      if (loading) return const Center(child: CircularProgressIndicator());
      return MusicNote(
        text: failed
            ? l10n.musicLoadFailed
            : switch (widget.listing) {
                MusicListing.albums => l10n.noAlbums,
                MusicListing.artists => l10n.noArtists,
                MusicListing.tracks => l10n.noSongs,
              },
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        // A page that failed is not asked for again by every scroll tick;
        // Refresh in the app bar is the way back.
        if (!finished &&
            !loading &&
            !failed &&
            notification.depth == 0 &&
            notification.metrics.extentAfter < 800) {
          setState(() => _pages++);
        }
        return false;
      },
      child: LayoutBuilder(
        builder: (context, constraints) => CustomScrollView(
          slivers: <Widget>[
            widget.listing == MusicListing.tracks
                ? _songs(items)
                : _grid(items, constraints.maxWidth),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(
                  top: context.spacing.md,
                  // Clear of the filter button, which floats over the end of
                  // the list and would otherwise sit on the last row's menu.
                  bottom: 72 + context.systemBottomInset,
                ),
                child: loading
                    ? const Center(child: CircularProgressIndicator())
                    : failed
                    ? MusicNote(text: l10n.musicLoadFailed)
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _songs(List<ServerItem> items) {
    return SliverList.builder(
      itemCount: items.length,
      itemBuilder: (context, i) {
        final track = items[i];
        final credits = <String>[?track.artistLine, ?track.album].join(' · ');
        return TrackRow(
          track: track,
          showArt: true,
          subtitle: credits.isEmpty ? null : credits,
          // The songs loaded so far, not the library's: a queue is held in
          // memory, and tens of thousands of entries is not a thing to hold
          // because someone tapped one song.
          onTap: () => playMusicQueue(context, ref, items, startIndex: i),
        );
      },
    );
  }

  Widget _grid(List<ServerItem> items, double width) {
    final spacing = context.spacing;
    final columns = columnsForWidth(
      ref.watch(libraryColumnsProvider),
      MediaQuery.sizeOf(context).width,
    );
    final gutter = (spacing.screenHorizontal(context.windowSize) -
            spacing.hitInset)
        .clamp(0.0, double.infinity);
    final cell = (width - gutter * 2) / columns;
    final side = (cell - spacing.hitInset * 2).clamp(48.0, 400.0);
    final albums = widget.listing == MusicListing.albums;

    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: gutter),
      sliver: SliverGrid.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: spacing.sm,
          crossAxisSpacing: 0,
          mainAxisExtent: PosterTile.outerHeight(
            context,
            side,
            withCaption: albums,
          ),
        ),
        itemCount: items.length,
        itemBuilder: (context, i) => MusicTile(
          item: items[i],
          side: side,
          // Who made the album: on a shelf of records, that is the fact a
          // year is not.
          caption: albums ? items[i].artistLine ?? '' : null,
        ),
      ),
    );
  }
}
