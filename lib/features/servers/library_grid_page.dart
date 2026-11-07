// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../servers/media_library_source.dart';
import '../libraries/last_library.dart';
import '../music/music_listing.dart';
import '../../widgets/gradient_art.dart';
import '../../widgets/poster_tile.dart';
import '../../widgets/remote_art.dart';
import '../../widgets/section_header.dart';
import 'library_filter_sheet.dart';
import 'library_view_settings.dart';
import 'server_library.dart';
import 'shelves.dart';

/// What a [LibraryGridPage] was opened to show.
///
/// Only a **library** gets tabs. A box set and a playlist are drill-downs
/// reached from inside one — they hold a fixed set of items and have no
/// suggestions, favourites or collections of their own, so a tab bar over
/// them would be four rows that can never fill.
///
/// [musicAlbums] is a music genre's tile: a library's albums, narrowed. Not a
/// [collection], whose grid asks for films and would come back empty.
enum LibraryBrowse {
  library,
  collection,
  playlist,
  musicAlbums;

  static LibraryBrowse fromQuery(String? value) => switch (value) {
    'collection' => LibraryBrowse.collection,
    'playlist' => LibraryBrowse.playlist,
    'musicAlbums' => LibraryBrowse.musicAlbums,
    _ => LibraryBrowse.library,
  };
}

/// Bumped by the shell when the Libraries destination is tapped while already
/// on it: the second tap opens the library switcher, the way Search's second
/// tap puts the cursor in the field. A counter, so every re-tap is a change.
final ValueNotifier<int> librarySwitchRequests = ValueNotifier<int>(0);

/// Screen 1e — one library, as a poster grid with filters.
///
/// Three columns on a phone; wider windows add columns rather than stretching
/// the posters, so a poster is always about the same physical size.
class LibraryGridPage extends ConsumerStatefulWidget {
  const LibraryGridPage({
    super.key,
    this.title = 'Movies',
    this.viewId,
    this.browse = LibraryBrowse.library,
    this.onSwitchLibrary,
    this.genre,
  });

  final String title;

  /// Opens the grid already narrowed to this genre — what a tile on the
  /// Genres tab opens. Still an ordinary filter: removable like any other.
  final String? genre;

  /// Set by the Libraries tab, which owns which library is showing and swaps
  /// this page for another when the title's switcher picks one. Null for a
  /// library pushed over the shell, which replaces its own route instead.
  final ValueChanged<String>? onSwitchLibrary;

  /// Which library to show. Null renders the empty state — the screen is
  /// always reached from a library tile, so a null id means the route was
  /// opened directly.
  ///
  /// A collection's id works here too: the server answers `/Items?parentId=`
  /// with the collection's films exactly as it answers with a library's, so
  /// one screen covers both and a box set is browsed rather than played.
  final String? viewId;

  final LibraryBrowse browse;

  @override
  ConsumerState<LibraryGridPage> createState() => _LibraryGridPageState();
}

