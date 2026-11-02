// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/tokens.dart';
import '../../downloads/download_models.dart';
import '../../downloads/download_store.dart';
import '../../downloads/downloads_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/gradient_art.dart';
import '../../widgets/section_header.dart';
import 'download_ui.dart';

/// Screen 1i — the offline copies, and the Downloads tab.
///
/// Unfinished copies first, in queue order, since that is what the user
/// came to check on; then what is on the device, films together and each
/// series' episodes under its own name in airing order.
///
/// Drawn entirely from the index, so it works with no server signed in.
/// Status is carried by colour as well as words: green for on the device,
/// error for a failure, primary for the bar of one under way.
class DownloadsPage extends ConsumerWidget {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = context.spacing;
    final l10n = AppLocalizations.of(context);
    final entries = ref.watch(downloadsProvider);

    final unfinished = <DownloadEntry>[
      for (final e in entries)
        if (e.status != DownloadStatus.completed) e,
    ];
    final groups = _groupsOf(
      <DownloadEntry>[
        for (final e in entries)
          if (e.status == DownloadStatus.completed) e,
      ],
      films: l10n.downloadsMovies,
    );
    final used = entries.fold<int>(0, (sum, e) => sum + e.receivedBytes);
    final horizontal = spacing.screenHorizontal(context.windowSize);

    return Scaffold(
      // No back arrow: this is a navigation destination.
      appBar: AppBar(title: Text(l10n.downloads)),
      body: entries.isEmpty
          ? const _EmptyState()
          : ListView(
              padding: EdgeInsets.only(bottom: spacing.xl),
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontal,
                    spacing.sm,
                    horizontal,
                    spacing.lg,
                  ),
                  child: Text(
                    l10n.downloadsUsed(formatBytes(used)),
                    style: context.texts.bodySmall
                        ?.copyWith(color: context.colors.onSurfaceVariant),
                  ),
                ),
                if (unfinished.isNotEmpty) ...<Widget>[
                  SectionHeader(title: l10n.downloadsInProgress),
                  for (final e in unfinished)
                    _DownloadTile(entry: e, showSeries: true),
                  SizedBox(height: spacing.lg),
                ],
                for (final (String title, List<DownloadEntry> items)
                    in groups) ...<Widget>[
                  SectionHeader(title: title),
                  for (final e in items) _DownloadTile(entry: e),
                  SizedBox(height: spacing.lg),
                ],
              ],
            ),
    );
  }

  /// Films first under one heading, then a heading per series, each in the
  /// order it aired.
  static List<(String, List<DownloadEntry>)> _groupsOf(
    List<DownloadEntry> done, {
    required String films,
  }) {
    final movies = <DownloadEntry>[];
    final bySeries = <String, List<DownloadEntry>>{};
    for (final e in done) {
      final series = e.seriesTitle;
      if (e.seriesId == null || series == null) {
        movies.add(e);
      } else {
        (bySeries[series] ??= <DownloadEntry>[]).add(e);
      }
    }

    movies.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    final names = bySeries.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return <(String, List<DownloadEntry>)>[
      if (movies.isNotEmpty) (films, movies),
      for (final name in names)
        (
          name,
          bySeries[name]!
            ..sort((a, b) {
              final season = (a.seasonNumber ?? 0).compareTo(b.seasonNumber ?? 0);
              return season != 0
                  ? season
                  : (a.episodeNumber ?? 0).compareTo(b.episodeNumber ?? 0);
            }),
        ),
    ];
  }
}

class _DownloadTile extends ConsumerWidget {
  const _DownloadTile({required this.entry, this.showSeries = false});

  final DownloadEntry entry;

