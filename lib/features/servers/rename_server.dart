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

/// Asks for a new name for [profile] and keeps it on this device.
///
/// The profile's own name, marked as given here so that editing the server's
/// address or account later does not put the server's name back over it.
/// The server keeps the name it calls itself; renaming the server itself is
/// a separate, administrator-only act.
Future<void> renameServer(
  BuildContext context,
  WidgetRef ref,
  ServerProfile profile,
) async {
  final name = await showDialog<String>(
    context: context,
    builder: (_) => _RenameDialog(initial: profile.name),
  );

  final trimmed = name?.trim();
  if (trimmed == null ||
      trimmed.isEmpty ||
      trimmed == profile.name ||
      !context.mounted) {
    return;
  }

  await ref
      .read(serverRegistryProvider.notifier)
      .rename(profile.id, trimmed, custom: true);
}

/// Owns its text controller, so the controller lives exactly as long as the
/// field: disposed by the caller after `showDialog` returned, it was gone
/// while the dialog was still animating closed and the field still drew.
class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initial});

  final String initial;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      title: Text(l10n.adminRename),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(labelText: l10n.adminRenameHint),
            onSubmitted: (v) => Navigator.of(context).pop(v),
          ),
          SizedBox(height: context.spacing.md),
          // Said before Save, not after: a name only this device knows
          // surprises someone who expected the web app to change too.
          Text(
            l10n.renameServerLocal,
            style: context.texts.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(l10n.actionSave),
        ),
      ],
    );
  }
}
