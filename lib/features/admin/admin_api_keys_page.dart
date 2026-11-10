// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../servers/server_admin.dart';
import 'admin_providers.dart';
import 'admin_widgets.dart';

/// Keys outside programs sign in with — a Sonarr, a Home Assistant.
///
/// A key is a password, so it is **masked** in the list and only ever leaves
/// the screen through Copy, which is what one is wanted for.
class AdminApiKeysPage extends ConsumerWidget {
  const AdminApiKeysPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final keys = ref.watch(apiKeysProvider);

    return AdminScaffold(
      title: l10n.adminApiKeys,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'admin-add-api-key',
        onPressed: () => _create(context, ref),
        icon: const Icon(Icons.key_rounded),
        label: Text(l10n.adminNewApiKey),
      ),
      onRefresh: () async {
        ref.invalidate(apiKeysProvider);
        await ref.read(apiKeysProvider.future);
      },
      child: switch (keys) {
        AsyncError(:final error) => AdminList(
          emptyText: '$error',
          children: const <Widget>[],
        ),
        _ => AdminList(
          loading: keys.isLoading,
          emptyText: l10n.adminNoApiKeys,
          children: <Widget>[
            for (final ServerApiKey key in keys.value ?? const <ServerApiKey>[])
              _KeyRow(apiKey: key),
          ],
        ),
      },
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _AppNameDialog(),
    );
    if (name == null || name.trim().isEmpty || !context.mounted) return;

    await runAdminAction(
      context,
      ref,
      action: (admin) => admin.createApiKey(name),
      success: l10n.adminApiKeyCreated(name.trim()),
      refresh: () => ref.invalidate(apiKeysProvider),
    );
  }
}

class _KeyRow extends ConsumerWidget {
  const _KeyRow({required this.apiKey});

  final ServerApiKey apiKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final name = apiKey.appName.isEmpty
        ? l10n.adminApiKeyUnnamed
        : apiKey.appName;

    return ListTile(
      leading: const Icon(Icons.key_outlined),
      title: Text(name),
      subtitle: Text(
        <String>[
          maskKey(apiKey.token),
          relativeTime(apiKey.created, l10n),
        ].where((s) => s.isNotEmpty).join(' · '),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconButton(
            icon: const Icon(Icons.copy_rounded),
            tooltip: l10n.adminCopyApiKey,
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              await Clipboard.setData(ClipboardData(text: apiKey.token));
              messenger.showSnackBar(
                SnackBar(content: Text(l10n.adminApiKeyCopied)),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: l10n.adminRevokeApiKey,
            onPressed: () async {
              final sure = await confirmAdminAction(
                context,
                title: l10n.adminRevokeApiKeyQuestion(name),
                body: l10n.adminRevokeApiKeyBody,
                confirmLabel: l10n.adminRevokeApiKey,
              );
              if (!sure || !context.mounted) return;
              await runAdminAction(
                context,
                ref,
                action: (admin) => admin.revokeApiKey(apiKey.token),
                success: l10n.adminApiKeyRevoked(name),
                refresh: () => ref.invalidate(apiKeysProvider),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// The first and last four characters, the rest dots: enough to tell keys
/// apart, not enough to use one read off a screen over a shoulder.
String maskKey(String token) {
  if (token.length <= 8) return '•' * token.length;
  return '${token.substring(0, 4)}••••${token.substring(token.length - 4)}';
}

class _AppNameDialog extends StatefulWidget {
  const _AppNameDialog();

  @override
  State<_AppNameDialog> createState() => _AppNameDialogState();
}

class _AppNameDialogState extends State<_AppNameDialog> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.adminNewApiKey),
      content: TextField(
        controller: _name,
        autofocus: true,
        decoration: InputDecoration(
          labelText: l10n.adminApiKeyApp,
          helperText: l10n.adminApiKeyAppHint,
        ),
        onChanged: (_) => setState(() {}),
        onSubmitted: (v) => Navigator.of(context).pop(v),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: _name.text.trim().isEmpty
              ? null
              : () => Navigator.of(context).pop(_name.text),
          child: Text(l10n.adminCreate),
        ),
      ],
    );
  }
}
