// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/tokens.dart';

/// Screen 1l — the settings index.
///
/// Section order is fixed by the design: Appearance, General, Player, Audio,
/// Subtitle, About. Each destination page arrives with build step 7; the rows
/// exist now so the shell is navigable and the order is locked in.
class SettingsIndexPage extends StatelessWidget {
  const SettingsIndexPage({super.key});

  static const _entries = <_SettingsEntry>[
    _SettingsEntry(
      title: 'Appearance',
      subtitle: 'Theme, accent colour, density',
      icon: Icons.palette_rounded,
    ),
    _SettingsEntry(
      title: 'General',
      subtitle: 'Language, startup tab, cache',
      icon: Icons.tune_rounded,
    ),
    _SettingsEntry(
      title: 'Player',
      subtitle: 'Decoding, gestures, streaming quality',
      icon: Icons.play_circle_rounded,
    ),
    _SettingsEntry(
      title: 'Audio',
      subtitle: 'Passthrough, track language, boost',
      icon: Icons.graphic_eq_rounded,
    ),
    _SettingsEntry(
      title: 'Subtitle',
      subtitle: 'Style, language order, sync offset',
      icon: Icons.subtitles_rounded,
    ),
    _SettingsEntry(
      title: 'About',
      subtitle: 'Version, licences, diagnostics',
      icon: Icons.info_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final scheme = context.colors;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Settings'),
      ),
      body: ListView(
        children: <Widget>[
          for (final _SettingsEntry e in _entries)
            ListTile(
              contentPadding: spacing.screenPadding(context.windowSize),
              minVerticalPadding: spacing.lg,
              leading: CircleAvatar(
                radius: 20,
                backgroundColor: scheme.primaryContainer,
                child: Icon(e.icon, size: 22, color: scheme.onPrimaryContainer),
              ),
              title: Text(e.title),
              subtitle: Text(e.subtitle),
              trailing: Icon(Icons.chevron_right_rounded, color: scheme.outline),
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${e.title} — not implemented yet')),
              ),
            ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: spacing.screenHorizontal(context.windowSize),
              vertical: spacing.sm,
            ),
            child: const Divider(),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: spacing.screenHorizontal(context.windowSize),
              vertical: spacing.sm,
            ),
            child: Text(
              'mPlayer 1.0.0 · build 1',
              style: context.texts.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

@immutable
class _SettingsEntry {
  const _SettingsEntry({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;
}