class _LibraryGridPageState extends ConsumerState<LibraryGridPage>
    with TickerProviderStateMixin {
  /// Empty by default: a library opens showing everything in it. Hiding most
  /// of a collection until the user notices a chip is the wrong first
  /// impression.
  late LibraryFilter _filter = widget.genre == null
      ? LibraryFilter.none
      : LibraryFilter(genres: <String>{widget.genre!});

  LibraryOrdering _ordering = const LibraryOrdering(ServerSort.name);

  /// Whether the one filter the chip row draws directly is on.
  ///
  /// The chip and the sheet's Unwatched checkbox are the same filter rather
  /// than two that happen to agree — ticking either shows the same grid, and
  /// the chip lights up for a choice made in the sheet.
  bool get _unwatchedOnly => _filter.flags.contains(ItemFilter.unplayed);

  TabController? _tabs;

  /// The tabs on show, which depend on what the library holds — and that is
  /// only known once `/UserViews` lands, so they can change once after the
  /// first frame.
  List<_LibraryTab> _shown = _LibraryTab.forKind('');

  bool get _hasTabs =>
      widget.browse == LibraryBrowse.library && widget.viewId != null;

  /// The controller for [tabs], rebuilt when their number changes. The tab
  /// the user was on is kept where it still exists.
  TabController _controllerFor(List<_LibraryTab> tabs) {
    final existing = _tabs;
    if (existing != null && existing.length == tabs.length) return existing;

    final was = existing == null ? _LibraryTab.browse : _shown[existing.index];
    final index = tabs.indexOf(was);
    existing?.dispose();
    return _tabs =
        TabController(
            length: tabs.length,
            initialIndex: index < 0 ? 0 : index,
            vsync: this,
          )
          // The filter button belongs to Browse alone, so a tab change has to
          // rebuild the scaffold that shows or hides it.
          ..addListener(() {
            if (mounted) setState(() {});
          });
  }

  @override
  void initState() {
    super.initState();

    // Any library opened is the one the Libraries tab should come back to,
    // however it was reached. After the frame: a provider must not change
    // while the widget tree is being built.
    final viewId = widget.viewId;
    if (_hasTabs && viewId != null) {
      Future<void>.microtask(() {
        final profileId = ref.read(activeServerProvider)?.profile.id;
        if (!mounted || profileId == null) return;
        ref.read(lastLibraryProvider.notifier).remember(profileId, viewId);
      });
    }

    // Only the Libraries tab's own page answers the shell; a library pushed
    // over it has no destination of its own to be re-tapped.
    if (widget.onSwitchLibrary != null) {
      librarySwitchRequests.addListener(_onSwitchRequested);
    }
  }

  void _onSwitchRequested() {
    final viewId = widget.viewId;
    if (!_hasTabs || viewId == null) return;
    // After the frame: the same tap pops the branch back to this page, and
    // the sheet belongs on top of that, not under a route on its way out.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final chosen = await showLibraryPicker(context, currentId: viewId);
      if (chosen != null && mounted) _switchTo(chosen);
    });
  }

  /// Opens [viewId] in place of the library on screen.
  void _switchTo(String viewId) {
    if (viewId == widget.viewId) return;

    final inTab = widget.onSwitchLibrary;
    if (inTab != null) {
      inTab(viewId);
    } else {
      // Replaced rather than pushed: switching is a sideways move, and back
      // should leave the library screen, not walk through every one tried.
      GoRouter.of(context).pushReplacement('/library', extra: viewId);
    }
  }

  @override
  void dispose() {
    librarySwitchRequests.removeListener(_onSwitchRequested);
    _tabs?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final l10n = AppLocalizations.of(context);
    final viewId = widget.viewId;

    final tabs = _LibraryTab.forKind(_collectionKind());
    if (_hasTabs) {
      _controllerFor(tabs);
      _shown = tabs;
    }

    return Scaffold(
      // Inside the Libraries tab the navigation bar already carries Search;
      // a library pushed over the shell has no bar, so it keeps the button.
      floatingActionButton: _floatingButtons(context),
      appBar: AppBar(
        backgroundColor: scheme.surfaceContainerHigh,
        // The Libraries tab's root has nothing under it to go back to.
        automaticallyImplyLeading: false,
        leading: context.canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: l10n.actionBack,
                onPressed: () => context.pop(),
              )
            : null,
        title: _TitleWithCount(
          count: _countLabel(viewId),
          title: _hasTabs
              ? _LibrarySwitcher(
                  currentId: viewId!,
                  title: _titleFor(ref) ?? widget.title,
                  onSelected: _switchTo,
                )
              : Text(_titleFor(ref) ?? widget.title),
        ),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: l10n.refresh,
            onPressed: () => refreshLibraries(ref),
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: l10n.viewOptions,
            onPressed: _pickView,
          ),
          // Search moved to the FAB: it is the frequent action here, and the
          // top-right corner is the one place a thumb cannot reach. Grid size
          // stays up here — it is set once and then left alone.
        ],
        bottom: _hasTabs
            ? TabBar(
                controller: _tabs,
                // More tabs than fit a phone — four labels like "Suggestions"
                // and "Collections" do not share 360dp readably. Scrolling is the
                // Material answer and the design's series screen already uses
                // a TabBar, so this is the same component doing the same job.
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: <Widget>[
                  for (final _LibraryTab tab in _shown)
                    Tab(text: tab.label(l10n)),
                ],
              )
            : null,
      ),
      // A null id is the route opened directly rather than from a tile. It
      // still draws as a library — chips, count strip, empty grid — because a
      // screen that looks nothing like the one it is supposed to be reads as
      // a failure rather than as an empty library.
      body: viewId == null
          ? _mainTab(null)
          : switch (widget.browse) {
              LibraryBrowse.playlist => _PlaylistItems(playlistId: viewId),
              LibraryBrowse.collection => _mainTab(viewId),
              LibraryBrowse.musicAlbums => _musicTab(
                viewId,
                MusicListing.albums,
              ),
              LibraryBrowse.library => TabBarView(
                controller: _tabs,
                children: <Widget>[
                  for (final _LibraryTab tab in _shown)
                    switch (tab) {
                      _LibraryTab.browse => _mainTab(viewId),
                      _LibraryTab.albums => _musicTab(
                        viewId,
                        MusicListing.albums,
                      ),
                      _LibraryTab.artists => _musicTab(
                        viewId,
                        MusicListing.artists,
                      ),
                      _LibraryTab.songs => _musicTab(
                        viewId,
                        MusicListing.tracks,
                      ),
                      _LibraryTab.suggestions => _SuggestionsTab(
                        viewId: viewId,
                        kind: _collectionKind(),
                      ),
                      _LibraryTab.upcoming => _UpcomingTab(viewId: viewId),
                      _LibraryTab.genres => _GenresTab(
                        viewId: viewId,
                        music: _collectionKind() == 'music',
                      ),
                      _LibraryTab.collections => _CollectionsTab(
                        viewId: viewId,
                      ),
                      _LibraryTab.playlists => const _PlaylistsTab(),
                    },
                ],
              ),
            },
    );
  }

  /// The grid's request, shared by the grid and the count in the title so
  /// both read one answer.
  ///
  /// The narrowing is the server's, not this screen's: a page holds a hundred
  /// of however many the library has, and filtering those would hide nothing
  /// past the hundredth while claiming to have filtered a library.
  AsyncValue<List<ServerItem>> _gridRequest(String? viewId) {
    if (viewId == null) {
      return const AsyncValue<List<ServerItem>>.data(<ServerItem>[]);
    }

    // Only a library groups: a box set's own grid is what the grouping opens.
    var group = false;
    if (widget.browse == LibraryBrowse.library) {
      final grouping = ref.watch(collectionGroupingProvider(viewId));
      // Waited for, or a library that groups would draw every film first.
      if (!grouping.hasValue) {
        return const AsyncValue<List<ServerItem>>.loading();
      }
      group = grouping.requireValue;
    }

    return ref.watch(
      libraryItemsProvider(
        LibraryQuery(
          viewId,
          _ordering.sort,
          order: _ordering.order,
          filter: _filter,
          groupCollections: group,
        ),
      ),
    );
  }

  /// What the title says under the library's name, or null to say nothing.
  ///
  /// Unfiltered, the library's real total — the grid holds one page of it,
  /// and "100 items" over a library of 2,000 is a number that is simply
  /// wrong. Filtered, the server's narrowed answer is only known a page at a
  /// time, so a full page reads "100+" rather than claiming to be all of it.
  String? _countLabel(String? viewId) {
    if (widget.browse == LibraryBrowse.playlist ||
        widget.browse == LibraryBrowse.musicAlbums) {
      return null;
    }

    final l10n = AppLocalizations.of(context);

    // Music counts what the tab on screen lists. Filtered it says nothing: its
    // pages load as they are scrolled to, so no number here would be the total.
    if (viewId != null && _collectionKind() == 'music') {
      final listing = _tabs == null ? null : _shown[_tabs!.index].listing;
      if (listing == null || !_filter.isEmpty) return null;
      final total = ref
          .watch(musicItemCountProvider((viewId: viewId, listing: listing)))
          .value;
      return total == null ? null : l10n.itemCount(total);
    }

    if (viewId != null &&
        _filter.isEmpty &&
        widget.browse == LibraryBrowse.library) {
      final grouped =
          ref.watch(collectionGroupingProvider(viewId)).value ?? false;
      final total = ref
          .watch(
            grouped
                ? libraryGroupedCountProvider(viewId)
                : libraryItemCountProvider(viewId),
          )
          .value;
      // Nothing until the tally lands: "0 items" while it is in flight reads
      // as an empty library.
      return total == null ? null : l10n.itemCount(total);
    }

    final request = _gridRequest(viewId);
    final items = request.value;
    if (items == null) return null;
    if (items.length >= libraryPageSize) {
      return l10n.itemCountAtLeast(items.length);
    }
    // "12 unwatched" only while that is the whole of the narrowing. With a
    // genre or a year on it too, the sentence would be naming one of several
    // constraints and reading as the only one.
    return _filter.count == 1 && _unwatchedOnly
        ? l10n.unwatchedCount(items.length)
        : l10n.itemCount(items.length);
  }

  /// The grid of everything in the library, with the chips above it.
  ///
  /// [viewId] is null only for the route opened with no library behind it,
  /// which still draws the chips and a count of zero.
  Widget _mainTab(String? viewId) {
    final request = _gridRequest(viewId);
    final items = request.value ?? const <ServerItem>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _ActiveFilters(
          filter: _filter,
          onChanged: (next) => setState(() => _filter = next),
        ),
        // The count lives in the title now; a little air keeps the first row
        // of posters off the tab bar when no filter chips sit between them.
        if (_filter.isEmpty) SizedBox(height: context.spacing.sm),
        Expanded(
          child: PosterGrid(
            items: items,
            loading: request.isLoading && items.isEmpty,
            onTap: (item) => openServerItem(context, item),
          ),
        ),
      ],
    );
  }

  /// Albums, artists or songs, with the same chips over them as the main grid.
  Widget _musicTab(String viewId, MusicListing listing) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _ActiveFilters(
          filter: _filter,
          onChanged: (next) => setState(() => _filter = next),
        ),
        if (_filter.isEmpty) SizedBox(height: context.spacing.sm),
        Expanded(
          child: MusicListingView(
            listing: listing,
            query: LibraryQuery(
              viewId,
              _ordering.sort,
              order: _ordering.order,
              filter: _filter,
            ),
          ),
        ),
      ],
    );
  }

  /// The `CollectionType` of the library being shown, which is what names the
  /// first tab. Empty until `/UserViews` lands, and for a drill-down.
  String _collectionKind() {
    final viewId = widget.viewId;
    if (viewId == null) return '';

    final views = ref.watch(serverViewsProvider).value ?? const <LibraryView>[];
    for (final LibraryView v in views) {
      if (v.id == viewId) return v.kind;
    }
    return '';
  }

  /// How the grid is drawn: posters per row, and what each card says.
  ///
  /// Everything applies as it is changed, with the grid behind the sheet
  /// redrawing under it — a choice about how cards look is judged by looking.
  Future<void> _pickView() {
    final kind = _collectionKind();
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      // As tall as its rows: the default stops at 9/16 of the window, which
      // on a phone hides the last switch below the fold.
      isScrollControlled: true,
      builder: (_) => _ViewSheet(
        // Only where a film or a series can belong to a box set. A plain folder
        // calls itself `unknown` and may hold either.
        groupingViewId:
            _hasTabs &&
                (kind == 'movies' || kind == 'tvshows' || kind == 'unknown')
            ? widget.viewId
            : null,
      ),
    );
  }


  /// The library's own name, once the views have loaded.
  String? _titleFor(WidgetRef ref) {
    final viewId = widget.viewId;
    // A collection and a playlist carry their name in the query — neither is
    // in `/UserViews`, so there is nothing to look it up in.
    if (viewId == null || widget.browse != LibraryBrowse.library) return null;

    final views = ref.watch(serverViewsProvider).value ?? const <LibraryView>[];
    for (final LibraryView v in views) {
      if (v.id == viewId) return v.name;
    }
    return null;
  }

  /// Whether the grid with its sort and filters is the one on screen — the
  /// Browse tab, or a box set, which is nothing but that grid.
  bool get _onGrid {
    if (widget.browse == LibraryBrowse.playlist) return false;
    final tabs = _tabs;
    if (tabs == null) return true;
    final tab = _shown[tabs.index];
    return tab == _LibraryTab.browse || tab.listing != null;
  }

  /// The filter button, and Search above it for a library pushed over the
  /// shell — inside the Libraries tab the navigation bar carries Search.
  Widget? _floatingButtons(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final inTab = widget.onSwitchLibrary != null;

    final filter = _onGrid
        ? Badge(
            // The count rides on the button, so a narrowed grid explains
            // itself even with the chips above it scrolled away.
            isLabelVisible: !_filter.isEmpty,
            label: Text('${_filter.count}'),
            child: FloatingActionButton(
              heroTag: 'library-options',
              tooltip: l10n.sortAndFilter,
              onPressed: _pickOptions,
              child: const Icon(Icons.tune_rounded),
            ),
          )
        : null;
    final search = inTab
        ? null
        : FloatingActionButton(
            heroTag: 'library-search',
            tooltip: l10n.navSearch,
            mini: filter != null,
            onPressed: () => context.go('/search'),
            child: const Icon(Icons.search_rounded),
          );

    if (filter == null) return search;
    if (search == null) return filter;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        search,
        SizedBox(height: context.spacing.md),
        filter,
      ],
    );
  }

  Future<void> _pickOptions() async {
    final chosen = await showLibraryOptionsDialog(
      context,
      viewId: widget.viewId,
      ordering: _ordering,
      filter: _filter,
      collectionKind: _collectionKind(),
    );

    if (chosen == null || !mounted) return;
    setState(() {
      _ordering = chosen.ordering;
      _filter = chosen.filter;
    });
  }
}

