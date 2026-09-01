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
import '../../widgets/poster_tile.dart';
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
enum LibraryBrowse {
  library,
  collection,
  playlist;

  static LibraryBrowse fromQuery(String? value) => switch (value) {
        'collection' => LibraryBrowse.collection,
        'playlist' => LibraryBrowse.playlist,
        _ => LibraryBrowse.library,
      };
}

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
  });

  final String title;

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
    with SingleTickerProviderStateMixin {
  /// Empty by default: a library opens showing everything in it. Hiding most
  /// of a collection until the user notices a chip is the wrong first
  /// impression.
  LibraryFilter _filter = LibraryFilter.none;

  LibraryOrdering _ordering = const LibraryOrdering(ServerSort.name);

  /// Whether the one filter the chip row draws directly is on.
  ///
  /// The chip and the sheet's Unwatched checkbox are the same filter rather
  /// than two that happen to agree — ticking either shows the same grid, and
  /// the chip lights up for a choice made in the sheet.
  bool get _unwatchedOnly => _filter.flags.contains(ItemFilter.unplayed);

  TabController? _tabs;

  bool get _hasTabs =>
      widget.browse == LibraryBrowse.library && widget.viewId != null;

  @override
  void initState() {
    super.initState();
    if (_hasTabs) _tabs = TabController(length: _LibraryTab.values.length, vsync: this);
  }

  @override
  void dispose() {
    _tabs?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final l10n = AppLocalizations.of(context);
    final viewId = widget.viewId;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: scheme.surfaceContainerHigh,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(_titleFor(ref) ?? widget.title),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.grid_view_rounded),
            tooltip: l10n.gridSize,
            onPressed: _pickColumns,
          ),
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: l10n.navSearch,
            onPressed: () => context.go('/search'),
          ),
        ],
        bottom: _hasTabs
            ? TabBar(
                controller: _tabs,
                // More tabs than fit a phone, and cramming five labels into
                // 360dp makes every one of them unreadable. Scrolling is the
                // Material answer and the design's series screen already uses
                // a TabBar, so this is the same component doing the same job.
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: <Widget>[
                  for (final _LibraryTab tab in _LibraryTab.values)
                    Tab(text: tab.label(l10n, _collectionKind())),
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
              LibraryBrowse.library => TabBarView(
                  controller: _tabs,
                  children: <Widget>[
                    _mainTab(viewId),
                    _SuggestionsTab(viewId: viewId, kind: _collectionKind()),
                    _FavouritesTab(viewId: viewId),
                    _CollectionsTab(viewId: viewId),
                    const _PlaylistsTab(),
                  ],
                ),
            },
    );
  }

  /// The grid of everything in the library, with the chips above it.
  ///
  /// [viewId] is null only for the route opened with no library behind it,
  /// which still draws the chips and a count of zero.
  Widget _mainTab(String? viewId) {
    final spacing = context.spacing;
    final scheme = context.colors;
    final l10n = AppLocalizations.of(context);

    // The narrowing is the server's, not this screen's: a page holds a
    // hundred of however many the library has, and filtering those would hide
    // nothing past the hundredth while claiming to have filtered a library.
    final request = viewId == null
        ? const AsyncValue<List<ServerItem>>.data(<ServerItem>[])
        : ref.watch(
            libraryItemsProvider(
              LibraryQuery(
                viewId,
                _ordering.sort,
                order: _ordering.order,
                filter: _filter,
              ),
            ),
          );
    final items = request.value ?? const <ServerItem>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: spacing.screenPadding(context.windowSize),
            children: <Widget>[
              FilterChip(
                label: Text(l10n.unwatched),
                selected: _unwatchedOnly,
                onSelected: (v) => setState(() {
                  _filter = _filter.copyWith(
                    flags: LibraryFilter.toggled(
                      _filter.flags,
                      ItemFilter.unplayed,
                      v,
                    ),
                  );
                }),
              ),
              SizedBox(width: spacing.sm),
              _MenuChip(
                label: sortLabel(_ordering.sort, l10n),
                onTap: _pickSort,
              ),
              SizedBox(width: spacing.sm),
              // The count is what makes a narrowed library explain itself:
              // without it the only sign that six filters are on is a grid
              // that looks emptier than the user remembers.
              ActionChip(
                avatar: const Icon(Icons.tune_rounded, size: 18),
                label: Text(
                  _filter.isEmpty ? l10n.filters : '${_filter.count}',
                ),
                tooltip: l10n.filters,
                onPressed: viewId == null ? null : () => _pickFilters(viewId),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            spacing.screenHorizontal(context.windowSize),
            spacing.md,
            spacing.screenHorizontal(context.windowSize),
            spacing.sm,
          ),
          child: Text(
            // "12 unwatched" only while that is the whole of the narrowing.
            // With a genre or a year on it too, the sentence would be naming
            // one of several constraints and reading as the only one.
            _filter.count == 1 && _unwatchedOnly
                ? l10n.unwatchedCount(items.length)
                : l10n.itemCount(items.length),
            style: context.texts.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
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

  Future<void> _pickColumns() async {
    final l10n = AppLocalizations.of(context);
    final current = ref.read(libraryColumnsProvider);

    final chosen = await showModalBottomSheet<int>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (var n = LibraryColumnsController.minColumns;
                n <= LibraryColumnsController.maxColumns;
                n++)
              ListTile(
                leading: const Icon(Icons.grid_view_rounded),
                title: Text(l10n.gridColumns(n)),
                trailing: n == current ? const Icon(Icons.check_rounded) : null,
                onTap: () => Navigator.of(sheetContext).pop(n),
              ),
          ],
        ),
      ),
    );

    if (chosen == null) return;
    await ref.read(libraryColumnsProvider.notifier).set(chosen);
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

  Future<void> _pickSort() async {
    final chosen = await showLibrarySortSheet(
      context,
      current: _ordering,
      collectionKind: _collectionKind(),
    );

    if (chosen == null || !mounted) return;
    setState(() => _ordering = chosen);
  }

  Future<void> _pickFilters(String viewId) async {
    final chosen = await showLibraryFilterSheet(
      context,
      viewId: viewId,
      current: _filter,
      collectionKind: _collectionKind(),
    );

    if (chosen == null || !mounted) return;
    setState(() => _filter = chosen);
  }
}

