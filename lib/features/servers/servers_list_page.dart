// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../servers/server_profile.dart';
import '../../servers/server_registry.dart';
import 'add_server_sheet.dart';

/// What the Server tab opens on once anything is configured.
///
/// The tab used to drop straight into whichever server was used last, which
/// left its screen with a back button pointing at nothing and no way to reach
/// a second server at all. The list is the tab's root now, so opening a
/// server is a push with something real underneath it.
class ServersListPage extends ConsumerWidget {
  const ServersListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = context.spacing;
    final scheme = context.colors;
    final l10n = AppLocalizations.of(context);
    final registry = ref.watch(serverRegistryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.switchServer),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            tooltip: l10n.settings,
            onPressed: () => context.push('/settings'),
          ),
          SizedBox(width: spacing.sm),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        // Distinct, because the rail's action outlives page transitions and
        // collides with a page-level tag otherwise.
        heroTag: 'add-server',
        onPressed: () => AddServerSheet.show(context),
        icon: const Icon(Icons.add_rounded),
        label: Text(l10n.addServer),
      ),
      body: ListView(
        padding: EdgeInsets.only(
          top: spacing.sm,
          // Clear of the FAB as well as the navigation bar.
          bottom: spacing.xl * 3 + context.systemBottomInset,
        ),
        children: <Widget>[
          for (final ServerProfile profile in registry.profiles)
            _ServerTile(profile: profile, active: profile.id == registry.activeId),
          if (registry.profiles.isEmpty)
            Padding(
              padding: EdgeInsets.all(spacing.xl),
              child: Text(
                l10n.noServersYet,
                textAlign: TextAlign.center,
                style: context.texts.bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }
}

class _ServerTile extends ConsumerWidget {
  const _ServerTile({required this.profile, required this.active});

  final ServerProfile profile;

  /// The one the rest of the app is currently talking to.
  final bool active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = context.colors;
    final l10n = AppLocalizations.of(context);

    return ListTile(
      leading: Icon(
        active ? Icons.dns_rounded : Icons.dns_outlined,
        color: active ? scheme.primary : null,
      ),
      title: Text(profile.name),
      subtitle: Text(
        hostLineFor(profile),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: PopupMenuButton<_ServerAction>(
        icon: const Icon(Icons.more_vert_rounded),
        onSelected: (action) => _run(context, ref, action),
        itemBuilder: (_) => <PopupMenuEntry<_ServerAction>>[
          PopupMenuItem<_ServerAction>(
            value: _ServerAction.edit,
            child: Text(l10n.editServer),
          ),
          PopupMenuItem<_ServerAction>(
            value: _ServerAction.remove,
            child: Text(l10n.removeServer),
          ),
        ],
      ),
      onTap: () => _open(context, ref),
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final router = GoRouter.of(context);

    // Activated before the push, not after: the home screen reads the active
    // server on its first build, and pushing first would show it the previous
    // one's libraries for a frame.
    if (!active) {
      await ref.read(serverRegistryProvider.notifier).activate(profile.id);
    }
    router.push('/servers/home');
  }

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    _ServerAction action,
  ) async {
    switch (action) {
      case _ServerAction.edit:
        await AddServerSheet.show(context, editing: profile);

      case _ServerAction.remove:
        final l10n = AppLocalizations.of(context);
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(l10n.removeServer),
            // Says what is *not* deleted. "Remove" next to a media server is
            // ambiguous enough to be worth a sentence.
            content: Text(l10n.removeServerBody(profile.name)),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(l10n.removeServer),
              ),
            ],
          ),
        );

        if (confirmed != true) return;
        await ref.read(serverRegistryProvider.notifier).remove(profile.id);
    }
  }
}

enum _ServerAction { edit, remove }

/// "10.1.1.5:8096 · dev" — the scheme is noise in a list.
String hostLineFor(ServerProfile profile) {
  final uri = Uri.tryParse(profile.uri);
  final host = uri == null
      ? profile.uri
      : (uri.hasPort ? '${uri.host}:${uri.port}' : uri.host);
  return profile.username.isEmpty ? host : '$host · ${profile.username}';
}