/// The tabs a library screen carries, in the order Jellyfin's own web
/// client puts them.
///
/// No Favourites tab: starred items are one of the Browse grid's filters
/// already, and a tab that repeats a filter is a label crammed into a phone's
/// width for nothing.
enum _LibraryTab {
  /// Everything in the library, with the sort and filter button.
  browse,

  /// A music library's three listings, in place of [browse].
  albums,
  artists,
  songs,
  suggestions,

  /// What is announced and not yet out. TV only — films have no schedule.
  upcoming,

  /// One tile per genre, each opening the grid narrowed to it.
  genres,
  collections,
  playlists;

  /// The tabs a library of [kind] has. Upcoming only for TV; Genres for the
  /// two kinds whose items the server files by genre. An unknown kind — the
  /// views not loaded yet — gets the tabs every library has.
  ///
  /// Music is its own set. The server has no suggestions or box sets for it,
  /// and its first tab cannot be one grid: an album, an artist and a song are
  /// three different things to go looking for.
  static List<_LibraryTab> forKind(String kind) => kind == 'music'
      ? const <_LibraryTab>[albums, artists, songs, playlists, genres]
      : <_LibraryTab>[
    browse,
    suggestions,
    if (kind == 'tvshows') upcoming,
    if (kind == 'movies' || kind == 'tvshows') genres,
    collections,
    playlists,
  ];

