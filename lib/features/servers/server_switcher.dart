// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../servers/server_profile.dart';
import '../../servers/server_registry.dart';
import 'add_server_sheet.dart';

/// The list of configured servers, and what can be done to one.
///
/// This exists because the servers home has no route under it to go back to:
/// once a server is added the Server tab *is* the home, so its app bar used
/// to carry a back button with nothing to pop — a control that did nothing at
/// all. The list it should have opened is this.
class ServerSwitcherSheet extends ConsumerWidget {
  const ServerSwitcherSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) => const ServerSwitcherSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = context.spacing;
    final scheme = context.colors;
    final l10n = AppLocalizations.of(context);
    final registry = ref.watch(serverRegistryProvider);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.fromLTRB(
              spacing.lg,
              spacing.lg,
              spacing.lg,
              spacing.sm,
            ),
            child: Text(l10n.switchServer, style: context.texts.titleMedium),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: <Widget>[
                for (final ServerProfile profile in registry.profiles)
                  ListTile(
                    leading: Icon(
                      profile.id == registry.activeId
                          ? Icons.dns_rounded
                          : Icons.dns_outlined,
                      color: profile.id == registry.activeId
                          ? scheme.primary
                          : null,
                    ),
                    title: Text(profile.name),
                    subtitle: Text(
                      _hostLine(profile),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: PopupMenuButton<_ServerAction>(
                      icon: const Icon(Icons.more_vert_rounded),
                      onSelected: (action) =>
                          _run(context, ref, profile, action),
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
                    selected: profile.id == registry.activeId,
                    onTap: () async {
                      final navigator = Navigator.of(context);
                      await ref
                          .read(serverRegistryProvider.notifier)
                          .activate(profile.id);
                      navigator.pop();
                    },
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.add_rounded),
            title: Text(l10n.addServer),
            onTap: () {
              // Closed first: the add sheet is a sheet too, and stacking one
              // on the other leaves this list behind it when the add is done.
              Navigator.of(context).pop();
              AddServerSheet.show(context);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    ServerProfile profile,
    _ServerAction action,
  ) async {
    switch (action) {
      case _ServerAction.edit:
        Navigator.of(context).pop();
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

  /// "10.1.1.5:8096 · dev" — the scheme is noise in a list.
  static String _hostLine(ServerProfile profile) {
    final uri = Uri.tryParse(profile.uri);
    final host = uri == null
        ? profile.uri
        : (uri.hasPort ? '${uri.host}:${uri.port}' : uri.host);
    return profile.username.isEmpty ? host : '$host · ${profile.username}';
  }
}

enum _ServerAction { edit, remove }
