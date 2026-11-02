// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/tokens.dart';
import '../../downloads/download_models.dart';
import '../../downloads/downloads_controller.dart';
import '../../l10n/app_localizations.dart';
import '../servers/server_library.dart';

/// "1.4 GB", "412 MB", "860 KB" — powers of 1024, one decimal past a
/// megabyte, which is the precision a progress line can use.
String formatBytes(int bytes) {
  const units = <String>['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final digits = unit >= 2 && value < 100 ? 1 : 0;
  return '${value.toStringAsFixed(digits)} ${units[unit]}';
}

/// The copy of [itemId] on the signed-in server, as far as a button needs
/// to know: its status and its whole-percent progress.
///
/// Reduced to a record so that a chunk arriving does not rebuild a detail
/// screen — only a status change or the next percent does.
({DownloadStatus status, int percent, String key})? watchDownload(
  WidgetRef ref,
  String itemId,
) {
  final profileId = ref.watch(activeServerProvider)?.profile.id;
  if (profileId == null) return null;
  final key = DownloadEntry.keyOf(profileId, itemId);
  return ref.watch(
    downloadsProvider.select((entries) {
      for (final DownloadEntry e in entries) {
        if (e.key == key) {
          return (
            status: e.status,
            percent: ((e.progress ?? 0) * 100).floor(),
            key: key,
          );
        }
      }
      return null;
    }),
  );
}

/// Asks before throwing a finished copy away; a film can be hours of
/// downloading to get back. Anything unfinished goes without asking.
Future<void> confirmRemoveDownload(
  BuildContext context,
  WidgetRef ref, {
  required String key,
  required String title,
  required bool completed,
}) async {
  if (completed) {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.removeDownloadTitle),
        content: Text(l10n.removeDownloadBody(title)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.actionRemove),
          ),
        ],
      ),
    );
    if (ok != true) return;
  }
  await ref.read(downloadsProvider.notifier).delete(key);
}

/// A small mark beside an episode's details: a tick once it is on the
/// device, a ring while it is on its way, nothing otherwise.
class DownloadBadge extends ConsumerWidget {
  const DownloadBadge({super.key, required this.itemId});

  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final download = watchDownload(ref, itemId);
    if (download == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);

    return switch (download.status) {
      DownloadStatus.completed => Tooltip(
          message: l10n.availableOffline,
          child: Icon(
            Icons.download_done_rounded,
            size: 16,
            color: context.semantic.success,
          ),
        ),
      DownloadStatus.queued || DownloadStatus.downloading => Tooltip(
          message: download.status == DownloadStatus.queued
              ? l10n.downloadQueued
              : l10n.downloadingPercent(download.percent),
          child: SizedBox.square(
            dimension: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              value: download.status == DownloadStatus.queued
                  ? null
                  : download.percent / 100,
            ),
          ),
        ),
      DownloadStatus.paused || DownloadStatus.failed => Tooltip(
          message: l10n.downloadPaused,
          child: Icon(
            Icons.pause_circle_outline_rounded,
            size: 16,
            color: context.colors.outline,
          ),
        ),
    };
  }
}
