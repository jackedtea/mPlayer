// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/television.dart';
import '../../app/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../servers/auto_connect.dart';
import '../../servers/media_library_source.dart';
import '../../servers/server_registry.dart';
import '../../widgets/gradient_art.dart';
import '../../widgets/remote_art.dart';
import '../../widgets/section_header.dart';
import '../servers/pin_lock.dart';
import '../servers/server_library.dart';
import '../servers/servers_empty_page.dart';
import '../servers/servers_list_page.dart';
import 'favorites_page.dart';
import 'home_hero.dart';
import '../servers/shelves.dart';

/// The Home tab, which has three faces and picks one rather than navigating.
///
/// Nothing configured is the empty state; a server not opened yet this launch
/// is the server list; a PIN-guarded one not unlocked yet is its lock;
/// otherwise it is the server's home. Choosing here keeps
/// the tab's root the same route whichever face is up, so tapping Home in the
/// bar always comes back to *this* — never to a list stacked under it.
class HomeTabPage extends ConsumerWidget {
  const HomeTabPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(connectedServerProvider) != null) return const HomePage();

    final registry = ref.watch(serverRegistryProvider);
    final active = registry.active;
    if (active != null &&
        registry.source != null &&
        ref.watch(serverSessionProvider) &&
        ref.watch(serverLockedProvider)) {
      return PinLockPage(profile: active);
    }
    if (registry.hasServer) return const ServersListPage();
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
    // The phone's carousel shows its neighbours as the cue to swipe; wider
    // than that, and on a television, one item gets the whole width.
    final hero =
        !context.windowSize.isCompact || ref.watch(isTelevisionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const _ServerTitle(),
        actions: <Widget>[
          // Beside pull to refresh, not instead of it: a pull is invisible
          // until someone thinks to try it, and on a desktop there is no
          // finger to pull with.
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: l10n.refresh,
            onPressed: () => refreshHome(ref),
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: l10n.customizeHome,
            onPressed: () => showHomeCustomizeSheet(context),
          ),
          const _AccountMenu(),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => refreshHome(ref),
        child: ListView(
          padding: EdgeInsets.only(
            top: hero ? 0 : spacing.sm,
            bottom: spacing.xl,
          ),
          children: <Widget>[
            if (hero) const HomeHero() else const _ResumeCarousel(),
            _Section(
              title: l10n.nextUp,
              items: ref.watch(serverNextUpProvider),
              cards: true,
            ),
            // Below what is in progress and above what is new: starred is a
            // choice to come back to, which is closer to the first than the
            // second.
            if (ref.watch(homeShowFavouritesProvider).value ?? true)
              _Section(
                title: l10n.favourites,
                items: ref.watch(homeFavouritesProvider),
                onSeeAll: () => context.go('/home/favorites'),
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
  const _Section({
    required this.title,
    required this.items,
    this.cards = false,
    this.onSeeAll,
  });

  final String title;
  final AsyncValue<List<ServerItem>> items;

  /// Resume-style cards rather than posters.
  final bool cards;

  /// Where the header's "See all" goes; null draws no action.
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final hasItems = items.value?.isNotEmpty ?? false;
    if (!hasItems && !items.isLoading) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(top: context.spacing.sectionGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionHeader(
            title: title,
            actionLabel:
                onSeeAll == null ? null : AppLocalizations.of(context).seeAll,
            onAction: onSeeAll,
          ),
          if (cards)
            ServerCardShelf(items: items)
          else
            ServerPosterShelf(items: items),
        ],
      ),
    );
  }
}

/// The ten most recently played items, as a hero carousel with a page
/// indicator under it.
///
/// A [PageView], not Material's `CarouselView`: that one hard-wires its own
/// snapping physics, under which a light flick runs through three or four
/// items — and each item here is a specific film the user is choosing
/// between, so overshooting loses their place. [PageScrollPhysics] moves one
/// page per swipe however hard it is thrown.
class _ResumeCarousel extends ConsumerStatefulWidget {
  const _ResumeCarousel();

  @override
  ConsumerState<_ResumeCarousel> createState() => _ResumeCarouselState();
}

class _ResumeCarouselState extends ConsumerState<_ResumeCarousel> {
  /// Where a looping carousel starts: far enough from page 0 that nobody
  /// swipes back to the wall. The page view itself has no end in either
  /// direction it can be reached from; page `p` shows item `p % count`.
  static const _loopOrigin = 10000;

  PageController? _pages;
  bool _pagesLoop = false;

  /// The page view's own page — past [_loopOrigin] while looping.
  int _page = 0;

