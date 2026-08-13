// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/tokens.dart';
import '../../core/models/library_models.dart';
import '../../sources/local_source.dart' show formatBytes;
import '../../sources/media_source.dart';
import '../../sources/source_registry.dart';
import 'browse_controller.dart';

/// Screen 1b — browsing a share or a local folder.
///
/// One screen for every filesystem-shaped source (SMB, WebDAV, NFS, device
/// storage): they differ only in the breadcrumb root and the icon, never in
/// layout.
class BrowserPage extends ConsumerStatefulWidget {
  const BrowserPage({super.key, required this.sourceId, this.path = ''});

  final String sourceId;
  final String path;

  @override
  ConsumerState<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends ConsumerState<BrowserPage> {
  bool _gridView = false;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final scheme = context.colors;

    final location =
        BrowseLocation(sourceId: widget.sourceId, path: widget.path);
    final listing = ref.watch(directoryListingProvider(location));
    final registry = ref.watch(sourceRegistryProvider);
    final source = registry.drivers[widget.sourceId];

    final rootLabel =
        source is BrowsableSource ? source.rootLabel : widget.sourceId;
    final segments = breadcrumbSegments(widget.path);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: scheme.surfaceContainerHigh,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(segments.isEmpty ? rootLabel : segments.last),
        actions: <Widget>[
          IconButton(
            icon: Icon(
              _gridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
            ),
            tooltip: _gridView ? 'List view' : 'Grid view',
            onPressed: () => setState(() => _gridView = !_gridView),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () =>
                ref.invalidate(directoryListingProvider(location)),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            color: scheme.surfaceContainerHigh,
            padding: EdgeInsets.fromLTRB(
              spacing.screenHorizontal(context.windowSize),
              0,
              spacing.screenHorizontal(context.windowSize),
              spacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _Breadcrumb(
                  icon: source?.kind.icon ?? Icons.folder_rounded,
                  root: rootLabel,
                  segments: segments,
                ),
                SizedBox(height: spacing.xs),
                _MetaStrip(listing: listing.value),
              ],
            ),
          ),
        ),
      ),
      body: listing.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          message: error is MediaSourceException
              ? error.message
              : 'Could not read this folder.\n$error',
          onRetry: () => ref.invalidate(directoryListingProvider(location)),
        ),
        data: (data) {
          if (data.entries.isEmpty) return const _EmptyState();
          return _gridView
              ? _EntryGrid(entries: data.entries, onOpen: _open)
              : ListView.builder(
                  itemCount: data.entries.length,
                  itemBuilder: (context, i) =>
                      _EntryRow(entry: data.entries[i], onOpen: _open),
                );
        },
      ),
    );
  }

  void _open(BrowseEntry entry) {
    if (entry.isFolder) {
      context.push(
        '/browse?source=${Uri.encodeComponent(widget.sourceId)}'
        '&path=${Uri.encodeComponent(entry.path)}',
      );
      return;
    }

    if (!entry.isPlayable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${entry.name} is not a video file')),
      );
      return;
    }

    _play(entry);
  }

  Future<void> _play(BrowseEntry entry) async {
    final source = ref.read(sourceRegistryProvider).drivers[widget.sourceId];
    if (source == null) return;

    try {
      final media = await source.resolve(
        MediaRef(
          sourceId: widget.sourceId,
          itemId: entry.path,
          title: entry.name,
        ),
      );
      if (!mounted) return;
      await context.push('/player', extra: media);
    } on MediaSourceException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

/// `lan · media / films / 2024` — the root is primary, separators are outline,
/// the current folder is the only one in medium weight.
class _Breadcrumb extends StatelessWidget {
  const _Breadcrumb({
    required this.icon,
    required this.root,
    required this.segments,
  });

  final IconData icon;
  final String root;
  final List<String> segments;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final spacing = context.spacing;
    const size = 13.0;

    return SizedBox(
      height: 20,
      child: ListView(
        scrollDirection: Axis.horizontal,
        // Keeps the current folder visible when the path is long.
        reverse: true,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 15, color: scheme.primary),
              SizedBox(width: spacing.xs + 2),
              Text(root, style: TextStyle(fontSize: size, color: scheme.primary)),
              for (final (int i, String segment) in segments.indexed) ...<Widget>[
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: spacing.xs + 1),
                  child: Text(
                    '/',
                    style: TextStyle(fontSize: size, color: scheme.outline),
                  ),
                ),
                Text(
                  segment,
                  style: TextStyle(
                    fontSize: size,
                    color: i == segments.length - 1
                        ? scheme.onSurface
                        : scheme.onSurfaceVariant,
                    fontWeight: i == segments.length - 1
                        ? FontWeight.w500
                        : FontWeight.w400,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaStrip extends StatelessWidget {
  const _MetaStrip({required this.listing});

  final BrowseListing? listing;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final data = listing;

    final left = data == null
        ? 'Reading…'
        : '${data.folderCount} folders · ${data.fileCount} files'
            '${data.totalBytes > 0 ? ' · ${formatBytes(data.totalBytes)}' : ''}';

    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            left,
            style: context.texts.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
        Icon(Icons.bolt_rounded, size: 15, color: scheme.primary),
        Text(
          'Direct play',
          style: context.texts.bodySmall?.copyWith(
            color: scheme.primary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry, required this.onOpen});

  final BrowseEntry entry;
  final void Function(BrowseEntry) onOpen;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final scheme = context.colors;

    return InkWell(
      onTap: () => onOpen(entry),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: spacing.rowMinHeight),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: spacing.screenHorizontal(context.windowSize),
            vertical: spacing.sm,
          ),
          child: Row(
            children: <Widget>[
              _EntryLeading(entry: entry),
              SizedBox(width: spacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      entry.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.texts.bodyLarge
                          ?.copyWith(color: scheme.onSurface),
                    ),
                    if (entry.detail.isNotEmpty)
                      Text(
                        entry.detail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.texts.bodySmall?.copyWith(
                          color: entry.needsTranscode
                              ? scheme.error
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              if (entry.isFolder)
                Icon(Icons.chevron_right_rounded, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}

class _EntryLeading extends StatelessWidget {
  const _EntryLeading({required this.entry});

  final BrowseEntry entry;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final radii = context.radii;

    switch (entry.kind) {
      case BrowseEntryKind.folder:
        return Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: radii.chipAll,
          ),
          child: Icon(
            Icons.folder_rounded,
            size: 24,
            color: scheme.onPrimaryContainer,
          ),
        );
      case BrowseEntryKind.video:
        // No thumbnail. A filesystem source has no artwork to show, and the
        // gradient placeholder reads as a real still — it makes every file
        // look like it has a preview that simply failed to load, and makes
        // two different files look meaningfully different when the colour is
        // only a hash of the name.
        //
        // Server sources keep their artwork: there the image is real. Local
        // thumbnails would need frame extraction, which is a separate job.
        return Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: radii.chipAll,
          ),
          child: Icon(
            Icons.movie_rounded,
            size: 24,
            color: scheme.primary,
          ),
        );
      case BrowseEntryKind.subtitle:
      case BrowseEntryKind.other:
        // Sidecar files get a neutral tile: they are context, not content.
        return Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: radii.chipAll,
          ),
          child: Icon(
            entry.kind == BrowseEntryKind.subtitle
                ? Icons.subtitles_rounded
                : Icons.insert_drive_file_rounded,
            size: 22,
            color: scheme.onSurfaceVariant,
          ),
        );
    }
  }
}

class _EntryGrid extends StatelessWidget {
  const _EntryGrid({required this.entries, required this.onOpen});

  final List<BrowseEntry> entries;
  final void Function(BrowseEntry) onOpen;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final radii = context.radii;

    return GridView.builder(
      padding: EdgeInsets.all(spacing.screenHorizontal(context.windowSize)),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        mainAxisSpacing: spacing.md,
        crossAxisSpacing: spacing.md,
        mainAxisExtent: 140,
      ),
      itemCount: entries.length,
      itemBuilder: (context, i) {
        final entry = entries[i];
        return InkWell(
          onTap: () => onOpen(entry),
          borderRadius: radii.cardAll,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: ClipRRect(
                  borderRadius: radii.cardAll,
                  // Icons here too, for the same reason as the list rows: a
                  // filesystem source has no artwork, and a gradient would
                  // pretend otherwise.
                  child: ColoredBox(
                    color: context.colors.surfaceContainerLow,
                    child: Center(
                      child: Icon(
                        switch (entry.kind) {
                          BrowseEntryKind.folder => Icons.folder_rounded,
                          BrowseEntryKind.video => Icons.movie_rounded,
                          BrowseEntryKind.subtitle => Icons.subtitles_rounded,
                          BrowseEntryKind.other =>
                            Icons.insert_drive_file_rounded,
                        },
                        size: 32,
                        color: context.colors.primary,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: spacing.xs + 2),
              Text(
                entry.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.texts.bodySmall
                    ?.copyWith(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.cloud_off_rounded,
              size: 44,
              color: context.colors.onSurfaceVariant,
            ),
            SizedBox(height: spacing.lg),
            Text(
              message,
              textAlign: TextAlign.center,
              style: context.texts.bodyMedium,
            ),
            SizedBox(height: spacing.lg),
            // Inline retry, never a modal — a dead share must not block the
            // rest of the app.
            FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.restart_alt_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'This folder is empty',
        style: context.texts.bodyMedium
            ?.copyWith(color: context.colors.onSurfaceVariant),
      ),
    );
  }
}
