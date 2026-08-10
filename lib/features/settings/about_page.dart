// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';

import '../../app/tokens.dart';
import 'settings_widgets.dart';

/// Screen 1m, About.
///
/// The licences row is real: it opens Flutter's [showLicensePage], which lists
/// every bundled dependency plus the Roboto OFL notice registered in
/// `main.dart`. A GPL app has to be able to show this.
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  static const _version = '1.0.0';
  static const _build = '1';

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final scheme = context.colors;

    return SettingsScaffold(
      title: 'About',
      children: <Widget>[
        SizedBox(height: spacing.xl),
        Center(
          child: Column(
            children: <Widget>[
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(context.radii.action),
                ),
                child: Icon(
                  Icons.play_circle_rounded,
                  size: 44,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              SizedBox(height: spacing.md),
              Text('mPlayer', style: context.texts.titleLarge),
              SizedBox(height: spacing.xs),
              Text(
                'Version $_version · build $_build',
                style: context.texts.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              SizedBox(height: spacing.md),
              Chip(
                avatar: Icon(
                  Icons.check_circle_rounded,
                  size: 18,
                  color: context.semantic.success,
                ),
                label: const Text('Up to date'),
                backgroundColor: scheme.surfaceContainerHigh,
                side: BorderSide.none,
              ),
            ],
          ),
        ),
        SizedBox(height: spacing.xl),
        _Row(
          icon: Icons.system_update_rounded,
          title: 'Check for updates',
          onTap: (c) => notImplemented(c, 'Update check'),
        ),
        _Row(
          icon: Icons.description_rounded,
          title: 'Release notes',
          onTap: (c) => notImplemented(c, 'Release notes'),
        ),
        _Row(
          icon: Icons.bug_report_rounded,
          title: 'Diagnostics',
          onTap: (c) => notImplemented(c, 'Diagnostics'),
        ),
        _Row(
          icon: Icons.gavel_rounded,
          title: 'Open-source licences',
          onTap: (c) => showLicensePage(
            context: c,
            applicationName: 'mPlayer',
            applicationVersion: 'Version $_version · build $_build',
            applicationLegalese:
                'Copyright (C) 2026 Nam\nGPL-3.0-or-later',
          ),
        ),
        _Row(
          icon: Icons.shield_rounded,
          title: 'Privacy',
          onTap: (c) => notImplemented(c, 'Privacy'),
        ),
        _Row(
          icon: Icons.code_rounded,
          title: 'Source code',
          subtitle: 'GPL-3.0-or-later',
          onTap: (c) => notImplemented(c, 'Source repository'),
        ),
        _Row(
          icon: Icons.devices_rounded,
          title: 'This device',
          onTap: (c) => notImplemented(c, 'Device info'),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            spacing.screenHorizontal(context.windowSize),
            spacing.xl,
            spacing.screenHorizontal(context.windowSize),
            spacing.lg,
          ),
          child: Text(
            'mPlayer is not affiliated with, endorsed by, or sponsored by the '
            'Jellyfin, Emby or Plex projects.',
            style: context.texts.bodySmall?.copyWith(color: scheme.outline),
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final void Function(BuildContext) onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: context.spacing.screenPadding(context.windowSize),
      leading: Icon(icon, color: context.colors.onSurfaceVariant),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: context.colors.outline,
      ),
      onTap: () => onTap(context),
    );
  }
}