  String label(AppLocalizations l10n) {
    return switch (this) {
      _LibraryTab.browse => l10n.tabBrowse,
      _LibraryTab.albums => l10n.tabAlbums,
      _LibraryTab.artists => l10n.tabArtists,
      _LibraryTab.songs => l10n.tabSongs,
      _LibraryTab.suggestions => l10n.tabSuggestions,
      _LibraryTab.upcoming => l10n.tabUpcoming,
      _LibraryTab.genres => l10n.tabGenres,
      _LibraryTab.collections => l10n.tabCollections,
      _LibraryTab.playlists => l10n.tabPlaylists,
    };
  }

  /// What this tab lists, for the tabs that are a music listing.
  MusicListing? get listing => switch (this) {
    _LibraryTab.albums => MusicListing.albums,
    _LibraryTab.artists => MusicListing.artists,
    _LibraryTab.songs => MusicListing.tracks,
    _ => null,
  };
}

/// Episodes announced and not yet out, under a heading per air date.
class _UpcomingTab extends ConsumerWidget {
  const _UpcomingTab({required this.viewId});

  final String viewId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final scheme = context.colors;
    final request = ref.watch(libraryUpcomingProvider(viewId));
    final items = request.value ?? const <ServerItem>[];

    if (items.isEmpty) {
      return request.isLoading
          ? const Center(child: CircularProgressIndicator())
          : _EmptyNote(text: l10n.noUpcoming);
    }

