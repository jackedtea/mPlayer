// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../servers/media_library_source.dart' show ServerException;
import '../../servers/server_admin.dart';
import 'admin_providers.dart';
import 'admin_widgets.dart';

/// Lets an administrator pick a folder **on the server's disk**, by walking
/// the server's own directory listing.
///
/// This is what makes adding a library from a phone safe: a typed path is a
/// typo that makes an empty library, and the phone's own files mean nothing
/// to the server. Every folder offered here is one the server listed. A path
/// can still be typed — a network share is not under any drive — and is then
/// opened, so a wrong one fails here rather than in the library.
///
/// Answers the chosen path, or null when backed out of.
Future<String?> pickServerFolder(BuildContext context) {
  return Navigator.of(context).push<String>(
    MaterialPageRoute<String>(
      fullscreenDialog: true,
      builder: (_) => const ServerFolderPicker(),
    ),
  );
}

class ServerFolderPicker extends ConsumerStatefulWidget {
  const ServerFolderPicker({super.key});

  @override
  ConsumerState<ServerFolderPicker> createState() => _ServerFolderPickerState();
}

class _ServerFolderPickerState extends ConsumerState<ServerFolderPicker> {
  /// The folder being shown, or null for the list of drives.
  String? _path;
  List<ServerFolder> _folders = const <ServerFolder>[];
  bool _loading = true;
  String? _error;

  final _typed = TextEditingController();

  /// Bumped per navigation, so a slow listing that lands after the next one
  /// was asked for is dropped instead of drawn under the wrong path.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _open(null);
  }

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  Future<void> _open(String? path) async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final admin = await ref.read(serverAdminProvider.future);
      if (admin == null) {
        // The scaffold's guard says why; just stop spinning under it.
        if (mounted) setState(() => _loading = false);
        return;
      }
      final folders = path == null
          ? await admin.drives()
          : await admin.folders(path);
      if (!mounted || generation != _generation) return;
      setState(() {
        _path = path;
        _folders = folders;
        _loading = false;
        _typed.text = path ?? '';
      });
    } on ServerException catch (e) {
      if (!mounted || generation != _generation) return;
      // Stay where we were: the folder that would not open is not shown.
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  Future<void> _up() async {
    final path = _path;
    if (path == null) return;
    try {
      final admin = await ref.read(serverAdminProvider.future);
      if (admin == null) return;
      await _open(await admin.parentFolder(path));
    } on ServerException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final path = _path;

    return AdminScaffold(
      title: l10n.adminPickFolder,
      onRefresh: () => _open(_path),
      bottomBar: Material(
        color: context.colors.surfaceContainer,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: spacing.screenHorizontal(context.windowSize),
              vertical: spacing.sm,
            ),
            child: FilledButton.icon(
              icon: const Icon(Icons.check_rounded),
              // A drive list is not a folder; something has to be opened.
              onPressed: path == null || _loading
                  ? null
                  : () => Navigator.of(context).pop(path),
              label: Text(
                path == null ? l10n.adminPickFolderHint : l10n.adminUseFolder,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ),
      child: Column(
        children: <Widget>[
          Padding(
            padding: EdgeInsets.fromLTRB(
              spacing.screenHorizontal(context.windowSize),
              spacing.sm,
              spacing.screenHorizontal(context.windowSize),
              spacing.xs,
            ),
            child: TextField(
              controller: _typed,
              decoration: InputDecoration(
                labelText: l10n.adminFolderPath,
                helperText: l10n.adminFolderPathHint,
                errorText: _error,
                errorMaxLines: 3,
                border: const OutlineInputBorder(),
                isDense: true,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward_rounded),
                  tooltip: l10n.adminOpenFolder,
                  onPressed: () => _goTyped(),
                ),
              ),
              onSubmitted: (_) => _goTyped(),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : AdminList(
                    children: <Widget>[
                      if (path != null)
                        ListTile(
                          leading: const Icon(Icons.arrow_upward_rounded),
                          title: Text(l10n.adminFolderUp),
                          onTap: _up,
                        ),
                      if (_folders.isEmpty)
                        Padding(
                          padding: EdgeInsets.all(spacing.lg),
                          child: AdminNote(
                            text: path == null
                                ? l10n.adminNoDrives
                                : l10n.adminFolderEmpty,
                          ),
                        ),
                      for (final ServerFolder folder in _folders)
                        ListTile(
                          leading: Icon(
                            path == null
                                ? Icons.storage_rounded
                                : Icons.folder_outlined,
                          ),
                          title: Text(
                            folder.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => _open(folder.path),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  void _goTyped() {
    final typed = _typed.text.trim();
    if (typed.isEmpty) {
      _open(null);
    } else {
      _open(typed);
    }
  }
}
