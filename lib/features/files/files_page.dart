// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/tokens.dart';
import '../../l10n/app_localizations.dart';
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
        title: Text(AppLocalizations.of(context).navStorage),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            tooltip: AppLocalizations.of(context).settings,
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
          // One "This device", not a media-index section and a granted-folders
          // section side by side. That split is an Android storage detail, and
          // reading it as two peers is the screen's main source of noise: both
          // are folders on this phone, so both are rows in one list.
          const _DeviceSection(),
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
              tooltip: AppLocalizations.of(context).openFile,
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
    //
    // Files and the network shares it lists, and nothing else. A server keeps
    // its own watch state — gathered from every device the user owns, not
    // just this one — and shows it on the Server tab, so a film continued on
    // the television would turn up here as a second, staler entry saying
    // something different about the same film.
    final points = <ResumePoint>[
      for (final ResumePoint p in ref.watch(resumePointsProvider).value ??
          const <ResumePoint>[])
        if (p.kind != SourceKind.jellyfin) p,
    ];
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
          thumbnailPath: p.thumbnailPath,
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
        SectionHeader(
          title: AppLocalizations.of(context).continueWatching,
          // Only offered while there is something to clear, which is also
          // the only time this section is drawn at all — and offered as an
          // icon. Spelt out it sat level with the two "Add" links below it,
          // which put the one destructive action on the screen among the
          // invitations to add things.
          trailing: IconButton(
            icon: const Icon(Icons.delete_sweep_rounded),
            tooltip: AppLocalizations.of(context).clearContinueWatchingTitle,
            onPressed: () => _clearContinueWatching(context, ref),
          ),
        ),
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

/// Forgets every saved position, after asking.
///
/// Asked because it cannot be undone and the shelf is the only record: the
/// positions live on this device, and nothing on a share or a server carries
/// a copy to restore them from.
Future<void> _clearContinueWatching(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.clearContinueWatchingTitle),
      // Says what is *not* touched as well as what is. "Clear" next to a
      // shelf of films is easy to read as "delete the films".
      content: Text(l10n.clearContinueWatchingBody),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.clearAll),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  // Clears the stills with the points; a frame left behind belongs to
  // nothing and would never be swept.
  await ref.read(resumeRepositoryProvider).clear();
  ref.invalidate(resumePointsProvider);

  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(l10n.continueWatchingCleared)),
  );
}

/// Everything readable on this machine, as a single list.
///
/// Android splits its storage two ways: the media index knows about most
/// videos, and whatever it missed — a folder with a `.nomedia` in it, a
/// container MediaScanner would not classify — has to be handed over one
/// folder at a time through the system picker. That is a platform detail, not
/// a shape the screen should take, so both kinds arrive as rows in the same
/// list and the picker is the last row of it.
class _DeviceSection extends ConsumerWidget {
  const _DeviceSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = context.spacing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionHeader(
          title: AppLocalizations.of(context).thisDevice,
          bottomPadding: spacing.xs + 2,
        ),
        // Only Android needs the media index; every other platform can read
        // the filesystem, and the browser opens there directly.
        if (MediaStoreSource.isSupported)
          const _IndexedFolders()
        else
          const _DesktopFolders(),
        // Granted folders stand on their own permission, so they are listed
        // whether or not the media index was ever allowed.
        if (SafSource.isSupported) const _GrantedFolders(),
      ],
    );
  }
}

/// The folders Android's media index reports.
class _IndexedFolders extends ConsumerWidget {
  const _IndexedFolders();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final access = ref.watch(mediaAccessProvider).value ?? MediaAccess.none;
    if (access == MediaAccess.none) {
      return _PermissionPrompt(onGrant: () => _requestAccess(ref));
    }

    final folders = ref.watch(mediaFoldersProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Partial access is a state of this list, so it is reported on the
        // list rather than in the section heading — one banner carrying both
        // the explanation and the way out, instead of a heading action and a
        // loose paragraph beneath it saying what that action was for.
        if (access == MediaAccess.partial)
          _PartialAccessBanner(onSelectMore: () => _requestAccess(ref)),
        ...switch (folders) {
          AsyncError(:final error) => <Widget>[_Message(text: '$error')],
          AsyncData(:final value) when value.isEmpty => <Widget>[
              _Message(text: l10n.noVideosOnDevice),
            ],
          AsyncData(:final value) => <Widget>[
              for (final MediaFolder folder in value)
                _FolderTile(
                  icon: Icons.folder_rounded,
                  title: folder.name,
                  // The full path truncated into meaninglessness at this
                  // width — `/storage/emulated/0/DCIM/Cam…` identifies
                  // nothing. Two segments is what the user recognises; the
                  // rest is the same prefix on every row.
                  subtitle: '${l10n.videoCount(folder.videoCount)}'
                      ' · ${_shortPath(folder.path)}',
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

/// Folders the user granted through the system picker, and the row that grants
/// another.
class _GrantedFolders extends ConsumerWidget {
  const _GrantedFolders();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folders = ref.watch(safFoldersProvider).value ?? const <SafFolder>[];
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final SafFolder folder in folders)
          _FolderTile(
            // A different glyph from the indexed rows, because these behave
            // differently: they can be handed back.
            icon: Icons.folder_open_rounded,
            title: folder.name,
            subtitle: l10n.grantedFolder,
            trailing: IconButton(
              icon: const Icon(Icons.close_rounded),
              tooltip: l10n.removeFolder,
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
        // Closes the list as a row rather than as a dashed card under a
        // heading that already said "Add". One invitation, at the end of the
        // thing it adds to.
        _AddFolderTile(onTap: () => _addFolder(ref)),
      ],
    );
  }
}

Future<void> _addFolder(WidgetRef ref) async {
  final folder = await ref.read(safSourceProvider).pickFolder();
  if (folder == null) return; // cancelled
  ref.invalidate(safFoldersProvider);
}

/// Shows the system dialog, then re-reads what was actually granted.
Future<void> _requestAccess(WidgetRef ref) async {
  await ref.read(mediaStoreSourceProvider).requestPermission();
  ref
    ..invalidate(mediaAccessProvider)
    ..invalidate(mediaFoldersProvider);
}

/// Windows, Linux and macOS read the filesystem directly — no media index,
/// no permission prompt.
class _DesktopFolders extends ConsumerWidget {
  const _DesktopFolders();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folders =
        ref.watch(deviceFoldersProvider).value ?? const <DeviceFolder>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final DeviceFolder folder in folders)
          _FolderTile(
            icon: folder.icon,
            title: folder.label,
            subtitle: folder.subtitle,
            onTap: () => context.push(
              '/browse?source=${LocalSource.sourceId}'
              '&path=${Uri.encodeComponent(folder.path)}',
            ),
          ),
      ],
    );
  }
}