    final locale = Localizations.localeOf(context).toLanguageTag();
    final dayFormat = DateFormat.MMMMEEEEd(locale);

    // In the order the server sent them, which is soonest first; an episode
    // with no date yet goes under its own heading at the end.
    final byDay = <String, List<ServerItem>>{};
    final undated = <ServerItem>[];
    for (final ServerItem item in items) {
      final date = item.premiereDate;
      if (date == null) {
        undated.add(item);
      } else {
        byDay
            .putIfAbsent(dayFormat.format(date), () => <ServerItem>[])
            .add(item);
      }
    }
    if (undated.isNotEmpty) byDay[l10n.upcomingUndated] = undated;

    return ListView(
      padding: EdgeInsets.only(bottom: spacing.xl + context.systemBottomInset),
      children: <Widget>[
        for (final MapEntry<String, List<ServerItem>> day
            in byDay.entries) ...<Widget>[
          SectionHeader(title: day.key),
          for (final ServerItem episode in day.value)
            ListTile(
              contentPadding: spacing.screenPadding(context.windowSize),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(context.radii.thumb),
                child: SizedBox(
                  width: 96,
                  height: 54,
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      GradientArt(seed: episode.seriesTitle ?? episode.title),
                      RemoteArt(url: artUrlFor(ref, episode, maxWidth: 240)),
                    ],
                  ),
                ),
              ),
              title: Text(
                episode.seriesTitle ?? episode.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                <String>[
                  episodeCode(episode),
                  episode.title,
                ].where((p) => p.isNotEmpty).join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              onTap: () => openServerItem(context, episode),
            ),
        ],
      ],
    );
  }
}

/// A tile per genre, each opening the library's grid narrowed to it.
class _GenresTab extends ConsumerWidget {
  const _GenresTab({required this.viewId, this.music = false});

  final String viewId;

  /// A genre in a music library opens albums rather than the film grid.
  final bool music;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final request = ref.watch(libraryGenresProvider(viewId));
    final genres = request.value ?? const <LibraryGenre>[];
    final source = ref.watch(activeServerProvider);

    if (genres.isEmpty) {
      return request.isLoading
          ? const Center(child: CircularProgressIndicator())
          : _EmptyNote(text: l10n.noGenres);
    }

    final gutter = spacing.screenHorizontal(context.windowSize);

