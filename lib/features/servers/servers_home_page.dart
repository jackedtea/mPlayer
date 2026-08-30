// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/tokens.dart';
import '../../core/models/library_models.dart';
import '../../l10n/app_localizations.dart';
import '../../servers/media_library_source.dart';
import '../../servers/server_registry.dart';
import '../../widgets/section_header.dart';
import 'server_library.dart';
import 'shelves.dart';

/// Screen 1d — the Server tab once a server is configured.
///
/// Reached from the empty state (1c) after a successful connection. Kept as a
/// separate page rather than a branch inside 1c so the empty state stays the
/// simple thing it is.
class ServersHomePage extends ConsumerStatefulWidget {
  const ServersHomePage({super.key});

  @override
  ConsumerState<ServersHomePage> createState() => _ServersHomePageState();
}

class _ServersHomePageState extends ConsumerState<ServersHomePage> {
  int _filter = 0;

  /// The library the filter row has selected, or null for "All".
  String? _selectedViewId() {
    final views = ref.watch(serverViewsProvider).value ?? const <LibraryView>[];
    // Index 0 is "All"; the rest line up with the views behind them.
    if (_filter <= 0 || _filter > views.length) return null;
    return views[_filter - 1].id;
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final scheme = context.colors;
    final profile = ref.watch(serverRegistryProvider).active;
    final username = profile?.username ?? '';

    return Scaffold(
      appBar: AppBar(
        // Not a back button. When a server is configured this screen *is* the
        // Server tab's root, so there was nothing under it to pop and the
        // arrow did nothing at all — what it should have opened is the list
        // of servers.
        leading: Builder(
          builder: (context) {
            // The server list is this screen's root now, so back always has
            // somewhere to go. Guarded anyway: a deep link straight to
            // `/servers/home` has nothing under it, and a dead arrow is worse
            // than no arrow.
            if (!context.canPop()) return const SizedBox.shrink();

            return IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              tooltip: AppLocalizations.of(context).actionBack,
              onPressed: () => context.pop(),
            );
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(profile?.name ?? ''),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: context.semantic.success,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: spacing.xs + 1),
                // A long hostname must ellipsize rather than push the app
                // bar's actions off the right edge.
                Flexible(
                  child: Text(
                    _hostLine(profile?.uri ?? '', username),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.cast_rounded),
            tooltip: AppLocalizations.of(context).cast,
            onPressed: () => _notYet(context, 'Cast'),
          ),
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: AppLocalizations.of(context).searchThisServer,
            onPressed: () => context.go('/search'),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: spacing.sm),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: scheme.primaryContainer,
              child: Text(
                // An account with a name that begins with a combining mark
                // still has to yield one grapheme, which `characters` is what
                // guarantees.
                username.isEmpty
                    ? '?'
                    : username.characters.first.toUpperCase(),
                style: TextStyle(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.only(bottom: spacing.xl),
        children: <Widget>[
          _FilterChips(
            selected: _filter,
            onSelected: (i) => setState(() => _filter = i),
          ),
          SizedBox(height: spacing.sm),
          SectionHeader(title: AppLocalizations.of(context).continueWatching),
          const _ResumeShelf(),
          SizedBox(height: spacing.sectionGap),
          SectionHeader(title: AppLocalizations.of(context).nextUp),
          const _NextUpShelf(),
          SizedBox(height: spacing.sectionGap),
          SectionHeader(title: AppLocalizations.of(context).recentlyAdded),
          _RecentlyAddedShelf(viewId: _selectedViewId()),
          SizedBox(height: spacing.sectionGap),
          SectionHeader(title: AppLocalizations.of(context).libraries),
          const _LibraryGrid(),
        ],
      ),
    );
  }
}

/// "media.home.lan · minh" — the scheme and port are noise in an app bar.
String _hostLine(String uri, String username) {
  final host = Uri.tryParse(uri)?.host ?? uri;
  return username.isEmpty ? host : '$host · $username';
}

class _FilterChips extends ConsumerWidget {
  const _FilterChips({required this.selected, required this.onSelected});

  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = context.spacing;
    final views = ref.watch(serverViewsProvider).value ?? const <LibraryView>[];

    // One chip per library, after "All". A server with a single library gets
    // no chips at all: a filter row with one option filters nothing.
    final labels = <String>[
      AppLocalizations.of(context).allSources,
      for (final LibraryView v in views) v.name,
    ];
    if (views.length < 2) return const SizedBox.shrink();

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: spacing.screenPadding(context.windowSize),
        children: <Widget>[
          for (final (int i, String label) in labels.indexed)
            Padding(
              padding: EdgeInsets.only(right: spacing.sm),
              child: FilterChip(
                label: Text(label),
                selected: i == selected,
                onSelected: (_) => onSelected(i),
              ),
            ),
        ],
      ),
    );
  }
}

/// What the user was in the middle of.
class _ResumeShelf extends ConsumerWidget {
  const _ResumeShelf();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ServerCardShelf(items: ref.watch(serverResumeProvider));
  }
}

/// The next unwatched episode of each series in progress.
class _NextUpShelf extends ConsumerWidget {
  const _NextUpShelf();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ServerCardShelf(items: ref.watch(serverNextUpProvider));
  }
}

class _RecentlyAddedShelf extends ConsumerWidget {
  const _RecentlyAddedShelf({this.viewId});

  /// Null means every library, which is what the "All" chip selects.
  final String? viewId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = viewId;
    return ServerPosterShelf(
      items: scope == null
          ? ref.watch(serverLatestProvider)
          : ref.watch(latestInViewProvider(scope)),
    );
  }
}

class _LibraryGrid extends ConsumerWidget {
  const _LibraryGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = context.spacing;
    final scheme = context.colors;
    final request = ref.watch(serverViewsProvider);
    final views = request.value ?? const <LibraryView>[];

    if (views.isEmpty) {
      if (!request.isLoading) return const SizedBox.shrink();
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Padding(
      padding: spacing.screenPadding(context.windowSize),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 260,
          mainAxisExtent: 76,
          mainAxisSpacing: spacing.md,
          crossAxisSpacing: spacing.md,
        ),
        itemCount: views.length,
        itemBuilder: (context, i) {
          final LibraryView view = views[i];
          // A request of its own per library, so the tiles draw immediately
          // and the counts fill in behind them.
          final count = ref.watch(libraryItemCountProvider(view.id)).value;
          final LibrarySection section =
              librarySectionFrom(view, itemCount: count);
          return Material(
            color: scheme.surfaceContainerLow,
            borderRadius: context.radii.cardAll,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              // Every library opens the same grid; what is inside it is the
              // view's own id, not a guess from its name.
              onTap: () => context.push('/library', extra: view.id),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: spacing.lg),
                child: Row(
                  children: <Widget>[
                    Icon(section.icon, color: scheme.primary),
                    SizedBox(width: spacing.md),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            section.name,
                            style: context.texts.bodyLarge,
                          ),
                          // Nothing at all until the count is known: a
                          // library labelled "0 items" while its tally is in
                          // flight reads as an empty library.
                          if (count != null)
                            Text(
                              AppLocalizations.of(
                                context,
                              ).itemCount(section.itemCount),
                              style: context.texts.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

void _notYet(BuildContext context, String what) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('$what — not implemented yet')),
  );
}