  @override
  void dispose() {
    _pages?.dispose();
    super.dispose();
  }

  /// The controller for [fraction], rebuilt only when the window crosses into
  /// a size that needs a different one — `viewportFraction` is fixed for a
  /// controller's lifetime — or when a refresh starts or stops the loop. The
  /// item the user was on is carried across.
  PageController _controllerFor(double fraction, int count) {
    final loop = count > 1;
    final current = _pages;
    if (current != null &&
        current.viewportFraction == fraction &&
        _pagesLoop == loop) {
      return current;
    }

    final index = _page % count;
    _page = loop ? _loopOrigin - _loopOrigin % count + index : 0;
    _pagesLoop = loop;
    final next = PageController(viewportFraction: fraction, initialPage: _page);
    // Disposed after the frame: the old one is still attached to the
    // PageView being replaced until then.
    if (current != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => current.dispose());
    }
    return _pages = next;
  }

  @override
  Widget build(BuildContext context) {
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

    final count = items.length;
    final loop = count > 1;
    // A refresh can return fewer items; the modulo lands on one that exists.
    final index = _page % count;

    return Column(
      children: <Widget>[
        SizedBox(
          height: height,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // The hero layout on a phone — one large item with a sliver of
              // each neighbour — and cards about 460 wide once there is room
              // for several, starting at the left edge like the shelves.
              final fraction = compact
                  ? 0.86
                  : (460 / constraints.maxWidth).clamp(0.2, 0.86);
              final pages = _controllerFor(fraction, count);

              return ScrollConfiguration(
                // A mouse drags it too: on desktop there is no touch, and a
                // carousel that only the dots can move feels broken.
                behavior: ScrollConfiguration.of(context).copyWith(
                  dragDevices: PointerDeviceKind.values.toSet(),
                ),
                child: PageView.builder(
                  controller: pages,
                  padEnds: compact,
                  // Past the last item comes the first again, and before
                  // the first the last: no end to swipe into.
                  itemCount: loop ? null : count,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (context, i) => _CarouselPage(
                    controller: pages,
                    index: i,
                    child: _CarouselCard(item: items[i % count]),
                  ),
                ),
              );
            },
          ),
        ),
        if (loop)
          _PageDots(
            count: count,
            current: index,
            // Within the lap the user is on, so a dot slides the few items
            // between rather than spinning through thousands of pages.
            onSelected: (i) => _pages?.animateToPage(
              _page - index + i,
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
            ),
          ),
      ],
    );
  }
}

/// One page of the carousel: inset from its neighbours, rounded, and a
/// little smaller the further it sits from the centre, so the page in front
/// reads as the one in front.
class _CarouselPage extends StatelessWidget {
  const _CarouselPage({
    required this.controller,
    required this.index,
    required this.child,
  });

  final PageController controller;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        // Before the first layout there is no page to measure against.
        final page = controller.hasClients && controller.position.haveDimensions
            ? controller.page ?? controller.initialPage.toDouble()
            : controller.initialPage.toDouble();
        final distance = (page - index).abs().clamp(0.0, 1.0);

        return Transform.scale(scale: 1 - distance * 0.08, child: child);
      },
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: spacing.xs + 2),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(context.radii.sheet),
          child: child,
        ),
      ),
    );
  }
}

/// Which page is showing, as a row of dots; the current one is a pill.
///
/// Each dot is also a way there — the only one on a desktop without a
/// trackpad gesture, and quicker than six swipes on a phone.
class _PageDots extends StatelessWidget {
  const _PageDots({
    required this.count,
    required this.current,
    required this.onSelected,
  });

  final int count;
  final int current;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return Padding(
      padding: EdgeInsets.only(top: context.spacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          for (var i = 0; i < count; i++)
            Semantics(
              button: true,
              selected: i == current,
              label: '${i + 1} / $count',
              child: InkResponse(
                onTap: () => onSelected(i),
                radius: 12,
                // Wider than the dot itself, so a finger can hit it.
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    width: i == current ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == current
                          ? scheme.primary
                          : scheme.onSurfaceVariant.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
        ],
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
          // Not one of the server's rows — it has nowhere to store this one —
          // so it says it is kept here.
          SwitchListTile(
            title: Text(l10n.favourites),
            subtitle: Text(l10n.onThisDevice),
            value: ref.watch(homeShowFavouritesProvider).value ?? true,
            onChanged: (on) =>
                ref.read(homeShowFavouritesProvider.notifier).set(on),
          ),
          const Divider(height: 1),
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
