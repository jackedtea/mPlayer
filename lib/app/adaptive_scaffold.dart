// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/music/mini_player.dart';
import '../features/remote/remote_page.dart' show RemoteBar;
import '../features/search/search_page.dart' show searchFocusRequests;
import '../core/updater.dart';
import '../features/servers/library_grid_page.dart' show librarySwitchRequests;
import '../features/servers/server_library.dart' show connectedServerProvider;
import '../features/settings/update_dialog.dart';
import '../l10n/app_localizations.dart';
import 'system_ui.dart';
import 'television.dart';
import 'tokens.dart';

/// One of the five top-level destinations.
@immutable
class NavDestination {
  const NavDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;

  /// Filled variant — the design uses fill *only* for the selected
  /// destination and the play/pause glyph.
  final IconData selectedIcon;
}

/// Built per-frame rather than as a const list: the labels are translated, so
/// they have to be resolved against the current locale.
///
/// **Home · Libraries · Search · Downloads · Settings**, in the order of
/// [AppBranch]. Settings stays in the bar rather than as an icon in the
/// top-right corner, where a thumb cannot reach it on a tall phone.
List<NavDestination> navDestinationsFor(AppLocalizations l10n) {
  return <NavDestination>[
    NavDestination(
      label: l10n.navHome,
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
    ),
    NavDestination(
      label: l10n.libraries,
      icon: Icons.video_library_outlined,
      selectedIcon: Icons.video_library_rounded,
    ),
    NavDestination(
      label: l10n.navSearch,
      icon: Icons.search_rounded,
      selectedIcon: Icons.search_rounded,
    ),
    NavDestination(
      label: l10n.downloads,
      icon: Icons.download_outlined,
      selectedIcon: Icons.download_rounded,
    ),
    NavDestination(
      label: l10n.settings,
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings_rounded,
    ),
  ];
}

/// The shell's branches, in the order the router declares them.
enum AppBranch { home, libraries, search, downloads, settings }

