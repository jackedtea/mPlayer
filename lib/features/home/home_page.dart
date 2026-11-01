// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../servers/auto_connect.dart';
import '../../servers/media_library_source.dart';
import '../../servers/server_registry.dart';
import '../../widgets/gradient_art.dart';
import '../../widgets/remote_art.dart';
import '../../widgets/section_header.dart';
import '../servers/server_library.dart';
import '../servers/servers_empty_page.dart';
import '../servers/servers_list_page.dart';
import '../servers/shelves.dart';

/// The Home tab, which has three faces and picks one rather than navigating.
///
/// Nothing configured is the empty state; a server not opened yet this launch
/// is the server list; otherwise it is the server's home. Choosing here keeps
/// the tab's root the same route whichever face is up, so tapping Home in the
/// bar always comes back to *this* — never to a list stacked under it.
class HomeTabPage extends ConsumerWidget {
  const HomeTabPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(connectedServerProvider) != null) return const HomePage();
    if (ref.watch(serverRegistryProvider).hasServer) {
      return const ServersListPage();
    }
    return const ServersEmptyPage();
  }
}

/// A server's home: what was being watched, what is next, and what is new in
/// each library the user has not hidden.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = context.spacing;
    final l10n = AppLocalizations.of(context);
    final views = ref.watch(serverViewsProvider);
    final excluded =
        ref.watch(homeExcludesProvider).value ?? const <String>{};

    return Scaffold(
      appBar: AppBar(
        title: const _ServerTitle(),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: l10n.customizeHome,
            onPressed: () => showHomeCustomizeSheet(context),
          ),
          const _AccountMenu(),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(homeResumeProvider);
          ref.invalidate(serverNextUpProvider);
          ref.invalidate(serverViewsProvider);
          ref.invalidate(latestInViewProvider);
          ref.invalidate(homeExcludesProvider);
          await ref.read(serverViewsProvider.future);
        },
        child: ListView(
          padding: EdgeInsets.only(top: spacing.sm, bottom: spacing.xl),
          children: <Widget>[
            const _ResumeCarousel(),
            _Section(
              title: l10n.nextUp,
              items: ref.watch(serverNextUpProvider),
              cards: true,
            ),
            for (final LibraryView view
                in homeLibraries(views.value ?? const <LibraryView>[]))
              if (!excluded.contains(view.id))
                _Section(
                  title: l10n.recentlyAddedIn(view.name),
                  items: ref.watch(latestInViewProvider(view.id)),
                ),
          ],
        ),
      ),
    );
  }
}

/// The libraries that can have a "Recently added" row at all.
///
/// The same ones the web client offers: a box-set or playlist view holds
/// things the user assembled rather than things the server added, and live
/// TV has no "newest" to speak of.
List<LibraryView> homeLibraries(List<LibraryView> views) {
  const skipped = <String>{'boxsets', 'playlists', 'livetv'};
  return <LibraryView>[
    for (final LibraryView v in views)
      if (!skipped.contains(v.kind)) v,
  ];
}

/// A header over a shelf, drawn only while the shelf has something or is
/// still on its way: a title over blank space reads as a row that failed.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.items, this.cards = false});

  final String title;
  final AsyncValue<List<ServerItem>> items;

  /// Resume-style cards rather than posters.
  final bool cards;

  @override
  Widget build(BuildContext context) {
    final hasItems = items.value?.isNotEmpty ?? false;
    if (!hasItems && !items.isLoading) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(top: context.spacing.sectionGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionHeader(title: title),
          if (cards)
            ServerCardShelf(items: items)
          else
            ServerPosterShelf(items: items),
        ],
      ),
    );
  }
}

/// The ten most recently played items, as a hero carousel.
class _ResumeCarousel extends ConsumerWidget {
  const _ResumeCarousel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final request = ref.watch(homeResumeProvider);
    final items = request.value ?? const <ServerItem>[];
    final compact = context.windowSize == WindowSize.compact;
    final height = compact ? 200.0 : 260.0;

    if (items.isEmpty) {
      if (!request.isLoading) return const SizedBox.shrink();
      return SizedBox(
        height: height,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final padding = EdgeInsets.symmetric(
      horizontal: context.spacing.screenHorizontal(context.windowSize) / 2,
    );
    final children = <Widget>[
      for (final ServerItem item in items) _CarouselCard(item: item),
    ];

    return SizedBox(
      height: height,
      // The hero layout on a phone — one large item with a sliver of each
      // neighbour — and fixed-width cards once there is room for several.
      // The cards draw their own ink: the carousel's would sit over the play
      // button and swallow its taps.
      child: compact
          ? CarouselView.weighted(
              flexWeights: const <int>[1, 7, 1],
              padding: padding,
              enableSplash: false,
              itemSnapping: true,
              children: children,
            )
          : CarouselView(
              itemExtent: 460,
              shrinkExtent: 200,
              padding: padding,
              enableSplash: false,
              itemSnapping: true,
              children: children,
            ),
    );
  }
}

class _CarouselCard extends ConsumerWidget {
  const _CarouselCard({required this.item});