/// The tabs a library screen carries, in the order Jellyfin's own clients use.
enum _LibraryTab {
  /// Everything in the library. Named after what the library holds, because
  /// "All" over a shelf of films says less than "Movies" does.
  all,
  suggestions,
  favourites,
  collections,
  playlists;

  String label(AppLocalizations l10n, String collectionKind) {
    return switch (this) {
      _LibraryTab.all => switch (collectionKind) {
          'movies' => l10n.tabMovies,
          'tvshows' => l10n.tabShows,
          // A music library, a folder, or a library whose type has not
          // arrived yet. "All" is true of every one of them.
          _ => l10n.tabItems,
        },
      _LibraryTab.suggestions => l10n.tabSuggestions,
      _LibraryTab.favourites => l10n.tabFavourites,
      _LibraryTab.collections => l10n.tabCollections,
      _LibraryTab.playlists => l10n.tabPlaylists,
    };
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

    final hasAnything = (resume.value?.isNotEmpty ?? false) ||
        (nextUp.value?.isNotEmpty ?? false) ||
        (latest.value?.isNotEmpty ?? false) ||
        (shelves.value?.isNotEmpty ?? false);

    // Only once every request has answered. A tab that says "nothing to
    // suggest" while four shelves are still in flight is wrong more often
    // than it is right.
    final settled = !resume.isLoading &&
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
          ServerPosterShelf(items: AsyncValue<List<ServerItem>>.data(shelf.items)),
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
    SuggestionKind.similarToRecentlyPlayed =>
      l10n.becauseYouWatched(shelf.subject),
    SuggestionKind.similarToLiked => l10n.becauseYouLike(shelf.subject),
    SuggestionKind.directorFromRecentlyPlayed ||
    SuggestionKind.likedDirector =>
      l10n.directedBy(shelf.subject),
    SuggestionKind.actorFromRecentlyPlayed ||
    SuggestionKind.likedActor =>
      l10n.starring(shelf.subject),
    SuggestionKind.unknown => l10n.suggestedForYou,
  };
}

class _FavouritesTab extends ConsumerWidget {
  const _FavouritesTab({required this.viewId});

  final String viewId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final request = ref.watch(libraryFavouritesProvider(viewId));

    return PosterGrid(
      items: request.value ?? const <ServerItem>[],
      loading: request.isLoading,
      emptyText: AppLocalizations.of(context).noFavourites,
      onTap: (item) => openServerItem(context, item),
    );
  }
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
            mainAxisExtent: PosterTile.outerHeight(context, posterHeight),
          ),
          itemCount: items.length,
          itemBuilder: (context, i) => PosterTile(
            item: libraryItemFrom(items[i]),
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
          style: context.texts.bodyMedium
              ?.copyWith(color: context.colors.onSurfaceVariant),
        ),
      ),
    );
  }
}

/// Chip that opens a menu — the design draws these with a trailing caret.
class _MenuChip extends StatelessWidget {
  const _MenuChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(label),
          const SizedBox(width: 2),
          const Icon(Icons.expand_more_rounded, size: 18),
        ],
      ),
      onPressed: onTap,
    );
  }
}