  /// Puts the series' name in front of an episode's title — wanted in the
  /// queue, where episodes of several shows sit together, and not under a
  /// heading that already names the show.
  final bool showSeries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = context.spacing;
    final scheme = context.colors;
    final l10n = AppLocalizations.of(context);
    final store = ref.watch(downloadStoreProvider).value;
    final signedIn = ref.watch(downloadSourceProvider)(entry.profileId) != null;
    final progress = entry.progress;
    final showBar = entry.status == DownloadStatus.downloading ||
        (entry.status == DownloadStatus.paused && progress != null);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.screenHorizontal(context.windowSize),
        vertical: spacing.xs,
      ),
      child: Container(
        padding: EdgeInsets.all(spacing.md),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: context.radii.cardAll,
        ),
        child: Row(
          children: <Widget>[
            _Poster(entry: entry, store: store),
            SizedBox(width: spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    _title(l10n),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.texts.bodyLarge,
                  ),
                  SizedBox(height: spacing.xs),
                  Text(
                    _detail(l10n, signedIn: signedIn),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.texts.bodySmall
                        ?.copyWith(color: _detailColor(context)),
                  ),
                  if (showBar) ...<Widget>[
                    SizedBox(height: spacing.sm),
                    ClipRRect(
                      borderRadius: context.radii.chipAll,
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 4,
                        backgroundColor: scheme.surfaceContainerHighest,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            ..._actions(context, ref, l10n),
          ],
        ),
      ),
    );
  }

  String _title(AppLocalizations l10n) {
    final season = entry.seasonNumber;
    final episode = entry.episodeNumber;
    final code = season != null && episode != null
        ? l10n.episodeOf(season, episode)
        : null;
    return <String>[
      if (showSeries && entry.seriesTitle != null) entry.seriesTitle!,
      ?code,
      entry.title,
    ].join(' · ');
  }

  String _detail(AppLocalizations l10n, {required bool signedIn}) {
    final total = entry.totalBytes;
    final sizes = total == null
        ? formatBytes(entry.receivedBytes)
        : l10n.downloadSizeOf(
            formatBytes(entry.receivedBytes),
            formatBytes(total),
          );

    return switch (entry.status) {
      DownloadStatus.completed =>
        '${l10n.availableOffline} · ${formatBytes(entry.receivedBytes)}',
      DownloadStatus.downloading => total == null
          ? sizes
          : '${l10n.downloadingPercent(((entry.progress ?? 0) * 100).floor())} · $sizes',
      DownloadStatus.queued =>
        signedIn ? l10n.downloadQueued : l10n.downloadWaitingForServer,
      DownloadStatus.paused => entry.receivedBytes > 0
          ? '${l10n.downloadPaused} · $sizes'
          : l10n.downloadPaused,
      DownloadStatus.failed => entry.error ?? l10n.actionFailed,
    };
  }

  Color _detailColor(BuildContext context) => switch (entry.status) {
        DownloadStatus.completed => context.semantic.success,
        DownloadStatus.failed => context.colors.error,
        _ => context.colors.onSurfaceVariant,
      };

  List<Widget> _actions(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    final controller = ref.read(downloadsProvider.notifier);
    final completed = entry.status == DownloadStatus.completed;

    final Widget? primary = switch (entry.status) {
      DownloadStatus.queued || DownloadStatus.downloading => IconButton(
          icon: const Icon(Icons.pause_rounded),
          tooltip: l10n.pauseDownload,
          onPressed: () => controller.pause(entry.key),
        ),
      DownloadStatus.paused => IconButton(
          icon: const Icon(Icons.download_rounded),
          tooltip: l10n.resumeDownload,
          onPressed: () => controller.resume(entry.key),
        ),
      DownloadStatus.failed => IconButton(
          icon: const Icon(Icons.refresh_rounded),
          tooltip: l10n.retryDownload,
          onPressed: () => controller.resume(entry.key),
        ),
      DownloadStatus.completed => null,
    };

    return <Widget>[
      ?primary,
      IconButton(
        icon: Icon(completed ? Icons.delete_outline_rounded : Icons.close_rounded),
        tooltip: completed ? l10n.removeDownload : l10n.cancelDownload,
        onPressed: () => confirmRemoveDownload(
          context,
          ref,
          key: entry.key,
          title: entry.title,
          completed: completed,
        ),
      ),
    ];
  }
}

/// The poster saved beside the file, over a gradient that stays the
/// picture when there is none — the same arrangement as `PosterTile`.
class _Poster extends StatelessWidget {
  const _Poster({required this.entry, required this.store});

  final DownloadEntry entry;
  final DownloadStore? store;

  @override
  Widget build(BuildContext context) {
    final file = store?.posterFile(entry);

    return ClipRRect(
      borderRadius: context.radii.chipAll,
      child: SizedBox(
        width: 48,
        height: 72,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            GradientArt(seed: entry.seriesTitle ?? entry.title),
            if (file != null)
              Image.file(
                File(file.path),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
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
    final spacing = context.spacing;
    final scheme = context.colors;
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Padding(
        padding: EdgeInsets.all(spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.download_for_offline_outlined,
              size: 48,
              color: scheme.outline,
            ),
            SizedBox(height: spacing.lg),
            Text(l10n.noDownloads, style: context.texts.titleMedium),
            SizedBox(height: spacing.sm),
            Text(
              l10n.downloadsEmptyHint,
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
