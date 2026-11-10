// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../servers/jellyfin_admin_dto.dart' show libraryKinds;
import '../../widgets/section_header.dart';
import '../servers/server_library.dart' show serverViewsProvider;
import 'admin_folder_picker.dart';
import 'admin_libraries_page.dart' show libraryIcon;
import 'admin_providers.dart';
import 'admin_widgets.dart';

/// Makes a library: what it holds, what it is called, and the folders on the
/// server's disk it reads.
///
/// The three questions Jellyfin's own dialog leads with, and nothing of the
/// thirty options under them — metadata fetchers, image savers, real-time
/// monitoring. The server's defaults for those are what nearly everyone
/// keeps, and they stay editable from the web dashboard.
class AdminAddLibraryPage extends ConsumerStatefulWidget {
  const AdminAddLibraryPage({super.key});

  @override
  ConsumerState<AdminAddLibraryPage> createState() =>
      _AdminAddLibraryPageState();
}

class _AdminAddLibraryPageState extends ConsumerState<AdminAddLibraryPage> {
  String? _kind = 'movies';
  final _name = TextEditingController();

  /// Whether the name is still the one the kind suggested. While it is,
  /// changing the kind renames it; once the person has typed, it is theirs.
  bool _nameIsSuggested = true;
  final List<String> _paths = <String>[];
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_nameIsSuggested) {
      _name.text = libraryKindLabel(_kind, AppLocalizations.of(context));
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _canCreate =>
      !_saving && _name.text.trim().isNotEmpty && _paths.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final horizontal = spacing.screenHorizontal(context.windowSize);

    return AdminScaffold(
      title: l10n.adminAddLibrary,
      // A form, not a list from the server: there is nothing to pull.
      onRefresh: () async {},
      bottomBar: Material(
        color: context.colors.surfaceContainer,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: horizontal,
              vertical: spacing.sm,
            ),
            child: FilledButton(
              onPressed: _canCreate ? _create : null,
              child: _saving
                  ? SizedBox.square(
                      dimension: spacing.lg,
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.adminCreate),
            ),
          ),
        ),
      ),
      child: AdminList(
        children: <Widget>[
          SectionHeader(title: l10n.adminLibraryKind),
          for (final String? kind in libraryKinds)
            ListTile(
              leading: Icon(libraryIcon(kind ?? '')),
              title: Text(libraryKindLabel(kind, l10n)),
              trailing: kind == _kind
                  ? Icon(Icons.check_rounded, color: context.colors.primary)
                  : null,
              selected: kind == _kind,
              onTap: () => setState(() {
                _kind = kind;
                if (_nameIsSuggested) {
                  _name.text = libraryKindLabel(kind, l10n);
                }
              }),
            ),
          SizedBox(height: spacing.md),
          SectionHeader(title: l10n.adminUserNameLabel),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontal),
            child: TextField(
              controller: _name,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              onChanged: (_) => setState(() => _nameIsSuggested = false),
            ),
          ),
          SizedBox(height: spacing.md),
          SectionHeader(title: l10n.adminLibraryFolders),
          if (_paths.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontal),
              child: Text(
                l10n.adminLibraryNeedsFolder,
                style: context.texts.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ),
          for (final String path in _paths)
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: Text(path, maxLines: 2, overflow: TextOverflow.ellipsis),
              trailing: IconButton(
                icon: const Icon(Icons.close_rounded),
                tooltip: l10n.adminRemoveFolder,
                onPressed: () => setState(() => _paths.remove(path)),
              ),
            ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: horizontal,
              vertical: spacing.sm,
            ),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.create_new_folder_outlined),
                label: Text(l10n.adminAddFolder),
                onPressed: _saving
                    ? null
                    : () async {
                        final path = await pickServerFolder(context);
                        if (path == null || _paths.contains(path)) return;
                        setState(() => _paths.add(path));
                      },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _create() async {
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final name = _name.text.trim();
    setState(() => _saving = true);

    final made = await runAdminAction(
      context,
      ref,
      action: (admin) => admin.addLibrary(
        name: name,
        kind: _kind,
        paths: List<String>.of(_paths),
      ),
      success: l10n.adminLibraryCreated(name),
      refresh: () => ref
        ..invalidate(adminLibraryFoldersProvider)
        ..invalidate(adminLibrariesProvider)
        ..invalidate(serverViewsProvider)
        ..invalidate(scheduledTasksProvider),
    );

    if (!mounted) return;
    setState(() => _saving = false);
    if (made) navigator.pop();
  }
}

/// A library kind as its picker names it.
String libraryKindLabel(String? kind, AppLocalizations l10n) => switch (kind) {
  'movies' => l10n.adminKindMovies,
  'tvshows' => l10n.adminKindShows,
  'music' => l10n.adminKindMusic,
  'musicvideos' => l10n.adminKindMusicVideos,
  'homevideos' => l10n.adminKindHomeVideos,
  'books' => l10n.adminKindBooks,
  _ => l10n.adminKindMixed,
};