/// Swaps navigation affordance by window size while keeping the same routes
/// and the same branch state:
///
/// * `< 600`  — [NavigationBar], 80h
/// * `600–1239` — [NavigationRail], 88w, Settings pinned to the bottom
/// * `>= 1240` — standard [NavigationDrawer], 256w
///
/// The shell is an `indexedStack`, so switching destinations preserves each
/// branch's navigation stack and scroll position.
///
/// **No navigation at all while Home is choosing a server** — the empty state
/// or the server list. Every other destination browses a server, so offering
/// them before one is open is four tabs that each say "open a server first".
class AdaptiveScaffold extends ConsumerWidget {
  const AdaptiveScaffold({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _go(int index) {
    final again = index == navigationShell.currentIndex;

    // Tapping the current destination pops that branch back to its root,
    // which is the behaviour users expect from a bottom bar.
    navigationShell.goBranch(index, initialLocation: again);

    // And on Search it also puts the cursor in the field, the way Google
    // Play's does: the first tap opens the tab, the second starts typing.
    if (again && index == AppBranch.search.index) {
      searchFocusRequests.value++;
    }

    // On Libraries the second tap opens the switcher.
    if (again && index == AppBranch.libraries.index) {
      librarySwitchRequests.value++;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The shell *is* the app outside the player, so if it is on screen the
    // system bars belong to the user again. Asserting it here rather than
    // trusting the player's teardown makes this self-healing: whatever goes
    // wrong on the way out of a film, arriving anywhere else puts the bars
    // back. Free unless something actually left them hidden.
    //
    // Except while the player is up. The shell stays mounted underneath it and
    // rebuilds whenever anything it watches changes, and every one of those
    // rebuilds would otherwise hand the film's screen back to the system bars.
    if (windowEdges.value != WindowEdges.none) {
      unawaited(restoreAppSystemUi());
    }

    // Only on Home: a route reached some other way with no server — a deep
    // link to Settings, say — keeps its bar, or it would have no way out.
    final choosingServer = navigationShell.currentIndex == AppBranch.home.index &&
        ref.watch(connectedServerProvider) == null;
    // The update check rides on the shell: it is up from launch, inside the
    // navigator a dialog needs, and not under the player — so a prompt never
    // lands on top of a film. One wrapper whatever the face, so its state
    // (and its one check) survives the shell changing shape.
    return _AutomaticUpdateCheck(
      child: choosingServer
          ? Scaffold(
              body: navigationShell,
              // A download can play with no server open, and this face has no
              // bar for the mini player to sit above.
              bottomNavigationBar: miniPlayerInShell(context, ref)
                  ? MiniPlayer(onOpen: () => context.push('/now-playing'))
                  : null,
            )
          // A television always gets the rail, whatever width it reports: a
          // 4K panel at a low density would otherwise be handed the drawer,
          // 256 points of labels across the left of a screen read from a
          // sofa, and a bottom bar is meant for a thumb.
          : ref.watch(isTelevisionProvider)
          ? _RailShell(shell: navigationShell, onGo: _go)
          : switch (context.windowSize) {
              WindowSize.compact =>
                _CompactShell(shell: navigationShell, onGo: _go),
              WindowSize.medium => _RailShell(shell: navigationShell, onGo: _go),
              WindowSize.large =>
                _DrawerShell(shell: navigationShell, onGo: _go),
            },
    );
  }
}

/// Runs the launch's update check once, and offers what it finds.
///
/// Every condition — release build, switched on, a day since the last, not
/// a version the user skipped — is [Updater.checkAutomatically]'s; this only
/// decides where the answer is shown.
class _AutomaticUpdateCheck extends ConsumerStatefulWidget {
  const _AutomaticUpdateCheck({required this.child});

  final Widget child;

  @override
  ConsumerState<_AutomaticUpdateCheck> createState() =>
      _AutomaticUpdateCheckState();
}

class _AutomaticUpdateCheckState extends ConsumerState<_AutomaticUpdateCheck> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  Future<void> _check() async {
    final found = await ref.read(updaterProvider).checkAutomatically();
    if (found == null || !mounted) return;
    await showUpdateDialog(context, found, automatic: true);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _CompactShell extends StatelessWidget {
  const _CompactShell({required this.shell, required this.onGo});

  final StatefulNavigationShell shell;
  final void Function(int) onGo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          RemoteBar(onOpen: () => context.push('/remote')),
          MiniPlayer(onOpen: () => context.push('/now-playing')),
          NavigationBar(
            selectedIndex: shell.currentIndex,
            onDestinationSelected: onGo,
            destinations: <Widget>[
              for (final NavDestination d
                  in navDestinationsFor(AppLocalizations.of(context)))
                NavigationDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selectedIcon),
                  label: d.label,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RailShell extends StatelessWidget {
  const _RailShell({required this.shell, required this.onGo});

  final StatefulNavigationShell shell;
  final void Function(int) onGo;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return Scaffold(
      body: Row(
        children: <Widget>[
          NavigationRail(
            minWidth: 88,
            selectedIndex: shell.currentIndex,
            onDestinationSelected: onGo,
            labelType: NavigationRailLabelType.all,
            destinations: <NavigationRailDestination>[
              for (final NavDestination d in navDestinationsFor(AppLocalizations.of(context)))
                NavigationRailDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selectedIcon),
                  label: Text(d.label),
                ),
            ],
          ),
          VerticalDivider(width: 1, color: context.semantic.divider),
          Expanded(child: shell),
        ],
      ),
      bottomNavigationBar: RemoteBar(onOpen: () => context.push('/remote')),
      backgroundColor: scheme.surface,
    );
  }
}

class _DrawerShell extends StatelessWidget {
  const _DrawerShell({required this.shell, required this.onGo});

  final StatefulNavigationShell shell;
  final void Function(int) onGo;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    return Scaffold(
      body: Row(
        children: <Widget>[
          SizedBox(
            width: 256,
            child: NavigationDrawer(
              selectedIndex: shell.currentIndex,
              onDestinationSelected: onGo,
              children: <Widget>[
                SizedBox(height: spacing.md),
                for (final NavDestination d in navDestinationsFor(AppLocalizations.of(context)))
                  NavigationDrawerDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: Text(d.label),
                  ),
              ],
            ),
          ),
          VerticalDivider(width: 1, color: context.semantic.divider),
          Expanded(child: shell),
        ],
      ),
      bottomNavigationBar: RemoteBar(onOpen: () => context.push('/remote')),
    );
  }
}
