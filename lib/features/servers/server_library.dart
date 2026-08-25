// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

/// What the server screens read, and how a [ServerItem] becomes something
/// those screens can draw.
///
/// The mapping lives here rather than in `lib/servers/` on purpose: it turns
/// durations into "41m left" and picks an icon, both of which need a locale
/// and a design — neither of which belongs behind an HTTP client.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/library_models.dart';
import '../../core/models/media_models.dart';
import '../../l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../player/playback_state.dart';
import '../../servers/media_library_source.dart';
import '../../servers/server_registry.dart';
import '../../sources/media_source.dart';
import '../../sources/source_registry.dart';

/// The signed-in client, or null when nothing is signed in.
final activeServerProvider = Provider<MediaLibrarySource?>(
  (ref) => ref.watch(serverRegistryProvider).source,
);

/// A library and the order it is being read in.
///
/// The two travel together because the sort is part of the *request*: the
/// server does the ordering, so changing it has to refetch rather than
/// reorder what is already here.
@immutable
class LibraryQuery {
  const LibraryQuery(this.viewId, this.sort);

  final String viewId;
  final ServerSort sort;

  @override
  bool operator ==(Object other) =>
      other is LibraryQuery && other.viewId == viewId && other.sort == sort;

  @override
  int get hashCode => Object.hash(viewId, sort);
}

/// One page of a library.
final libraryItemsProvider =
    FutureProvider.family<List<ServerItem>, LibraryQuery>((ref, query) async {
  final source = ref.watch(activeServerProvider);
  if (source == null) return const <ServerItem>[];
  return source.items(query.viewId, sort: query.sort);
});

final serverViewsProvider = FutureProvider<List<LibraryView>>((ref) async {
  final source = ref.watch(activeServerProvider);
  if (source == null) return const <LibraryView>[];
  return source.views();
});

final serverResumeProvider = FutureProvider<List<ServerItem>>((ref) async {
  final source = ref.watch(activeServerProvider);
  if (source == null) return const <ServerItem>[];
  return source.resumable();
});

final serverNextUpProvider = FutureProvider<List<ServerItem>>((ref) async {
  final source = ref.watch(activeServerProvider);
  if (source == null) return const <ServerItem>[];
  return source.nextUp();
});

/// The newest additions across every library, for the home shelf.
final serverLatestProvider = FutureProvider<List<ServerItem>>((ref) async {
  final source = ref.watch(activeServerProvider);
  if (source == null) return const <ServerItem>[];

  final views = await ref.watch(serverViewsProvider.future);
  // Only the libraries that hold something watchable: a music library's
  // newest albums have no place on this shelf.
  final watchable = views.where(
    (v) => v.kind == 'movies' || v.kind == 'tvshows' || v.kind == 'unknown',
  );
  if (watchable.isEmpty) return const <ServerItem>[];

  final items = <ServerItem>[];
  for (final LibraryView view in watchable.take(3)) {
    items.addAll(
      await source.items(view.id, limit: 12, sort: ServerSort.dateAdded),
    );
  }
  return items.take(20).toList();
});

/// The newest additions inside one library, for the filtered shelf.
final latestInViewProvider =
    FutureProvider.family<List<ServerItem>, String>((ref, viewId) async {
  final source = ref.watch(activeServerProvider);
  if (source == null) return const <ServerItem>[];
  return source.items(viewId, limit: 20, sort: ServerSort.dateAdded);
});

final serverSearchProvider =
    FutureProvider.family<List<ServerItem>, String>((ref, query) async {
  final source = ref.watch(activeServerProvider);
  if (source == null || query.trim().isEmpty) return const <ServerItem>[];
  return source.search(query.trim());
});

/// One item, fetched for a detail screen.
final serverItemProvider =
    FutureProvider.family<ServerItem?, String>((ref, itemId) async {
  final source = ref.watch(activeServerProvider);
  if (source == null) return null;
  return source.item(itemId);
});

