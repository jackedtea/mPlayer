// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/tokens.dart';
import '../../core/models/library_models.dart';
import '../../core/sample_library.dart';

/// Screen 1i — offline copies.
///
/// Status is carried by colour as well as words: green for available, error
/// for blocked, primary for active. The colours come from the scheme, so this
/// screen needs no dark-mode variant of its own.
class DownloadsPage extends StatelessWidget {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final downloads = SampleLibrary.downloads;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Downloads'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.more_vert_rounded),
            tooltip: 'More',
            onPressed: () => _notYet(context, 'Download settings'),
          ),
        ],
      ),
      body: downloads.isEmpty
          ? const _EmptyState()
          : ListView.separated(
              padding: EdgeInsets.all(
                spacing.screenHorizontal(context.windowSize),
              ),
              itemCount: downloads.length,
              separatorBuilder: (_, _) => SizedBox(height: spacing.sm),
              itemBuilder: (context, i) => _DownloadTile(item: downloads[i]),
            ),
    );
  }
}

class _DownloadTile extends StatelessWidget {
  const _DownloadTile({required this.item});

  final DownloadItem item;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final scheme = context.colors;

    return Container(
      padding: EdgeInsets.all(spacing.lg),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: context.radii.cardAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.texts.bodyLarge,
                ),
              ),
              _TrailingAction(item: item),
            ],
          ),
          SizedBox(height: spacing.xs),
          Text(
            item.detail,
            style: context.texts.bodySmall?.copyWith(color: _detailColor(context)),
          ),
          if (item.status == DownloadStatus.inProgress) ...<Widget>[
            SizedBox(height: spacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: item.progress,
                minHeight: 4,
                backgroundColor: scheme.surfaceContainerHighest,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _detailColor(BuildContext context) {
    return switch (item.status) {
      DownloadStatus.completed => context.semantic.success,
      DownloadStatus.queued => context.colors.error,
      DownloadStatus.inProgress => context.colors.onSurfaceVariant,
    };
  }
}

class _TrailingAction extends StatelessWidget {
  const _TrailingAction({required this.item});

  final DownloadItem item;

  @override
  Widget build(BuildContext context) {
    switch (item.status) {
      case DownloadStatus.inProgress:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              '${(item.progress * 100).round()}%',
              style: context.texts.bodySmall
                  ?.copyWith(color: context.colors.onSurfaceVariant),
            ),
            IconButton(
              icon: const Icon(Icons.pause_circle_rounded),
              tooltip: 'Pause',
              onPressed: () => _notYet(context, 'Pause download'),
            ),
          ],
        );
      case DownloadStatus.completed:
        return IconButton(
          icon: const Icon(Icons.check_circle_rounded),
          color: context.semantic.success,
          tooltip: 'Available offline',
          onPressed: () => _notYet(context, 'Manage download'),
        );
      case DownloadStatus.queued:
        return IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Cancel',
          onPressed: () => _notYet(context, 'Cancel download'),
        );
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final scheme = context.colors;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.download_for_offline_rounded,
              size: 48,
              color: scheme.outline,
            ),
            SizedBox(height: spacing.lg),
            Text('Nothing downloaded', style: context.texts.titleMedium),
            SizedBox(height: spacing.sm),
            Text(
              'Downloads are queued on Wi-Fi by default and expire per the '
              "server's policy.",
              textAlign: TextAlign.center,
              style: context.texts.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

void _notYet(BuildContext context, String what) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('$what — not implemented yet')),
  );
}
