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
import '../../sources/media_source.dart';
import '../../sources/source_config.dart';
import '../../sources/source_registry.dart';
import '../player/open_local_video.dart';
import 'source_sheet.dart';
import '../../widgets/continue_watching_card.dart';
import '../../widgets/section_header.dart';
import '../../widgets/source_tile.dart';

/// Screen 1a — the launch destination.
///
/// Deliberately server-free: everything here works with nothing configured.
class FilesPage extends ConsumerWidget {
  const FilesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = context.spacing;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Files'),
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
      // At medium width the navigation rail already carries this action as its
      // leading button (design 1j), so a page FAB would duplicate it.
      floatingActionButton: context.windowSize.isMedium
          ? null
          : FloatingActionButton(
              heroTag: 'storage-open-file',
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
            onTap: () => row.icon == Icons.download_for_offline_rounded
                ? context.push('/downloads')
                : context.push('/browse?name=This%20device'),
          ),
      ],
    );
  }
}

class _NetworkSection extends ConsumerWidget {
  const _NetworkSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = context.spacing;
    final padding = spacing.screenPadding(context.windowSize);
    final registry = ref.watch(sourceRegistryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionHeader(
          title: 'Network',
          actionLabel: 'Add',
          bottomPadding: spacing.xs + 2,
          onAction: () => SourceSheet.showAdd(context),
        ),
        Padding(
          padding: padding,
          child: Column(
            children: <Widget>[
              for (final SourceConfig config in registry.configs) ...<Widget>[
                _ConfiguredSourceTile(
                  config: config,
                  // A kind with no driver yet is listed but cannot be opened.
                  browsable: registry.drivers[config.id] is BrowsableSource,
                ),
                SizedBox(height: spacing.sm),
              ],
              AddSourceTile(
                title: 'Add SMB, WebDAV or NFS',
                subtitle: 'Or scan the local network',
                onTap: () => SourceSheet.showAdd(context),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ConfiguredSourceTile extends ConsumerWidget {
  const _ConfiguredSourceTile({
    required this.config,
    required this.browsable,
  });

  final SourceConfig config;
  final bool browsable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SourceTile(
      source: MediaSourceRef(
        id: config.id,
        kind: config.kind,
        name: config.name,
        detail: browsable
            ? config.uri
            : '${config.kind.label} — driver not available yet',
        online: browsable,
      ),
      onTap: browsable
          ? () => context.push(
                '/browse?source=${Uri.encodeComponent(config.id)}',
              )
          : null,
      trailing: IconButton(
        icon: const Icon(Icons.more_vert_rounded),
        tooltip: 'Share options',
        onPressed: () => _showOptions(context, ref),
      ),
    );
  }

  void _showOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.edit_rounded),
              title: const Text('Edit share'),
              subtitle: const Text('Change its name, address or credentials'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                SourceSheet.showEdit(context, config);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_rounded),
              title: const Text('Remove share'),
              subtitle: const Text('Its saved password is deleted too'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                ref.read(sourceRegistryProvider.notifier).remove(config.id);
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Placeholder feedback for actions whose feature lands in a later build step.
void _notYet(BuildContext context, String what) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('$what — not implemented yet')),
  );
}