/// How many items one library holds.
///
/// Separate from [serverViewsProvider] because it is a separate request per
/// library — cheap ones, `limit=0`, but the library tiles must draw before
/// they land rather than waiting on four round trips.
final libraryItemCountProvider =
    FutureProvider.family<int?, String>((ref, viewId) async {
  final source = ref.watch(activeServerProvider);
  if (source == null) return null;
  try {
    return await source.itemCount(viewId);
  } on ServerException {
    // No count is better than a wrong one; the tile shows the name alone.
    return null;
  }
});

/// What the server suggests alongside an item.
///
/// A separate request from the item itself, so a server that has no `/Similar`
/// route — or simply no opinion — costs the screen a shelf and nothing else.
final similarItemsProvider =
    FutureProvider.family<List<ServerItem>, String>((ref, itemId) async {
  final source = ref.watch(activeServerProvider);
  if (source == null) return const <ServerItem>[];
  try {
    return await source.similar(itemId);
  } on ServerException {
    return const <ServerItem>[];
  }
});

/// A series' episodes, flattened across seasons in the order the server
/// returns them — which is broadcast order, and what a viewer expects.
final seriesEpisodesProvider =
    FutureProvider.family<List<ServerItem>, String>((ref, seriesId) async {
  final source = ref.watch(activeServerProvider);
  if (source == null) return const <ServerItem>[];
  return source.episodes(seriesId);
});

/// Resolves a server item and hands it to the player.
///
/// Resolution happens here rather than inside the player so a server that
/// refuses reports on the screen the user pressed, instead of opening a black
/// player that then fails. The resume position comes back with it: the server
/// has been collecting that from every device, not just this one.
Future<void> playServerItem(
  BuildContext context,
  WidgetRef ref,
  String itemId, {
  bool fromStart = false,
}) async {
  final profile = ref.read(serverRegistryProvider).active;
  if (profile == null) return;

  final source = ref.read(mediaSourcesProvider)[profile.id];
  if (source == null) return;

  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.of(context);

  try {
    final resolved = await source.resolve(
      MediaRef(sourceId: profile.id, itemId: itemId, title: ''),
    );
    // "Start over" is the one case where the server's resume point is not
    // what the user asked for.
    final media = fromStart ? resolved.startingAt(Duration.zero) : resolved;
    router.push('/player', extra: media);
  } on MediaSourceException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  }
}

/// What the server would send for an item, without playing it.
///
/// This is what makes an audio track selectable *before* the film starts: the
/// track list comes from the server's playback decision, not from a decoder
/// that has to open the file first. Asking costs a `PlaybackInfo` round trip
/// and, on some servers, a transcode slot that is released when the session
/// times out — so it is only requested by the screen that shows the pickers.
final playbackInfoProvider =
    FutureProvider.family<ServerPlayback?, String>((ref, itemId) async {
  final source = ref.watch(activeServerProvider);
  if (source == null) return null;
  try {
    return await source.playback(itemId, const PlaybackCapabilities());
  } on ServerException {
    return null;
  }
});

/// Plays [itemIds] in the order given, starting at [startIndex].
///
/// Only the first is resolved here. The rest are handed over as bare
/// references and resolved when the player reaches them — resolving twenty
/// episodes up front would mean twenty round trips before anything played,
/// and twenty transcodes the user never asked to start.
Future<void> playServerQueue(
  BuildContext context,
  WidgetRef ref,
  List<String> itemIds, {
  int startIndex = 0,
}) async {
  if (itemIds.isEmpty) return;

  final profile = ref.read(serverRegistryProvider).active;
  if (profile == null) return;

  final source = ref.read(mediaSourcesProvider)[profile.id];
  if (source == null) return;

  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.of(context);

  final index = startIndex.clamp(0, itemIds.length - 1);

  try {
    final media = await source.resolve(
      MediaRef(sourceId: profile.id, itemId: itemIds[index], title: ''),
    );

    router.push(
      '/player',
      extra: PlayerLaunch(
        media: media,
        queue: PlaybackQueue(
          items: <MediaRef>[
            for (final String id in itemIds)
              MediaRef(sourceId: profile.id, itemId: id, title: ''),
          ],
          index: index,
        ),
      ),
    );
  } on MediaSourceException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  }
}

