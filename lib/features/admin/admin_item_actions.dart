// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

/// What an administrator can do to one item from its own screen: refresh its
/// metadata, edit it, delete it.
///
/// Built as [ItemAction]s so they land in the same row, glyphs and ⋮ menu as
/// Watched and Favourite — and, being appended last, in the overflow where a
/// row is short of room, which is where something used once a month belongs.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../servers/media_library_source.dart'
    show ServerItem, ServerItemKind;
import '../../servers/server_admin.dart';
import '../servers/item_actions.dart' show ItemAction;
import '../servers/server_library.dart';
import 'admin_providers.dart';
import 'admin_widgets.dart';

/// The administrator's actions for [item], or none for anyone else.
List<ItemAction> adminItemActions(
  BuildContext context,
  WidgetRef ref,
  ServerItem item,
) {
  if (!ref.watch(isAdministratorProvider) || item.id.isEmpty) {
    return const <ItemAction>[];
  }
  final l10n = AppLocalizations.of(context);

  return <ItemAction>[
    ItemAction(
      icon: Icons.refresh_rounded,
      label: l10n.adminRefreshMetadata,
      onSelected: () async {
        final mode = await pickRefreshMode(context);
        if (mode == null || !context.mounted) return;
        await runAdminAction(
          context,
          ref,
          action: (admin) => admin.refreshItem(item.id, mode),
          success: l10n.adminRefreshQueued(item.title),
          refresh: () => ref.invalidate(scheduledTasksProvider),
        );
      },
    ),
    // An artist is described by their providers, and the editor's fields
    // (year, certificate) mean nothing for one.
    if (item.kind != ServerItemKind.musicArtist)
      ItemAction(
        icon: Icons.edit_note_rounded,
        label: l10n.adminEditMetadata,
        onSelected: () async {
          final saved = await context.push<bool>(
            '/admin/item/${item.id}?title='
            '${Uri.encodeQueryComponent(item.title)}',
          );
          if (saved == true) invalidateItem(ref, item.id);
        },
      ),
    ItemAction(
      icon: Icons.delete_forever_outlined,
      label: l10n.adminDeleteItem,
      onSelected: () => _delete(context, ref, item),
    ),
  ];
}

Future<void> _delete(
  BuildContext context,
  WidgetRef ref,
  ServerItem item,
) async {
  final l10n = AppLocalizations.of(context);

  // Asked before the dialog: whether this screen *is* the item decides
  // whether it has to close afterwards. An episode deleted from its series'
  // list leaves the series on screen; a film deleted from its own page
  // leaves nothing to show.
  final router = GoRouter.of(context);
  final onItsOwnScreen = _routeExtra(context) == item.id;

  final sure = await confirmAdminAction(
    context,
    title: l10n.adminDeleteItemQuestion(item.title),
    body: l10n.adminDeleteItemBody,
    confirmLabel: l10n.adminDeleteItem,
  );
  if (!sure || !context.mounted) return;

  final deleted = await runAdminAction(
    context,
    ref,
    action: (admin) => admin.deleteItem(item.id),
    success: l10n.adminItemDeleted(item.title),
    refresh: () => invalidateItem(ref, item.id),
  );
  if (deleted && onItsOwnScreen && router.canPop()) router.pop();
}

/// The id the detail route was opened with, or null off a go_router page
/// (a test pumping a widget alone, a dialog's own route).
Object? _routeExtra(BuildContext context) {
  try {
    return GoRouterState.of(context).extra;
  } on GoError {
    return null;
  }
}

/// Everything that may be showing [itemId] or a list it was in.
void invalidateItem(WidgetRef ref, String itemId) {
  ref
    ..invalidate(serverItemProvider(itemId))
    ..invalidate(seriesEpisodesProvider)
    ..invalidate(libraryItemsProvider)
    ..invalidate(latestInViewProvider)
    ..invalidate(homeResumeProvider)
    ..invalidate(serverNextUpProvider);
}

/// Asks how deep a refresh should go. Null when dismissed.
Future<MetadataRefresh?> pickRefreshMode(BuildContext context) {
  final l10n = AppLocalizations.of(context);

  return showDialog<MetadataRefresh>(
    context: context,
    builder: (dialogContext) {
      Widget option(MetadataRefresh mode, String title, String body) {
        return ListTile(
          title: Text(title),
          subtitle: Text(body),
          onTap: () => Navigator.of(dialogContext).pop(mode),
        );
      }

      return SimpleDialog(
        title: Text(l10n.adminRefreshMetadata),
        children: <Widget>[
          option(
            MetadataRefresh.scan,
            l10n.adminRefreshScan,
            l10n.adminRefreshScanBody,
          ),
          option(
            MetadataRefresh.missing,
            l10n.adminRefreshMissing,
            l10n.adminRefreshMissingBody,
          ),
          option(
            MetadataRefresh.replaceAll,
            l10n.adminRefreshReplace,
            l10n.adminRefreshReplaceBody,
          ),
        ],
      );
    },
  );
}

/// The ⋮ an administrator gets in a library's app bar — what Jellyfin's web
/// client offers on a library: scan it, refresh its metadata, edit it.
///
/// Draws nothing for anyone else, so the bar keeps its shape for a viewer.
/// [isLibrary] is false for a box set or playlist drilled into, which has
/// metadata to refresh and edit but no files of its own to scan.
class AdminItemMenu extends ConsumerWidget {
  const AdminItemMenu({
    super.key,
    required this.itemId,
    required this.title,
    this.isLibrary = true,
  });

  final String itemId;
  final String title;
  final bool isLibrary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(isAdministratorProvider) || itemId.isEmpty) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);

    PopupMenuItem<VoidCallback> item(
      IconData icon,
      String label,
      VoidCallback action,
    ) {
      return PopupMenuItem<VoidCallback>(
        value: action,
        child: ListTile(leading: Icon(icon), title: Text(label)),
      );
    }

    Future<void> refresh(MetadataRefresh mode) => runAdminAction(
      context,
      ref,
      action: (admin) => admin.refreshItem(itemId, mode),
      success: l10n.adminRefreshQueued(title),
      refresh: () => ref.invalidate(scheduledTasksProvider),
    );

    return PopupMenuButton<VoidCallback>(
      icon: const Icon(Icons.more_vert_rounded),
      tooltip: MaterialLocalizations.of(context).showMenuTooltip,
      onSelected: (action) => action(),
      itemBuilder: (_) => <PopupMenuEntry<VoidCallback>>[
        if (isLibrary)
          item(
            Icons.youtube_searched_for_rounded,
            l10n.adminLibraryScan,
            () => refresh(MetadataRefresh.scan),
          ),
        item(Icons.refresh_rounded, l10n.adminRefreshMetadata, () async {
          final mode = await pickRefreshMode(context);
          if (mode != null && context.mounted) await refresh(mode);
        }),
        item(Icons.edit_note_rounded, l10n.adminEditMetadata, () async {
          final saved = await context.push<bool>(
            '/admin/item/$itemId?title=${Uri.encodeQueryComponent(title)}',
          );
          if (saved != true) return;
          invalidateItem(ref, itemId);
          // A library's name is read from the views, for the switcher.
          ref.invalidate(serverViewsProvider);
        }),
      ],
    );
  }
}
