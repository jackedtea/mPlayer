// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/tokens.dart';
import '../../core/models/library_models.dart';
import '../../core/sample_library.dart';
import '../../widgets/gradient_art.dart';

/// Screen 1b — browsing a share or a local folder.
///
/// One screen for every filesystem-shaped source (SMB, WebDAV, NFS, device
/// storage): they differ only in the breadcrumb root and the icon, never in
/// layout. The listing is placeholder data until the drivers land.
class BrowserPage extends StatefulWidget {
  const BrowserPage({
    super.key,
    required this.sourceName,
    required this.sourceIcon,
  });

  final String sourceName;
  final IconData sourceIcon;

  @override
  State<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends State<BrowserPage> {
  bool _gridView = false;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final scheme = context.colors;
    final entries = SampleLibrary.shareListing;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: scheme.surfaceContainerHigh,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(SampleLibrary.breadcrumb.last),
        actions: <Widget>[
          IconButton(
            icon: Icon(
              _gridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
            ),
            tooltip: _gridView ? 'List view' : 'Grid view',
            onPressed: () => setState(() => _gridView = !_gridView),
          ),
          IconButton(
            icon: const Icon(Icons.sort_rounded),
            tooltip: 'Sort',
            onPressed: () => _notYet(context, 'Sort'),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert_rounded),
            tooltip: 'More',
            onPressed: () => _notYet(context, 'Folder actions'),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
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
                  icon: widget.sourceIcon,
                  root: widget.sourceName,
                  path: SampleLibrary.breadcrumb,
                ),
                SizedBox(height: spacing.sm),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        SampleLibrary.shareMeta,
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
                ),
              ],
            ),
          ),
        ),
      ),
      body: _gridView
          ? _EntryGrid(entries: entries)
          : ListView.builder(
              itemCount: entries.length,
              itemBuilder: (context, i) => _EntryRow(entry: entries[i]),
            ),
    );
  }
}

/// `lan · media / films / 2024` — the root is primary, separators are outline,
/// the current folder is the only one in medium weight.
class _Breadcrumb extends StatelessWidget {
  const _Breadcrumb({
    required this.icon,
    required this.root,
    required this.path,
  });

  final IconData icon;
  final String root;
  final List<String> path;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final spacing = context.spacing;
    const size = 13.0;

    return SizedBox(
      height: 20,
      child: ListView(
        scrollDirection: Axis.horizontal,
        reverse: true, // keep the current folder visible when the path is long
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 15, color: scheme.primary),
              SizedBox(width: spacing.xs + 2),
              Text(
                root,
                style: TextStyle(fontSize: size, color: scheme.primary),
              ),
              for (final (int i, String segment) in path.indexed) ...<Widget>[
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
                    color: i == path.length - 1
                        ? scheme.onSurface
                        : scheme.onSurfaceVariant,
                    fontWeight:
                        i == path.length - 1 ? FontWeight.w500 : FontWeight.w400,
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

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry});

  final BrowseEntry entry;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final scheme = context.colors;

    return InkWell(
      onTap: () => _notYet(context, entry.name),
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
                          // A file that will not direct-play is worth
                          // spotting before opening it.
                          color: entry.needsTranscode
                              ? scheme.error
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_vert_rounded),
                tooltip: 'More',
                onPressed: () => _notYet(context, 'Actions for ${entry.name}'),
              ),
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
        return ClipRRect(
          borderRadius: BorderRadius.circular(radii.thumb),
          child: SizedBox(
            width: 64,
            height: 40,
            child: GradientArt(seed: entry.name),
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
  const _EntryGrid({required this.entries});

  final List<BrowseEntry> entries;

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
        childAspectRatio: 16 / 11,
      ),
      itemCount: entries.length,
      itemBuilder: (context, i) {
        final entry = entries[i];
        return InkWell(
          onTap: () => _notYet(context, entry.name),
          borderRadius: radii.cardAll,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: ClipRRect(
                  borderRadius: radii.cardAll,
                  child: entry.kind == BrowseEntryKind.video
                      ? GradientArt(seed: entry.name)
                      : ColoredBox(
                          color: context.colors.surfaceContainerLow,
                          child: Center(
                            child: Icon(
                              entry.kind == BrowseEntryKind.folder
                                  ? Icons.folder_rounded
                                  : Icons.subtitles_rounded,
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

void _notYet(BuildContext context, String what) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('$what — not implemented yet')),
  );
}