// --------------------------------------------------------------- mapping

/// Artwork for [item] on the signed-in server, or null.
///
/// [maxWidth] is asked for so the server resizes rather than sending a 2000px
/// poster to fill a 108px tile — the difference on a phone is most of the
/// data a library grid costs.
Uri? artUrlFor(WidgetRef ref, ServerItem item, {int? maxWidth}) {
  return ref.watch(activeServerProvider)?.imageUrl(item, maxWidth: maxWidth);
}

/// A poster tile in a grid or a shelf.
LibraryItem libraryItemFrom(ServerItem item) {
  return LibraryItem(
    id: item.id,
    title: item.title,
    // The design draws a bare year under the title; an item without one gets
    // an empty line rather than a placeholder.
    year: item.year?.toString() ?? '',
    watched: item.played,
  );
}

/// A card on the Continue-watching or Next-up shelf.
ResumeItem resumeItemFrom(
  ServerItem item,
  AppLocalizations l10n, {
  required String serverLabel,
}) {
  return ResumeItem(
    id: item.id,
    // An episode reads as "Westworld · S1E10" rather than by its own title,
    // which on its own says nothing about what is being resumed.
    title: item.seriesTitle == null
        ? item.title
        : '${item.seriesTitle} · ${episodeCode(item)}',
    sourceKind: SourceKind.jellyfin,
    sourceLabel: serverLabel,
    remaining: remainingLabel(item, l10n),
    // The server does not state a quality tier, and inventing "4K HDR" from
    // a height would be a guess shown as a fact.
    quality: '',
    progress: item.watchedFraction ?? 0,
  );
}

/// "S1E10", or an empty string for anything that is not an episode.
String episodeCode(ServerItem item) {
  final season = item.seasonNumber;
  final episode = item.episodeNumber;
  if (season == null || episode == null) return '';
  return 'S${season}E$episode';
}

/// "41m left", or the runtime for something never started.
String remainingLabel(ServerItem item, AppLocalizations l10n) {
  final runtime = item.runtime;
  if (runtime == null) return '';

  final left = item.position == null ? runtime : runtime - item.position!;
  if (left <= Duration.zero) return '';

  return l10n.timeLeft(durationLabel(left));
}

/// "2h 16m", "48m", "1m". Never "0m": something under a minute reads as
/// finished, which is what the caller checks for.
String durationLabel(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);

  if (hours > 0) return minutes == 0 ? '${hours}h' : '${hours}h ${minutes}m';
  return '${duration.inMinutes.clamp(1, 59)}m';
}

/// Everything screen 1f draws for one item.
MovieDetail movieDetailFrom(ServerItem item, AppLocalizations l10n) {
  final runtime = item.runtime;
  final position = item.position;

  return MovieDetail(
    title: item.title,
    year: item.year?.toString() ?? '',
    // One decimal, because "8.10" reads as a precision the rating does not
    // have and "8" reads as a whole number nobody wrote.
    rating: item.rating == null ? '' : item.rating!.toStringAsFixed(1),
    runtime: runtime == null ? '' : durationLabel(runtime),
    certificate: item.certificate ?? '',
    // The server states no quality tier; deriving "4K HDR" from a stream
    // height would be a guess shown as a fact.
    quality: '',
    overview: item.overview ?? '',
    genres: item.genres,
    // The media-info card needs the stream list, which arrives with the
    // playback decision rather than with the item.
    info: const <MediaInfoRow>[],
    cast: <CastMember>[
      for (final ServerPerson p in item.people)
        CastMember(name: p.name, role: p.role),
    ],
    watchedFraction: item.watchedFraction ?? 0,
    // Null is what makes the primary button read "Play" instead of "Resume",
    // so an unstarted item must not get a label here.
    resumeLabel: position == null || runtime == null
        ? null
        : l10n.resumeAt(durationLabel(position)),
  );
}

