// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../servers/media_library_source.dart';
import '../servers/server_library.dart';

/// Approves another device's Quick Connect code, signing it in as this user.
///
/// The half of Quick Connect the add-server sheet does not cover: there this
/// app shows a code and waits; here it is the device already signed in, and
/// a television or a friend's phone is the one showing the code.
Future<void> showQuickConnectDialog(BuildContext context) async {
  final approved = await showDialog<bool>(
    context: context,
    builder: (_) => const _QuickConnectDialog(),
  );
  if (approved != true || !context.mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(AppLocalizations.of(context).quickConnectApproved)),
  );
}

class _QuickConnectDialog extends ConsumerStatefulWidget {
  const _QuickConnectDialog();

  @override
  ConsumerState<_QuickConnectDialog> createState() =>
      _QuickConnectDialogState();
}

class _QuickConnectDialogState extends ConsumerState<_QuickConnectDialog> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  /// Jellyfin's codes are six digits.
  static const _length = 6;

  bool get _complete => _code.text.trim().length == _length;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _approve() async {
    final source = ref.read(connectedServerProvider);
    if (source == null || !_complete || _busy) return;

    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final answer = await source.authorizeQuickConnect(_code.text);
      if (!mounted) return;

      switch (answer) {
        case QuickConnectApproval.approved:
          Navigator.of(context).pop(true);
          return;
        case QuickConnectApproval.unknownCode:
          _error = l10n.quickConnectUnknownCode;
        case QuickConnectApproval.refused:
          _error = l10n.quickConnectRefused;
      }
    } on ServerException catch (e) {
      _error = e.message;
    }

    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final scheme = context.colors;

    return AlertDialog(
      icon: const Icon(Icons.phonelink_lock_rounded),
      title: Text(l10n.quickConnectTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l10n.quickConnectBody,
            style: context.texts.bodyMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          SizedBox(height: spacing.lg),
          TextField(
            controller: _code,
            autofocus: true,
            enabled: !_busy,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: _length,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
            ],
            style: context.texts.headlineMedium?.copyWith(
              letterSpacing: 8,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
            decoration: InputDecoration(
              labelText: l10n.quickConnectCode,
              errorText: _error,
              errorMaxLines: 3,
              // The counter says "3/6", which the digits themselves say.
              counterText: '',
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() => _error = null),
            onSubmitted: (_) => _approve(),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _complete && !_busy ? _approve : null,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.quickConnectApprove),
        ),
      ],
    );
  }
}
