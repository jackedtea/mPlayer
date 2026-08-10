// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/player/open_local_video.dart';
import 'tokens.dart';

/// One of the three top-level destinations.
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

const navDestinations = <NavDestination>[
  NavDestination(
    label: 'Storage',
    icon: Icons.folder_outlined,
    selectedIcon: Icons.folder_rounded,
  ),
  NavDestination(
    label: 'Server',
    icon: Icons.dns_outlined,
    selectedIcon: Icons.dns_rounded,
  ),
  NavDestination(
    label: 'Search',
    icon: Icons.search_rounded,
    selectedIcon: Icons.search_rounded,
  ),
];

/// Swaps navigation affordance by window size while keeping the same routes
/// and the same branch state:
///
/// * `< 600`  — [NavigationBar], 80h
/// * `600–1239` — [NavigationRail], 88w, Settings pinned to the bottom
/// * `>= 1240` — standard [NavigationDrawer], 256w
///
/// The shell is an `indexedStack`, so switching destinations preserves each
/// branch's navigation stack and scroll position.
class AdaptiveScaffold extends StatelessWidget {
  const AdaptiveScaffold({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _go(int index) {
    // Tapping the current destination pops that branch back to its root,
    // which is the behaviour users expect from a bottom bar.
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return switch (context.windowSize) {
      WindowSize.compact => _CompactShell(shell: navigationShell, onGo: _go),
      WindowSize.medium => _RailShell(shell: navigationShell, onGo: _go),
      WindowSize.large => _DrawerShell(shell: navigationShell, onGo: _go),
    };
  }
}

class _CompactShell extends StatelessWidget {
  const _CompactShell({required this.shell, required this.onGo});

  final StatefulNavigationShell shell;
  final void Function(int) onGo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: onGo,
        destinations: <Widget>[
          for (final NavDestination d in navDestinations)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selectedIcon),
              label: d.label,
            ),
        ],
      ),
    );
  }
}

class _RailShell extends ConsumerWidget {
  const _RailShell({required this.shell, required this.onGo});

  final StatefulNavigationShell shell;
  final void Function(int) onGo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = context.spacing;
    final scheme = context.colors;

    return Scaffold(
      body: Row(
        children: <Widget>[
          NavigationRail(
            minWidth: 88,
            selectedIndex: shell.currentIndex,
            onDestinationSelected: onGo,
            labelType: NavigationRailLabelType.all,
            leading: Padding(
              padding: EdgeInsets.symmetric(vertical: spacing.md),
              child: FloatingActionButton(
                // Explicit tag: this FAB outlives page transitions, so it
                // would collide with any page-level FAB's default hero tag.
                heroTag: 'rail-open-file',
                onPressed: () => openLocalVideo(context, ref),
                elevation: 0,
                tooltip: 'Open a file or folder',
                child: const Icon(Icons.folder_open_rounded),
              ),
            ),
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: EdgeInsets.only(bottom: spacing.lg),
                  child: IconButton(
                    icon: const Icon(Icons.settings_rounded),
                    tooltip: 'Settings',
                    onPressed: () => context.push('/settings'),
                  ),
                ),
              ),
            ),
            destinations: <NavigationRailDestination>[
              for (final NavDestination d in navDestinations)
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
                for (final NavDestination d in navDestinations)
                  NavigationDrawerDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: Text(d.label),
                  ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    spacing.xl + spacing.xs,
                    spacing.md,
                    spacing.xl + spacing.xs,
                    spacing.sm,
                  ),
                  child: const Divider(),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: spacing.md),
                  child: ListTile(
                    leading: const Icon(Icons.settings_rounded),
                    title: const Text('Settings'),
                    shape: const StadiumBorder(),
                    onTap: () => context.push('/settings'),
                  ),
                ),
              ],
            ),
          ),
          VerticalDivider(width: 1, color: context.semantic.divider),
          Expanded(child: shell),
        ],
      ),
    );
  }
}
