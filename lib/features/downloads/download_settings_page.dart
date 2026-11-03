// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/tokens.dart';
import '../../downloads/download_settings.dart';
import '../../downloads/downloads_controller.dart';
import '../../l10n/app_localizations.dart';
import '../settings/settings_widgets.dart';
import 'download_ui.dart';

/// Settings › Downloads: when the queue may run, what happens to a copy
/// once it is watched, and the disk it takes.
class DownloadSettingsPage extends ConsumerWidget {
  const DownloadSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(downloadSettingsProvider);
    final controller = ref.read(downloadSettingsProvider.notifier);
    final entries = ref.watch(downloadsProvider);
    final used = entries.fold<int>(0, (sum, e) => sum + e.receivedBytes);
    final scheme = context.colors;

    return SettingsScaffold(
      title: l10n.downloadSettings,
      children: <Widget>[
        SettingsSwitchRow(
          title: l10n.downloadWifiOnly,
          subtitle: l10n.downloadWifiOnlySub,
          value: settings.wifiOnly,
          onChanged: controller.setWifiOnly,
        ),
        SettingsSwitchRow(
          title: l10n.downloadRemoveWatched,
          subtitle: l10n.downloadRemoveWatchedSub,
          value: settings.removeWatched,
          onChanged: controller.setRemoveWatched,
        ),
        SettingsSection(title: l10n.downloadStorage),
        ListTile(
          contentPadding: context.spacing.screenPadding(context.windowSize),
          leading: const Icon(Icons.sd_storage_outlined),
          title: Text(
            entries.isEmpty ? l10n.downloadsNone : l10n.downloadsUsed(formatBytes(used)),
          ),
        ),
        ListTile(
          contentPadding: context.spacing.screenPadding(context.windowSize),
          enabled: entries.isNotEmpty,
          leading: Icon(
            Icons.delete_outline_rounded,
            color: entries.isEmpty ? null : scheme.error,
          ),
          title: Text(
            l10n.downloadRemoveAll,
            style: entries.isEmpty ? null : TextStyle(color: scheme.error),
          ),
          onTap: () => _removeAll(context, ref),
        ),
      ],
    );
  }

  Future<void> _removeAll(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.downloadRemoveAllTitle),
        content: Text(l10n.downloadRemoveAllBody),
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
    if (ok == true) await ref.read(downloadsProvider.notifier).deleteAll();
  }
}