    return GridView.builder(
      padding: EdgeInsets.fromLTRB(
        gutter,
        spacing.md,
        gutter,
        spacing.xl + context.systemBottomInset,
      ),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        childAspectRatio: 16 / 9,
        mainAxisSpacing: spacing.md,
        crossAxisSpacing: spacing.md,
      ),
      itemCount: genres.length,
      itemBuilder: (context, i) {
        final genre = genres[i];
        return ClipRRect(
          borderRadius: context.radii.cardAll,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              GradientArt(seed: genre.name),
              RemoteArt(url: source?.genreImageUrl(genre, maxWidth: 440)),
              // The name has to read over whatever picture is behind it.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[Color(0x00000000), Color(0xB3000000)],
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: EdgeInsets.all(spacing.md),
                  child: Text(
                    genre.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.texts.titleMedium?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              Material(
                type: MaterialType.transparency,
                child: InkWell(
                  // The library's own grid, narrowed by a removable filter
                  // rather than a separate genre screen: sort, filter and
                  // the poster size all work as they do everywhere else.
                  onTap: () => context.push(
                    Uri(
                      path: '/library',
                      queryParameters: <String, String>{
                        'title': genre.name,
                        'browse': music ? 'musicAlbums' : 'collection',
                        'genre': genre.name,
                      },
                    ).toString(),
                    extra: viewId,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// What the server suggests from this library.
///
/// Three shelves everywhere — what was being watched, what is next, what is
/// new — and, for a movie library, the server's own recommendation rows under
/// them. There is no `/Shows/Recommendations`, so a shows library gets the
/// first three and nothing is missing that could have been there.
class _SuggestionsTab extends ConsumerWidget {
  const _SuggestionsTab({required this.viewId, required this.kind});

  final String viewId;
  final String kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = context.spacing;
    final l10n = AppLocalizations.of(context);

    final resume = ref.watch(resumeInViewProvider(viewId));
    final nextUp = ref.watch(nextUpInViewProvider(viewId));
    final latest = ref.watch(latestInViewProvider(viewId));
    final shelves = ref.watch(librarySuggestionsProvider(viewId));

    final hasAnything =
        (resume.value?.isNotEmpty ?? false) ||
        (nextUp.value?.isNotEmpty ?? false) ||
        (latest.value?.isNotEmpty ?? false) ||
        (shelves.value?.isNotEmpty ?? false);

    // Only once every request has answered. A tab that says "nothing to
    // suggest" while four shelves are still in flight is wrong more often
    // than it is right.
    final settled =
        !resume.isLoading &&
        !nextUp.isLoading &&
        !latest.isLoading &&
        !shelves.isLoading;

    if (!hasAnything) {
      return settled
          ? _EmptyNote(text: l10n.noSuggestions)
          : const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: EdgeInsets.only(
        top: spacing.md,
        bottom: spacing.xl + context.systemBottomInset,
      ),
      children: <Widget>[
        // Each header is drawn only with something under it: a title over
        // blank space reads as a shelf that failed to load.
        if (resume.value?.isNotEmpty ?? false) ...<Widget>[
          SectionHeader(title: l10n.continueWatching),
          ServerCardShelf(items: resume),
          SizedBox(height: spacing.sectionGap),
        ],
        if (nextUp.value?.isNotEmpty ?? false) ...<Widget>[
          SectionHeader(title: l10n.nextUp),
          ServerCardShelf(items: nextUp),
          SizedBox(height: spacing.sectionGap),
        ],
        if (latest.value?.isNotEmpty ?? false) ...<Widget>[
          SectionHeader(title: l10n.recentlyAdded),
          ServerPosterShelf(items: latest),
          SizedBox(height: spacing.sectionGap),
        ],
        for (final ServerShelf shelf
            in shelves.value ?? const <ServerShelf>[]) ...<Widget>[
          SectionHeader(title: _shelfTitle(l10n, shelf)),
          ServerPosterShelf(
            items: AsyncValue<List<ServerItem>>.data(shelf.items),
          ),
          SizedBox(height: spacing.sectionGap),
        ],
      ],
    );
  }
}

/// The server's reason, said in the user's language.
///
/// The reason and its subject arrive separately — "SimilarToRecentlyPlayed"
/// and "Dune" — precisely so this sentence can be built here rather than
/// behind the HTTP client. A subject the server did not name, or a reason this
/// app has no wording for, falls back to a plain heading instead of a sentence
/// with a hole in it.
String _shelfTitle(AppLocalizations l10n, ServerShelf shelf) {
  if (shelf.subject.isEmpty) return l10n.suggestedForYou;

  return switch (shelf.kind) {
    SuggestionKind.similarToRecentlyPlayed => l10n.becauseYouWatched(
      shelf.subject,
    ),
    SuggestionKind.similarToLiked => l10n.becauseYouLike(shelf.subject),
    SuggestionKind.directorFromRecentlyPlayed ||
    SuggestionKind.likedDirector => l10n.directedBy(shelf.subject),
    SuggestionKind.actorFromRecentlyPlayed ||
    SuggestionKind.likedActor => l10n.starring(shelf.subject),
    SuggestionKind.unknown => l10n.suggestedForYou,
  };
}

class _CollectionsTab extends ConsumerWidget {
  const _CollectionsTab({required this.viewId});

  final String viewId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final request = ref.watch(libraryCollectionsProvider(viewId));

    return PosterGrid(
      items: request.value ?? const <ServerItem>[],
      loading: request.isLoading,
      emptyText: AppLocalizations.of(context).noCollections,
      onTap: (item) => openServerItem(context, item),
    );
  }
}

/// Every playlist on the server, under whichever library the user is in.
///
/// Not filtered by library, because a playlist is not owned by one: it holds
/// whatever was put in it, from wherever. Showing them all is the truth; a
/// filter would hide most of them under a heading claiming otherwise.
class _PlaylistsTab extends ConsumerWidget {
  const _PlaylistsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final request = ref.watch(serverPlaylistsProvider);

    return PosterGrid(
      items: request.value ?? const <ServerItem>[],
      loading: request.isLoading,
      emptyText: AppLocalizations.of(context).noPlaylists,
      onTap: (item) => openServerPlaylist(context, item),
    );
  }
}

/// What is inside one playlist, in the order it was put there.
class _PlaylistItems extends ConsumerWidget {
  const _PlaylistItems({required this.playlistId});

  final String playlistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final request = ref.watch(playlistItemsProvider(playlistId));

    return PosterGrid(
      items: request.value ?? const <ServerItem>[],
      loading: request.isLoading,
      emptyText: AppLocalizations.of(context).emptyPlaylist,
      onTap: (item) => openServerItem(context, item),
    );
  }
}

/// The poster grid every tab draws.
///
/// Column count is the user's setting; the poster is whatever a cell leaves
/// after the ink ring, so the artwork follows the columns rather than the
/// other way round.
class PosterGrid extends ConsumerWidget {
  const PosterGrid({
    super.key,
    required this.items,
    required this.onTap,
    this.loading = false,
    this.emptyText,
  });

  final List<ServerItem> items;
  final ValueChanged<ServerItem> onTap;
  final bool loading;

  /// Shown when the list is empty and the request has settled. Null draws
  /// nothing, which is what the main grid wants — its count strip above
  /// already says "0 items".
  final String? emptyText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = context.spacing;

    if (items.isEmpty) {
      if (loading) return const Center(child: CircularProgressIndicator());
      final text = emptyText;
      return text == null ? const SizedBox.shrink() : _EmptyNote(text: text);
    }

    final columns = columnsForWidth(
      ref.watch(libraryColumnsProvider),
      MediaQuery.sizeOf(context).width,
    );
    final info = ref.watch(libraryCardInfoProvider);
    final l10n = AppLocalizations.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final gutter =
            (spacing.screenHorizontal(context.windowSize) - spacing.hitInset)
                .clamp(0.0, double.infinity);
        final cell = (constraints.maxWidth - gutter * 2) / columns;
        final posterWidth = (cell - spacing.hitInset * 2).clamp(48.0, 400.0);
        // The design's poster is 108x142; keeping that ratio means five
        // columns look like three, only smaller.
        final posterHeight = posterWidth * 142 / 108;

        return GridView.builder(
          padding: EdgeInsets.fromLTRB(
            gutter,
            0,
            gutter,
            spacing.md + context.systemBottomInset,
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: spacing.sm,
            crossAxisSpacing: 0,
            // Fixed height, not an aspect ratio: the caption is two lines of
            // text, whose height does not scale with the column width.
            mainAxisExtent: PosterTile.outerHeight(
              context,
              posterHeight,
              withCaption: info.caption,
            ),
          ),
          itemCount: items.length,
          itemBuilder: (context, i) => PosterTile(
            item: libraryItemFrom(items[i]),
            caption: info.caption ? cardCaption(items[i], l10n, info) : null,
            badge: info.count ? cardCount(items[i], l10n) : null,
            artUrl: artUrlFor(ref, items[i], maxWidth: 300),
            width: posterWidth,
            posterHeight: posterHeight,
            onTap: () => onTap(items[i]),
          ),
        );
      },
    );
  }
}

