// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/tokens.dart';
import 'add_server_sheet.dart';

/// Screen 1c — the Server tab with nothing configured.
///
/// This is an opt-in empty state, never a login wall: the copy exists to say
/// local playback already works without a server.
class ServerEmptyPage extends StatelessWidget {
  const ServerEmptyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final scheme = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Server'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
          SizedBox(width: spacing.sm),
        ],
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: spacing.xl + spacing.sm),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(context.radii.sheet),
                      ),
                      child: Icon(
                        Icons.dns_rounded,
                        size: 44,
                        color: scheme.primary,
                      ),
                    ),
                    SizedBox(height: spacing.xl),
                    Text(
                      'No media server yet',
                      textAlign: TextAlign.center,
                      style: context.texts.headlineSmall,
                    ),
                    SizedBox(height: spacing.md),
                    Text(
                      'Everything on this device and your network shares '
                      'already works without one. Add a Jellyfin server to '
                      'sync watch state, metadata and remote access.',
                      textAlign: TextAlign.center,
                      style: context.texts.bodyMedium
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    SizedBox(height: spacing.xl + spacing.xs),
                    FilledButton.icon(
                      onPressed: () => AddServerSheet.show(context),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add Jellyfin server'),
                    ),
                    SizedBox(height: spacing.sm),
                    // Until a real connection exists, this is how the
                    // connected home (1d) is reachable for review.
                    TextButton(
                      onPressed: () => context.push('/server/home'),
                      child: const Text('Preview a connected server'),
                    ),
                    SizedBox(height: spacing.sm),
                    TextButton.icon(
                      onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Network scan — not implemented yet'),
                        ),
                      ),
                      icon: const Icon(Icons.radar_rounded, size: 18),
                      label: const Text('Scan this network'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              spacing.screenHorizontal(context.windowSize),
              0,
              spacing.screenHorizontal(context.windowSize),
              spacing.xl - spacing.xs,
            ),
            child: _InfoCard(
              text: 'Emby and Plex servers can be added here too — '
                  'the tab is not Jellyfin-only.',
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final scheme = context.colors;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.lg,
        vertical: spacing.md,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: context.radii.cardAll,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.info_rounded, size: 20, color: scheme.primary),
          SizedBox(width: spacing.md),
          Expanded(
            child: Text(
              text,
              style: context.texts.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
