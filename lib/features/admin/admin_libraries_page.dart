// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../servers/server_admin.dart';
import '../servers/server_library.dart' show serverViewsProvider;
import 'admin_folder_picker.dart';
import 'admin_item_actions.dart' show pickRefreshMode;
import 'admin_providers.dart';
import 'admin_widgets.dart';

/// The server's libraries, with the folders each one reads, and what can be
/// done to one: scan it, refresh its metadata, rename it, change its folders,
/// remove it. Add library is the FAB.
///
/// Folders are only ever picked by walking the **server's own** directory
/// listing (`pickServerFolder`): typed from a phone, a path is a typo that
/// makes an empty library.
class AdminLibrariesPage extends ConsumerWidget {
  const AdminLibrariesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final folders = ref.watch(adminLibraryFoldersProvider);

    return AdminScaffold(
      title: l10n.adminLibraries,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'admin-add-library',
        onPressed: () => context.push('/admin/libraries/new'),
        icon: const Icon(Icons.add_rounded),
        label: Text(l10n.adminAddLibrary),
      ),
      onRefresh: () async {
        ref.invalidate(adminLibraryFoldersProvider);
        await ref.read(adminLibraryFoldersProvider.future);
      },
      child: switch (folders) {
        AsyncError(:final error) => AdminList(
          emptyText: '$error',
          children: const <Widget>[],
        ),
        _ => AdminList(
          loading: folders.isLoading,
          emptyText: l10n.adminNoLibraries,
          children: <Widget>[
            for (final AdminLibraryFolder folder
                in folders.value ?? const <AdminLibraryFolder>[])
              _LibraryRow(folder: folder),
          ],
        ),
      },
    );
  }
}

class _LibraryRow extends ConsumerWidget {
  const _LibraryRow({required this.folder});

  final AdminLibraryFolder folder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final progress = folder.refreshProgress;

    return ListTile(
      leading: Icon(libraryIcon(folder.kind)),
      title: Text(folder.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (folder.paths.isEmpty)
            Text(l10n.adminLibraryNoFolders)
          else
            for (final String path in folder.paths)
              Text(path, maxLines: 1, overflow: TextOverflow.ellipsis),
          if (progress != null)
            Padding(
              padding: EdgeInsets.only(top: context.spacing.xs),
              child: LinearProgressIndicator(value: progress / 100),
            ),
        ],
      ),
      trailing: PopupMenuButton<VoidCallback>(
        icon: const Icon(Icons.more_vert_rounded),
        onSelected: (action) => action(),
        itemBuilder: (_) => <PopupMenuEntry<VoidCallback>>[
          _item(
            Icons.youtube_searched_for_rounded,
            l10n.adminLibraryScan,
            () => _refresh(context, ref, MetadataRefresh.scan),
          ),
          _item(Icons.refresh_rounded, l10n.adminRefreshMetadata, () async {
            final mode = await pickRefreshMode(context);
            if (mode != null && context.mounted) {
              await _refresh(context, ref, mode);
            }
          }),
          _item(
            Icons.drive_file_rename_outline_rounded,
            l10n.adminLibraryRename,
            () => _rename(context, ref),
          ),
          _item(
            Icons.folder_open_rounded,
            l10n.adminLibraryFolders,
            () => showLibraryFolders(context, folder.name),
          ),
          _item(
            Icons.delete_outline_rounded,
            l10n.adminLibraryRemove,
            () => _remove(context, ref),
            colour: context.colors.error,
          ),
        ],
      ),
    );
  }

  PopupMenuItem<VoidCallback> _item(
    IconData icon,
    String label,
    VoidCallback action, {
    Color? colour,
  }) {
    return PopupMenuItem<VoidCallback>(
      value: action,
      child: ListTile(
        leading: Icon(icon, color: colour),
        title: Text(label, style: TextStyle(color: colour)),
      ),
    );
  }

  Future<void> _refresh(
    BuildContext context,
    WidgetRef ref,
    MetadataRefresh mode,
  ) async {
    final l10n = AppLocalizations.of(context);
    // A library whose id the server left out cannot be refreshed by itself;
    // say so rather than scanning every library in its place.
    if (folder.itemId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.adminLibraryNoId)));
      return;
    }
    await runAdminAction(
      context,
      ref,
      action: (admin) => admin.refreshItem(folder.itemId, mode),
      success: l10n.adminRefreshQueued(folder.name),
      refresh: () => ref
        ..invalidate(adminLibraryFoldersProvider)
        ..invalidate(scheduledTasksProvider),
    );
  }

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _RenameDialog(initial: folder.name),
    );

    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty || trimmed == folder.name || !context.mounted) return;

    await runAdminAction(
      context,
      ref,
      action: (admin) => admin.renameLibrary(folder.name, trimmed),
      success: l10n.adminLibraryRenamed(trimmed),
      // The library switcher and every tab read the name from the views.
      refresh: () => ref
        ..invalidate(adminLibraryFoldersProvider)
        ..invalidate(serverViewsProvider),
    );
  }

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final sure = await confirmAdminAction(
      context,
      title: l10n.adminLibraryRemoveQuestion(folder.name),
      body: l10n.adminLibraryRemoveBody,
      confirmLabel: l10n.adminLibraryRemove,
    );
    if (!sure || !context.mounted) return;

    await runAdminAction(
      context,
      ref,
      action: (admin) => admin.deleteLibrary(folder.name),
      success: l10n.adminLibraryRemoved(folder.name),
      refresh: () => ref
        ..invalidate(adminLibraryFoldersProvider)
        ..invalidate(serverViewsProvider)
        ..invalidate(adminLibrariesProvider),
    );
  }
}