  final ServerItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final art = backdropUrlFor(ref, item, maxWidth: 900) ??
        artUrlFor(ref, item, maxWidth: 600);
    final title = item.seriesTitle ?? item.title;
    final subtitle = <String>[
      if (item.seriesTitle != null) ...<String>[episodeCode(item), item.title],
      remainingLabel(item, l10n),
    ].where((s) => s.isNotEmpty).join(' · ');

    return LayoutBuilder(
      builder: (context, constraints) {
        // A neighbour squeezed to a sliver shows its picture and nothing
        // else: two letters of a title and half a button say nothing.
        final roomy = constraints.maxWidth >= 180;

        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            GradientArt(seed: item.id),
            RemoteArt(url: art),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: <double>[0.35, 1],
                  colors: <Color>[Colors.transparent, Colors.black87],
                ),
              ),
            ),
            Material(
              type: MaterialType.transparency,
              child: InkWell(onTap: () => openServerItem(context, item)),
            ),
            if (roomy)
              Positioned(
                left: spacing.lg,
                right: spacing.lg,
                bottom: spacing.lg,
                child: IgnorePointer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Padding(
                        // Clear of the play button in the corner.
                        padding: const EdgeInsets.only(right: 56),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.texts.titleMedium
                                  ?.copyWith(color: Colors.white),
                            ),
                            if (subtitle.isNotEmpty)
                              Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.texts.bodySmall
                                    ?.copyWith(color: Colors.white70),
                              ),
                          ],
                        ),
                      ),
                      SizedBox(height: spacing.sm),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: item.watchedFraction ?? 0,
                          minHeight: 3,
                          backgroundColor: Colors.white24,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (roomy)
              Positioned(
                right: spacing.md,
                bottom: spacing.lg + spacing.sm,
                child: IconButton.filled(
                  icon: const Icon(Icons.play_arrow_rounded),
                  tooltip: l10n.play,
                  onPressed: () => playServerItem(context, ref, item.id),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// The server's name over its host and the signed-in user.
class _ServerTitle extends ConsumerWidget {
  const _ServerTitle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = context.spacing;
    final scheme = context.colors;
    final profile = ref.watch(serverRegistryProvider).active;
    final username = profile?.username ?? '';

    return Column(
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
            // A long hostname must ellipsize rather than push the app bar's
            // actions off the right edge.
            Flexible(
              child: Text(
                _hostLine(profile?.uri ?? '', username),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// "media.home.lan · minh" — the scheme and port are noise in an app bar.
String _hostLine(String uri, String username) {
  final host = Uri.tryParse(uri)?.host ?? uri;
  return username.isEmpty ? host : '$host · $username';
}

/// The account avatar, which is also the way back to the server list.
class _AccountMenu extends ConsumerWidget {
  const _AccountMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = context.spacing;
    final scheme = context.colors;
    final l10n = AppLocalizations.of(context);
    final username = ref.watch(serverRegistryProvider).active?.username ?? '';

    return Padding(
      padding: EdgeInsets.only(right: spacing.sm),
      child: PopupMenuButton<void>(
        tooltip: l10n.changeServer,
        itemBuilder: (_) => <PopupMenuEntry<void>>[
          PopupMenuItem<void>(
            onTap: () => ref.read(serverSessionProvider.notifier).leave(),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.swap_horiz_rounded),
              title: Text(l10n.changeServer),
            ),
          ),
        ],
        child: CircleAvatar(
          radius: 16,
          backgroundColor: scheme.primaryContainer,
          child: Text(
            // An account with a name that begins with a combining mark still
            // has to yield one grapheme, which `characters` guarantees.
            username.isEmpty ? '?' : username.characters.first.toUpperCase(),
            style: TextStyle(
              color: scheme.onPrimaryContainer,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

/// Which libraries get a "Recently added" row on Home.
Future<void> showHomeCustomizeSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (_) => const _HomeCustomizeSheet(),
  );
}

class _HomeCustomizeSheet extends ConsumerWidget {
  const _HomeCustomizeSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = context.spacing;
    final l10n = AppLocalizations.of(context);
    final views = homeLibraries(
      ref.watch(serverViewsProvider).value ?? const <LibraryView>[],
    );
    final excludes = ref.watch(homeExcludesProvider);
    final excluded = excludes.value;

    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: EdgeInsets.only(bottom: spacing.md),
        children: <Widget>[
          ListTile(
            title: Text(l10n.customizeHome, style: context.texts.titleLarge),
            subtitle: Text(l10n.customizeHomeSub),
          ),
          if (excluded == null)
            Padding(
              padding: EdgeInsets.all(spacing.xl),
              child: Center(
                // A failed read must not draw every switch as "on": that
                // would invite the user to save a list they never saw.
                child: excludes.hasError
                    ? Text(l10n.actionFailed)
                    : const CircularProgressIndicator(),
              ),
            )
          else
            for (final LibraryView view in views)
              SwitchListTile(
                title: Text(view.name),
                value: !excluded.contains(view.id),
                onChanged: (shown) => _set(context, ref, view.id, shown),
              ),
        ],
      ),
    );
  }

  Future<void> _set(
    BuildContext context,
    WidgetRef ref,
    String viewId,
    bool shown,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(homeExcludesProvider.notifier)
          .setShown(viewId, shown: shown);
    } on ServerException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}