/// One episode row on screen 1g.
Episode episodeFrom(ServerItem item, AppLocalizations l10n) {
  final runtime = item.runtime;
  final fraction = item.watchedFraction ?? 0;

  return Episode(
    number: item.episodeNumber ?? 0,
    title: item.title,
    description: item.overview ?? '',
    meta: <String>[
      if (runtime != null) durationLabel(runtime),
      if (item.played)
        l10n.watched
      else if (fraction > 0)
        remainingLabel(item, l10n)
      else
        // "new", not "Unwatched": this sits in an episode's meta line after
        // its runtime, where the filter chip's wording would read oddly.
        l10n.episodeNew,
    ].where((s) => s.isNotEmpty).join(' · '),
    // A watched episode shows no bar: the tick already says so, and a full
    // bar under it says the same thing twice.
    progress: item.played ? 0 : fraction,
  );
}

/// A series and its seasons, as screen 1g draws them.
///
/// The episodes arrive flat and in broadcast order; the seasons are grouped
/// out of them rather than fetched separately, which would be a request per
/// season for data already in hand.
SeriesDetail seriesDetailFrom(
  ServerItem series,
  List<ServerItem> episodes,
  AppLocalizations l10n,
) {
  final bySeason = <int, List<ServerItem>>{};
  for (final ServerItem episode in episodes) {
    // A special with no season number is season 0, which is what Jellyfin
    // calls the specials folder anyway.
    bySeason
        .putIfAbsent(episode.seasonNumber ?? 0, () => <ServerItem>[])
        .add(episode);
  }

  final numbers = bySeason.keys.toList()..sort();
  final unwatched = episodes.where((e) => !e.played).length;

  return SeriesDetail(
    title: series.title,
    summary: <String>[
      l10n.seasonCount(numbers.length),
      l10n.episodeCount(episodes.length),
      if (unwatched > 0) l10n.unwatchedCount(unwatched),
    ].join(' · '),
    seasons: <Season>[
      for (final int number in numbers)
        Season(
          name: number == 0 ? l10n.specials : l10n.seasonNumber(number),
          episodes: <Episode>[
            for (final ServerItem e in bySeason[number]!) episodeFrom(e, l10n),
          ],
        ),
    ],
  );
}

/// One search result from a server.
SearchHit searchHitFrom(ServerItem item, AppLocalizations l10n) {
  return SearchHit(
    title: item.title,
    // The line under the title says what the thing *is*, since a title alone
    // does not distinguish a film from the series of the same name.
    subtitle: <String>[
      if (item.year != null) '${item.year}',
      if (item.kind == ServerItemKind.episode && item.seriesTitle != null)
        '${item.seriesTitle} ${episodeCode(item)}'
      else
        _kindLabel(item.kind, l10n),
    ].where((s) => s.isNotEmpty).join(' · '),
    kind: SearchHitKind.poster,
  );
}

String _kindLabel(ServerItemKind kind, AppLocalizations l10n) {
  return switch (kind) {
    ServerItemKind.movie => l10n.kindMovie,
    ServerItemKind.series => l10n.kindSeries,
    ServerItemKind.season => l10n.kindSeason,
    ServerItemKind.episode => l10n.kindEpisode,
    _ => '',
  };
}

/// The icon a library gets in the sections list.
IconData iconForLibrary(String kind) {
  return switch (kind) {
    'movies' => Icons.movie_rounded,
    'tvshows' => Icons.live_tv_rounded,
    'music' => Icons.library_music_rounded,
    'musicvideos' => Icons.music_video_rounded,
    'homevideos' || 'photos' => Icons.photo_library_rounded,
    'books' => Icons.menu_book_rounded,
    'boxsets' => Icons.collections_bookmark_rounded,
    _ => Icons.folder_rounded,
  };
}

/// A library, as the sections list draws it.
LibrarySection librarySectionFrom(LibraryView view, {int? itemCount}) {
  return LibrarySection(
    name: view.name,
    // Zero only when the server has actually said so. The tile treats a null
    // count as "not known yet" and draws no line at all, rather than claiming
    // an empty library.
    itemCount: itemCount ?? 0,
    icon: iconForLibrary(view.kind),
  );
}