/// Asks for a library's new name. Its own widget so the field's controller
/// lives exactly as long as the dialog — disposed after the closing animation,
/// not before it.
class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initial});

  final String initial;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.adminLibraryRename),
      content: TextField(
        controller: _name,
        autofocus: true,
        decoration: InputDecoration(labelText: l10n.adminUserNameLabel),
        onSubmitted: (v) => Navigator.of(context).pop(v),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_name.text),
          child: Text(l10n.actionSave),
        ),
      ],
    );
  }
}

/// The glyph for a library of [kind] — the server's `CollectionType`.
IconData libraryIcon(String kind) => switch (kind) {
  'movies' => Icons.movie_outlined,
  'tvshows' => Icons.tv_rounded,
  'music' => Icons.library_music_outlined,
  'musicvideos' => Icons.music_video_outlined,
  'books' => Icons.menu_book_outlined,
  'photos' || 'homevideos' => Icons.photo_library_outlined,
  'boxsets' => Icons.collections_bookmark_outlined,
  'livetv' => Icons.live_tv_rounded,
  _ => Icons.folder_outlined,
};

/// The folders one library reads, each removable, and Add folder.
///
/// A sheet over the list rather than a page of its own: two or three paths
/// is all a library usually has, and the list behind it is where the result
/// shows.
Future<void> showLibraryFolders(BuildContext context, String name) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _LibraryFoldersSheet(name: name),
  );
}

class _LibraryFoldersSheet extends ConsumerWidget {
  const _LibraryFoldersSheet({required this.name});

  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    // Read from the same list the page shows, so a change here redraws both.
    final library = ref
        .watch(adminLibraryFoldersProvider)
        .value
        ?.where((f) => f.name == name)
        .firstOrNull;
    final paths = library?.paths ?? const <String>[];

    void refresh() => ref
      ..invalidate(adminLibraryFoldersProvider)
      ..invalidate(scheduledTasksProvider);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ListTile(
            title: Text(name, style: context.texts.titleMedium),
            subtitle: Text(l10n.adminLibraryFolders),
          ),
          for (final String path in paths)
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: Text(path, maxLines: 2, overflow: TextOverflow.ellipsis),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline_rounded),
                tooltip: l10n.adminRemoveFolder,
                onPressed: () async {
                  final sure = await confirmAdminAction(
                    context,
                    title: l10n.adminRemoveFolderQuestion,
                    body: l10n.adminRemoveFolderBody(path),
                    confirmLabel: l10n.adminRemoveFolder,
                  );
                  if (!sure || !context.mounted) return;
                  await runAdminAction(
                    context,
                    ref,
                    action: (admin) => admin.removeLibraryPath(name, path),
                    success: l10n.adminFolderRemoved,
                    refresh: refresh,
                  );
                },
              ),
            ),
          Padding(
            padding: EdgeInsets.all(spacing.md),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.create_new_folder_outlined),
              label: Text(l10n.adminAddFolder),
              onPressed: () async {
                final path = await pickServerFolder(context);
                if (path == null || paths.contains(path) || !context.mounted) {
                  return;
                }
                await runAdminAction(
                  context,
                  ref,
                  action: (admin) => admin.addLibraryPath(name, path),
                  success: l10n.adminFolderAdded,
                  refresh: refresh,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
