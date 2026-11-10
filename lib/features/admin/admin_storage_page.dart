// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../servers/server_admin.dart';
import '../../widgets/section_header.dart';
import '../downloads/download_ui.dart' show formatBytes;
import 'admin_providers.dart';
import 'admin_widgets.dart';

/// Where the server keeps things and how full the disks under them are.
///
/// The question it answers is "is a disk about to fill up", so each row
/// leads with the free space and draws a bar only where the server measured
/// both halves of it.
class AdminStoragePage extends ConsumerWidget {
  const AdminStoragePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final storage = ref.watch(serverStorageProvider);

    return AdminScaffold(
      title: l10n.adminStorage,
      onRefresh: () async {
        ref.invalidate(serverStorageProvider);
        await ref.read(serverStorageProvider.future);
      },
      child: switch (storage) {
        AsyncError(:final error) => AdminList(
          emptyText: '$error',
          children: const <Widget>[],
        ),
        AsyncData(value: null) => AdminList(
          emptyText: l10n.adminStorageUnsupported,
          children: const <Widget>[],
        ),
        _ => AdminList(
          loading: storage.isLoading,
          children: <Widget>[
            if (storage.value case final ServerStorage s) ...<Widget>[
              SectionHeader(title: l10n.adminStorageServer),
              for (final StorageFolder f in s.folders)
                _FolderRow(title: storageFolderLabel(f.kind, l10n), folder: f),
              for (final lib in s.libraries)
                if (lib.folders.isNotEmpty) ...<Widget>[
                  SizedBox(height: context.spacing.md),
                  SectionHeader(title: lib.name),
                  for (final StorageFolder f in lib.folders)
                    _FolderRow(title: f.path, folder: f, showPath: false),
                ],
            ],
          ],
        ),
      },
    );
  }
}

class _FolderRow extends StatelessWidget {
  const _FolderRow({
    required this.title,
    required this.folder,
    this.showPath = true,
  });

  final String title;
  final StorageFolder folder;
  final bool showPath;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = context.colors;
    final free = folder.free;
    final used = folder.used;

    final share = diskShareUsed(free: free, used: used);
    final low = free != null && isLowSpace(free);

    return ListTile(
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (showPath)
            Text(folder.path, maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(
            <String>[
              if (free != null) l10n.adminStorageFree(formatBytes(free)),
              if (used != null) l10n.adminStorageUsed(formatBytes(used)),
            ].join(' · '),
            style: low ? TextStyle(color: scheme.error) : null,
          ),
          if (share != null)
            Padding(
              padding: EdgeInsets.only(top: context.spacing.xs),
              child: LinearProgressIndicator(
                value: share,
                color: low ? scheme.error : null,
              ),
            ),
        ],
      ),
    );
  }
}

/// How much of the folder's disk this folder takes, 0..1, or null when
/// either half was not measured.
double? diskShareUsed({int? free, int? used}) {
  if (free == null || used == null || free + used <= 0) return null;
  return (used / (free + used)).clamp(0.0, 1.0);
}

/// Under 10 GB free: few films, and a transcode cache can take that in an
/// evening.
bool isLowSpace(int freeBytes) => freeBytes < 10 * 1024 * 1024 * 1024;

String storageFolderLabel(StorageFolderKind kind, AppLocalizations l10n) =>
    switch (kind) {
      StorageFolderKind.programData => l10n.adminFolderData,
      StorageFolderKind.web => l10n.adminFolderWeb,
      StorageFolderKind.imageCache => l10n.adminFolderImages,
      StorageFolderKind.cache => l10n.adminFolderCache,
      StorageFolderKind.logs => l10n.adminFolderLogs,
      StorageFolderKind.metadata => l10n.adminFolderMetadata,
      StorageFolderKind.transcodes => l10n.adminFolderTranscodes,
      StorageFolderKind.library => l10n.adminLibraries,
    };