/// A centred sentence where a grid would be — an empty tab explains itself
/// rather than showing blank space the user reads as a failure.
class _EmptyNote extends StatelessWidget {
  const _EmptyNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.spacing.screenHorizontal(context.windowSize),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: context.texts.bodyMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// Posters per row, whether collections are grouped, then which facts the
/// cards carry.
class _ViewSheet extends ConsumerWidget {
  const _ViewSheet({this.groupingViewId});

  /// The library the grouping switch applies to. Null leaves the switch out.
  final String? groupingViewId;

  Future<void> _setGrouping(
    BuildContext context,
    WidgetRef ref,
    String viewId,
    bool group,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(collectionGroupingProvider(viewId).notifier).set(group);
    } on ServerException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final columns = ref.watch(libraryColumnsProvider);
    final info = ref.watch(libraryCardInfoProvider);
    final setInfo = ref.read(libraryCardInfoProvider.notifier).set;
    final groupingId = groupingViewId;

    Widget heading(String text) => Padding(
          padding: EdgeInsets.fromLTRB(
            spacing.lg,
            spacing.md,
            spacing.lg,
            spacing.sm,
          ),
          child: Text(
            text,
            style: context.texts.titleSmall
                ?.copyWith(color: context.colors.primary),
          ),
        );

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            heading(l10n.gridSize),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: spacing.lg),
              child: Wrap(
                spacing: spacing.sm,
                runSpacing: spacing.sm,
                children: <Widget>[
                  for (
                    var n = LibraryColumnsController.minColumns;
                    n <= LibraryColumnsController.maxColumns;
                    n++
                  )
                    ChoiceChip(
                      label: Text(l10n.gridColumns(n)),
                      selected: n == columns,
                      onSelected: (_) =>
                          ref.read(libraryColumnsProvider.notifier).set(n),
                    ),
                ],
              ),
            ),
            if (groupingId != null)
              SwitchListTile(
                title: Text(l10n.groupByCollection),
                subtitle: Text(l10n.groupByCollectionSub),
                value:
                    ref.watch(collectionGroupingProvider(groupingId)).value ??
                    false,
                onChanged: (on) => _setGrouping(context, ref, groupingId, on),
              ),
            heading(l10n.showOnCards),
            SwitchListTile(
              title: Text(l10n.cardYear),
              value: info.year,
              onChanged: (on) => setInfo(info.copyWith(year: on)),
            ),
            SwitchListTile(
              title: Text(l10n.cardCount),
              subtitle: Text(l10n.cardCountSub),
              value: info.count,
              onChanged: (on) => setInfo(info.copyWith(count: on)),
            ),
            SwitchListTile(
              title: Text(l10n.cardStatus),
              subtitle: Text(l10n.cardStatusSub),
              value: info.status,
              onChanged: (on) => setInfo(info.copyWith(status: on)),
            ),
          ],
        ),
      ),
    );
  }
}

/// The app bar's title with the item count under it, in the smaller type
/// the server home uses for its host line.
class _TitleWithCount extends StatelessWidget {
  const _TitleWithCount({required this.title, required this.count});

  final Widget title;
  final String? count;

