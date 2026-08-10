// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/tokens.dart';
import '../../core/models/media_models.dart';
import '../../core/sample_data.dart';
import '../player/open_local_video.dart';
import '../../widgets/continue_watching_card.dart';
import '../../widgets/section_header.dart';
import '../../widgets/source_tile.dart';

/// Screen 1a — the launch destination.
///
/// Deliberately server-free: everything here works with nothing configured.
class StoragePage extends ConsumerWidget {
  const StoragePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = context.spacing;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Storage'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
          SizedBox(width: spacing.sm),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.only(bottom: spacing.xl * 4),
        children: <Widget>[
          const _ContinueWatchingSection(),
          SizedBox(height: spacing.sectionGap),
          const _ThisDeviceSection(),
          SizedBox(height: spacing.sectionGap),
          const _NetworkSection(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => openLocalVideo(context, ref),
        tooltip: 'Open a file or folder',
        child: const Icon(Icons.folder_open_rounded),
      ),
    );
  }
}

class _ContinueWatchingSection extends StatelessWidget {
  const _ContinueWatchingSection();

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final items = SampleData.resumeShelf;
    if (items.isEmpty) return const SizedBox.shrink();

    // The cards carry an ink ring outside their artwork, so the shelf pulls
    // its own padding and gaps in by that much: the artwork still starts at
    // the 16pt screen margin and sits 12pt from its neighbour.
    final inset = spacing.hitInset;
    final sidePadding =
        (spacing.screenHorizontal(context.windowSize) - inset).clamp(0.0, double.infinity);
    final gap = (spacing.cardGap - inset * 2).clamp(0.0, double.infinity);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SectionHeader(title: 'Continue watching'),
        SizedBox(
          height: ContinueWatchingCard.outerHeight(context),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: sidePadding),
            itemCount: items.length,
            separatorBuilder: (_, _) => SizedBox(width: gap),
            itemBuilder: (context, i) => ContinueWatchingCard(
              item: items[i],
              onTap: () => _notYet(context, 'Resume "${items[i].title}"'),
            ),
          ),
        ),
      ],
    );
  }
}

class _ThisDeviceSection extends StatelessWidget {
  const _ThisDeviceSection();

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final scheme = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionHeader(title: 'This device', bottomPadding: spacing.xs + 2),
        for (final DeviceShortcut row in SampleData.deviceShortcuts)
          ListTile(
            contentPadding: spacing.screenPadding(context.windowSize),
            leading: CircleAvatar(
              radius: 20,
              backgroundColor: scheme.primaryContainer,
              child: Icon(row.icon, size: 22, color: scheme.onPrimaryContainer),
            ),
            title: Text(row.title),
            subtitle: Text(row.subtitle),
            trailing: Icon(Icons.chevron_right_rounded, color: scheme.outline),
            onTap: () => _notYet(context, row.title),
          ),
      ],
    );
  }
}

class _NetworkSection extends StatelessWidget {
  const _NetworkSection();

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final padding = spacing.screenPadding(context.windowSize);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionHeader(
          title: 'Network',
          actionLabel: 'Add',
          bottomPadding: spacing.xs + 2,
          onAction: () => _notYet(context, 'Add a network share'),
        ),
        Padding(
          padding: padding,
          child: Column(
            children: <Widget>[
              for (final MediaSourceRef source in SampleData.networkSources) ...<Widget>[
                SourceTile(
                  source: source,
                  onTap: () => _notYet(context, 'Browse ${source.name}'),
                ),
                SizedBox(height: spacing.sm),
              ],
              AddSourceTile(
                title: 'Add SMB, WebDAV or NFS',
                subtitle: 'Or scan the local network',
                onTap: () => _notYet(context, 'Add a network share'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Placeholder feedback for actions whose feature lands in a later build step.
void _notYet(BuildContext context, String what) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('$what — not implemented yet')),
  );
}
