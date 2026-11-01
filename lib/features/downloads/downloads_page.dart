// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';

import '../../app/tokens.dart';
import '../../core/models/library_models.dart';
import '../../l10n/app_localizations.dart';

/// Screen 1i — offline copies, and the Downloads tab.
///
/// **Not built yet.** The tab exists so the bar has its final shape; nothing
/// feeds the list, so it always shows the empty state. It used to show the
/// sample library's downloads, which in a tab of its own would read as real
/// files on the device. The tiles stay for when the download manager lands.
///
/// Status is carried by colour as well as words: green for available, error
/// for blocked, primary for active. The colours come from the scheme, so this
/// screen needs no dark-mode variant of its own.
class DownloadsPage extends StatelessWidget {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    const downloads = <DownloadItem>[];

    return Scaffold(
      // No back arrow: this is a navigation destination now.
      appBar: AppBar(title: Text(AppLocalizations.of(context).downloads)),
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
            Text(
              AppLocalizations.of(context).noDownloads,
              style: context.texts.titleMedium,
            ),
            SizedBox(height: spacing.sm),
            Text(
              AppLocalizations.of(context).downloadsComingSoon,
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