  @override
  Widget build(BuildContext context) {
    final label = count;
    if (label == null) return title;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        title,
        Padding(
          // Under the switcher's text, not under its ink.
          padding: EdgeInsets.symmetric(horizontal: context.spacing.sm),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.texts.labelMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// The library's name in the app bar, which is also how to move to another
/// library: tapping it lists them all.
class _LibrarySwitcher extends ConsumerWidget {
  const _LibrarySwitcher({
    required this.currentId,
    required this.title,
    required this.onSelected,
  });

  final String currentId;
  final String title;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return Semantics(
      button: true,
      hint: l10n.switchLibrary,
      child: InkWell(
        borderRadius: BorderRadius.circular(context.radii.card),
        onTap: () => _open(context),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.spacing.sm,
            vertical: context.spacing.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(Icons.arrow_drop_down_rounded),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    final chosen = await showLibraryPicker(context, currentId: currentId);
    if (chosen != null) onSelected(chosen);
  }
}

/// Lists the server's libraries in a sheet; resolves to the one picked, or
/// null when dismissed.
Future<String?> showLibraryPicker(
  BuildContext context, {
  required String currentId,
}) {
  return showModalBottomSheet<String>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _LibraryPickerSheet(currentId: currentId),
  );
}

class _LibraryPickerSheet extends ConsumerWidget {
  const _LibraryPickerSheet({required this.currentId});

  final String currentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = context.spacing;
    final scheme = context.colors;
    final l10n = AppLocalizations.of(context);
    final views = ref.watch(serverViewsProvider).value ?? const <LibraryView>[];

    return ListView(
      shrinkWrap: true,
      padding: EdgeInsets.only(bottom: spacing.lg),
      children: <Widget>[
        Padding(
          padding: EdgeInsets.fromLTRB(spacing.xl, 0, spacing.xl, spacing.sm),
          child: Text(l10n.switchLibrary, style: context.texts.titleLarge),
        ),
        for (final LibraryView view in views)
          Builder(
            builder: (context) {
              final count = ref.watch(libraryItemCountProvider(view.id)).value;
              final section = librarySectionFrom(view, itemCount: count);
              final selected = view.id == currentId;

              return ListTile(
                contentPadding: EdgeInsets.symmetric(horizontal: spacing.xl),
                selected: selected,
                selectedTileColor: scheme.secondaryContainer,
                leading: Icon(section.icon),
                title: Text(view.name),
                subtitle: count == null
                    ? null
                    : Text(l10n.itemCount(section.itemCount)),
                trailing: selected ? const Icon(Icons.check_rounded) : null,
                onTap: () => Navigator.of(context).pop(view.id),
              );
            },
          ),
      ],
    );
  }
}

/// What the grid is narrowed by, one removable chip per constraint, with a
/// way to clear them all. Nothing at all while nothing is on.
///
/// The dialog behind the filter button is where filters are chosen; this is
/// where they are seen — a count says *that* a library is narrowed, never by
/// what, and the way out of one stale genre should not be the whole dialog.
class _ActiveFilters extends StatelessWidget {
  const _ActiveFilters({required this.filter, required this.onChanged});

  final LibraryFilter filter;
  final ValueChanged<LibraryFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    if (filter.isEmpty) return const SizedBox.shrink();

    final spacing = context.spacing;
    final l10n = AppLocalizations.of(context);
    final padding = spacing.screenPadding(context.windowSize);

    Widget chip(String label, LibraryFilter without) => InputChip(
      label: Text(label),
      onDeleted: () => onChanged(without),
      visualDensity: VisualDensity.compact,
    );

    final chips = <Widget>[
      for (final ItemFilter flag in filter.flags)
        chip(
          flagLabel(flag, l10n),
          filter.copyWith(
            flags: LibraryFilter.toggled(filter.flags, flag, false),
          ),
        ),
      for (final SeriesStatus status in filter.status)
        chip(
          statusLabel(status, l10n),
          filter.copyWith(
            status: LibraryFilter.toggled(filter.status, status, false),
          ),
        ),
      for (final ItemFeature feature in filter.features)
        chip(
          featureLabel(feature, l10n),
          filter.copyWith(
            features: LibraryFilter.toggled(filter.features, feature, false),
          ),
        ),
      for (final String genre in filter.genres)
        chip(
          genre,
          filter.copyWith(
            genres: LibraryFilter.toggled(filter.genres, genre, false),
          ),
        ),
      for (final int year in filter.years)
        chip(
          '$year',
          filter.copyWith(
            years: LibraryFilter.toggled(filter.years, year, false),
          ),
        ),
      for (final String rating in filter.parentalRatings)
        chip(
          rating,
          filter.copyWith(
            parentalRatings: LibraryFilter.toggled(
              filter.parentalRatings,
              rating,
              false,
            ),
          ),
        ),
      for (final String tag in filter.tags)
        chip(
          tag,
          filter.copyWith(tags: LibraryFilter.toggled(filter.tags, tag, false)),
        ),
    ];

    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.fromLTRB(padding.left, 6, padding.right, 2),
        children: <Widget>[
          for (final Widget c in chips) ...<Widget>[
            c,
            SizedBox(width: spacing.sm),
          ],
          TextButton(
            onPressed: () => onChanged(LibraryFilter.none),
            child: Text(l10n.clearAll),
          ),
        ],
      ),
    );
  }
}
