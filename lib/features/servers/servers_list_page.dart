// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../servers/auto_connect.dart';
import '../../servers/server_profile.dart';
import '../../servers/server_registry.dart';
import 'add_server_sheet.dart';

/// The Home tab's face once anything is configured and no server has been
/// opened yet this launch — or after "Switch server".
///
/// Opening a server is not a navigation: it marks the session entered, and
/// [HomeTabPage] swaps this list for the server's home in the same tab. With
/// [autoConnectProvider] on, that happens by itself at launch and this list
/// is never seen unless the stored sign-in has lapsed.
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
      title: Row(
        children: <Widget>[
          Flexible(
            child: Text(
              profile.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Said before the tap, so a PIN screen is not a surprise.
          if (profile.pinProtected) ...<Widget>[
            const SizedBox(width: 6),
            Icon(
              Icons.lock_rounded,
              size: 16,
              color: scheme.onSurfaceVariant,
              semanticLabel: l10n.pinLockTitle,
            ),
          ],
        ],
      ),
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
    final session = ref.read(serverSessionProvider.notifier);

    // Activated before entering, not after: the home reads the active server
    // on its first build, and entering first would show it the previous
    // one's libraries for a frame.
    if (!active) {
      await ref.read(serverRegistryProvider.notifier).activate(profile.id);
    }
    // A lapsed sign-in leaves no client; the home has nothing to show then,
    // and the list stays up.
    if (ref.read(serverRegistryProvider).source == null) return;
    session.enter();
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