/// The last two segments of a path — `DCIM/Camera` out of
/// `/storage/emulated/0/DCIM/Camera`. Reads both separators, so the same row
/// works on Windows.
String _shortPath(String path) {
  final parts = <String>[
    for (final String part in path.split(RegExp(r'[/\\]')))
      if (part.isNotEmpty) part,
  ];
  if (parts.length <= 2) return parts.join('/');
  return parts.sublist(parts.length - 2).join('/');
}

/// One folder row. Every list on this screen uses it, so the indexed folders,
/// the granted ones and the desktop drives read as the same kind of thing.
class _FolderTile extends StatelessWidget {
  const _FolderTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  /// Defaults to the chevron; a granted folder puts its release button here.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return ListTile(
      contentPadding: context.spacing.screenPadding(context.windowSize),
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: scheme.primaryContainer,
        child: Icon(icon, size: 22, color: scheme.onPrimaryContainer),
      ),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing:
          trailing ?? Icon(Icons.chevron_right_rounded, color: scheme.outline),
      onTap: onTap,
    );
  }
}

/// The row that hands another folder over.
class _AddFolderTile extends StatelessWidget {
  const _AddFolderTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final l10n = AppLocalizations.of(context);

    return ListTile(
      contentPadding: context.spacing.screenPadding(context.windowSize),
      // Outlined rather than filled, so the invitation stays quieter than the
      // folders it sits under.
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outlineVariant),
          shape: BoxShape.circle,
        ),
        child:
            Icon(Icons.add_rounded, size: 22, color: scheme.onSurfaceVariant),
      ),
      title: Text(
        l10n.addFolder,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style:
            context.texts.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
      ),
      subtitle: Text(
        l10n.addFolderSubtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.texts.bodySmall?.copyWith(color: scheme.outline),
      ),
      onTap: onTap,
    );
  }
}

/// Says why the list is short, and offers the way out in the same breath.
class _PartialAccessBanner extends StatelessWidget {
  const _PartialAccessBanner({required this.onSelectMore});

  final VoidCallback onSelectMore;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final scheme = context.colors;

    return Padding(
      padding: spacing.screenPadding(context.windowSize),
      child: Container(
        padding: EdgeInsets.fromLTRB(
          spacing.md,
          spacing.xs,
          spacing.xs,
          spacing.xs,
        ),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: context.radii.cardAll,
        ),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.info_outline_rounded,
              size: 20,
              color: scheme.onSurfaceVariant,
            ),
            SizedBox(width: spacing.md),
            Expanded(
              child: Text(
                AppLocalizations.of(context).partialAccessNotice,
                style: context.texts.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
            SizedBox(width: spacing.xs),
            TextButton(
              onPressed: onSelectMore,
              child: Text(AppLocalizations.of(context).selectMore),
            ),
          ],
        ),
      ),
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
    final l10n = AppLocalizations.of(context);

    return Padding(
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
            Text(l10n.mediaAccessTitle, style: context.texts.bodyLarge),
            SizedBox(height: spacing.xs),
            Text(
              l10n.mediaAccessBody,
              style: context.texts.bodySmall
                  ?.copyWith(color: context.colors.onSurfaceVariant),
            ),
            SizedBox(height: spacing.md),
            FilledButton(
              onPressed: onGrant,
              child: Text(l10n.allowAccess),
            ),
          ],
        ),
      ),
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
          title: AppLocalizations.of(context).network,
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
              // The dashed card is the empty state, not a permanent footer.
              // Once there is a share to look at, the heading's "Add" is the
              // whole of the invitation and the card was only repeating it at
              // four times the height.
              if (registry.configs.isEmpty)
                AddSourceTile(
                  title: AppLocalizations.of(context).addShareTitle,
                  subtitle: AppLocalizations.of(context).addShareSubtitle,
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
        tooltip: AppLocalizations.of(context).shareOptions,
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
              title: Text(AppLocalizations.of(context).editShare),
              subtitle: Text(AppLocalizations.of(context).editShareSubtitle),
              onTap: () {
                Navigator.of(sheetContext).pop();
                SourceSheet.showEdit(context, config);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_rounded),
              title: Text(AppLocalizations.of(context).removeShare),
              subtitle: Text(AppLocalizations.of(context).removeShareSubtitle),
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
    SnackBar(content: Text(AppLocalizations.of(context).notImplemented(what))),
  );
}
