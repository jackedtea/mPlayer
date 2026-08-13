// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/tokens.dart';
import '../../core/models/media_models.dart';
import '../../core/resume_repository.dart';
import '../../sources/local_source.dart';
import '../../sources/media_store_source.dart';
import '../../sources/saf_source.dart';
import '../player/playback_state.dart' show formatDuration;
import 'device_folders.dart';
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
          const _FoldersSection(),
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

class _ContinueWatchingSection extends ConsumerWidget {
  const _ContinueWatchingSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = context.spacing;

    // Real resume points now. An empty shelf renders nothing at all rather
    // than an empty row with a heading — there is nothing to continue.
    final points = ref.watch(resumePointsProvider).value ?? const <ResumePoint>[];
    if (points.isEmpty) return const SizedBox.shrink();

    final items = <ResumeItem>[
      for (final ResumePoint p in points)
        ResumeItem(
          id: p.key,
          title: p.title,
          sourceKind: p.kind,
          sourceLabel: p.kind.label,
          remaining: '${formatDuration(p.remaining)} left',
          quality: '',
          progress: p.progress,
        ),
    ];

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
              onTap: () => _resume(context, ref, points[i]),
            ),
          ),
        ),
      ],
    );
  }
}

class _ThisDeviceSection extends ConsumerWidget {
  const _ThisDeviceSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = context.spacing;
    final scheme = context.colors;

    // Only Android needs the media index; every other platform can read the
    // filesystem, and the browser opens there directly.
    if (!MediaStoreSource.isSupported) {
      return const _DesktopDeviceSection();
    }

    final granted = ref.watch(mediaPermissionProvider).value ?? false;
    if (!granted) {
      return _PermissionPrompt(
        onGrant: () async {
          await ref.read(mediaStoreSourceProvider).requestPermission();
          ref.invalidate(mediaPermissionProvider);
        },
      );
    }

    final folders = ref.watch(mediaFoldersProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionHeader(title: 'This device', bottomPadding: spacing.xs + 2),
        ...switch (folders) {
          AsyncError(:final error) => <Widget>[
              _Message(text: '$error'),
            ],
          AsyncData(:final value) when value.isEmpty => <Widget>[
              const _Message(
                text: 'No videos found on this device yet.',
              ),
            ],
          AsyncData(:final value) => <Widget>[
              for (final MediaFolder folder in value)
                ListTile(
                  contentPadding: spacing.screenPadding(context.windowSize),
                  leading: CircleAvatar(
                    radius: 20,
                    backgroundColor: scheme.primaryContainer,
                    child: Icon(
                      Icons.folder_rounded,
                      size: 22,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  title: Text(folder.name),
                  subtitle: Text(
                    '${folder.videoCount} videos · ${folder.path}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: scheme.outline,
                  ),
                  onTap: () => context.push(
                    '/browse?source=${MediaStoreSource.sourceId}'
                    '&path=${Uri.encodeComponent(folder.id)}',
                  ),
                ),
            ],
          _ => <Widget>[
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
        },
      ],
    );
  }
}

/// Folders the user granted through the system picker.
///
/// The escape hatch for everything the media index cannot see: a folder with a
/// `.nomedia` file in it, or containers MediaScanner refused to classify. Only
/// shown on Android, where that limitation exists.
class _FoldersSection extends ConsumerWidget {
  const _FoldersSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!SafSource.isSupported) return const SizedBox.shrink();

