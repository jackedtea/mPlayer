// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/tokens.dart';
import 'player_ui_state.dart';

/// The player's overflow sheet: rotation, lock, aspect, sleep timer, then
/// stats and the settings page below a divider.
class MoreMenu extends ConsumerWidget {
  const MoreMenu({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A2125),
      useSafeArea: true,
      builder: (_) => const MoreMenu(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(playerUiProvider);
    final controller = ref.read(playerUiProvider.notifier);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _Row(
            icon: ui.rotation.icon,
            label: 'Rotation',
            value: ui.rotation.label,
            onTap: controller.cycleRotation,
          ),
          _Row(
            icon: Icons.lock_rounded,
            label: 'Lock player',
            onTap: () {
              controller.toggleLock();
              Navigator.of(context).pop();
            },
          ),
          _Row(
            icon: Icons.aspect_ratio_rounded,
            label: 'Aspect ratio',
            value: ui.aspect.label,
            onTap: controller.cycleAspect,
          ),
          _Row(
            icon: Icons.bedtime_rounded,
            label: 'Sleep timer',
            value: ui.sleepLabel,
            onTap: () => _pickSleepTimer(context, ref),
          ),
          const Divider(height: 1, color: Colors.white24),
          _Row(
            icon: Icons.analytics_rounded,
            label: 'Stats for nerds',
            value: ui.statsVisible ? 'On' : 'Off',
            onTap: () {
              controller.toggleStats();
              Navigator.of(context).pop();
            },
          ),
          _Row(
            icon: Icons.settings_rounded,
            label: 'Player settings',
            onTap: () {
              Navigator.of(context).pop();
              context.push('/settings/player');
            },
          ),
        ],
      ),
    );
  }

  Future<void> _pickSleepTimer(BuildContext context, WidgetRef ref) async {
    const choices = <(String, Duration?)>[
      ('Off', null),
      ('15 minutes', Duration(minutes: 15)),
      ('30 minutes', Duration(minutes: 30)),
      ('60 minutes', Duration(minutes: 60)),
    ];

    final chosen = await showModalBottomSheet<(String, Duration?)>(
      context: context,
      backgroundColor: const Color(0xFF1A2125),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final (String label, Duration? d) in choices)
              ListTile(
                title: Text(label, style: const TextStyle(color: Colors.white)),
                onTap: () => Navigator.of(sheetContext).pop((label, d)),
              ),
          ],
        ),
      ),
    );

    if (chosen == null) return;
    ref.read(playerUiProvider.notifier).setSleepTimer(chosen.$2);
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    required this.onTap,
    this.value,
  });

  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListTile(
        dense: true,
        onTap: onTap,
        contentPadding: EdgeInsets.symmetric(horizontal: context.spacing.xl),
        leading: Icon(icon, color: Colors.white, size: 22),
        title: Text(label, style: const TextStyle(color: Colors.white)),
        trailing: value == null
            ? null
            : Text(
                value!,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
              ),
      ),
    );
  }
}