    final spacing = context.spacing;
    final scheme = context.colors;
    final folders = ref.watch(safFoldersProvider).value ?? const <SafFolder>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionHeader(
          title: 'Folders',
          actionLabel: 'Add',
          bottomPadding: spacing.xs + 2,
          onAction: () => _addFolder(context, ref),
        ),
        for (final SafFolder folder in folders)
          ListTile(
            contentPadding: spacing.screenPadding(context.windowSize),
            leading: CircleAvatar(
              radius: 20,
              backgroundColor: scheme.primaryContainer,
              child: Icon(
                Icons.folder_open_rounded,
                size: 22,
                color: scheme.onPrimaryContainer,
              ),
            ),
            title: Text(folder.name),
            subtitle: const Text('Granted folder'),
            trailing: IconButton(
              icon: const Icon(Icons.close_rounded),
              tooltip: 'Remove folder',
              onPressed: () async {
                await ref.read(safSourceProvider).release(folder.treeUri);
                ref.invalidate(safFoldersProvider);
              },
            ),
            onTap: () => context.push(
              '/browse?source=${SafSource.sourceId}'
              '&path=${Uri.encodeComponent(folder.treeUri)}',
            ),
          ),
        if (folders.isEmpty)
          Padding(
            padding: spacing.screenPadding(context.windowSize),
            child: AddSourceTile(
              title: 'Add a folder',
              subtitle: 'For videos the media index does not list',
              onTap: () => _addFolder(context, ref),
            ),
          ),
      ],
    );
  }

  Future<void> _addFolder(BuildContext context, WidgetRef ref) async {
    final folder = await ref.read(safSourceProvider).pickFolder();
    if (folder == null) return; // cancelled
    ref.invalidate(safFoldersProvider);
  }
}

/// Windows, Linux and macOS read the filesystem directly — no media index,
/// no permission prompt.
class _DesktopDeviceSection extends ConsumerWidget {
  const _DesktopDeviceSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = context.spacing;
    final scheme = context.colors;
    final folders = ref.watch(deviceFoldersProvider).value ??
        const <DeviceFolder>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionHeader(title: 'This device', bottomPadding: spacing.xs + 2),
        for (final DeviceFolder folder in folders)
          ListTile(
            contentPadding: spacing.screenPadding(context.windowSize),
            leading: CircleAvatar(
              radius: 20,
              backgroundColor: scheme.primaryContainer,
              child: Icon(
                folder.icon,
                size: 22,
                color: scheme.onPrimaryContainer,
              ),
            ),
            title: Text(folder.label),
            subtitle: Text(
              folder.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Icon(Icons.chevron_right_rounded, color: scheme.outline),
            onTap: () => context.push(
              '/browse?source=${LocalSource.sourceId}'
              '&path=${Uri.encodeComponent(folder.path)}',
            ),
          ),
      ],
    );
  }
}

/// Asks before showing an empty list. An unexplained blank section reads as a
/// broken app rather than a permission that was never granted.
class _PermissionPrompt extends StatelessWidget {
  const _PermissionPrompt({required this.onGrant});

  final Future<void> Function() onGrant;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionHeader(title: 'This device', bottomPadding: spacing.xs + 2),
        Padding(
          padding: spacing.screenPadding(context.windowSize),
          child: Container(
            padding: EdgeInsets.all(spacing.lg),
            decoration: BoxDecoration(
              color: context.colors.surfaceContainerLow,
              borderRadius: context.radii.cardAll,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Allow mPlayer to find your videos',
                  style: context.texts.bodyLarge,
                ),
                SizedBox(height: spacing.xs),
                Text(
                  'Android does not let apps browse storage directly, so the '
                  'system media index is used instead.',
                  style: context.texts.bodySmall
                      ?.copyWith(color: context.colors.onSurfaceVariant),
                ),
                SizedBox(height: spacing.md),
                FilledButton(
                  onPressed: onGrant,
                  child: const Text('Allow access'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.spacing.screenHorizontal(context.windowSize),
        vertical: context.spacing.sm,
      ),
      child: Text(
        text,
        style: context.texts.bodySmall
            ?.copyWith(color: context.colors.onSurfaceVariant),
      ),
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

/// Reopens a shelf item where it was left off.
///
/// The resume position itself comes from `resolveWithResume`, so this only has
/// to find the source and hand over — and report inline if the file has since
/// moved or the share is unreachable.
Future<void> _resume(
  BuildContext context,
  WidgetRef ref,
  ResumePoint point,
) async {
  final source = ref.read(mediaSourcesProvider)[point.sourceId];
  if (source == null) {
    _notYet(context, '${point.kind.label} is not available');
    return;
  }

  try {
    final media = await resolveWithResume(
      ref,
      source,
      MediaRef(
        sourceId: point.sourceId,
        itemId: point.itemId,
        title: point.title,
      ),
    );
    if (!context.mounted) return;
    await context.push('/player', extra: media);
  } on MediaSourceException catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(e.message)));
  }
}

/// Placeholder feedback for actions whose feature lands in a later build step.
void _notYet(BuildContext context, String what) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('$what — not implemented yet')),
  );
}
