// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';

import '../../app/tokens.dart';

/// Screen 1c, second frame — the modal "Add a server" bottom sheet.
///
/// The address field probes the server as you type; Quick Connect is on by
/// default, which hides the password field because approval happens on another
/// signed-in device. The actual probe and auth land with the Jellyfin client
/// (build step 5) — [onSubmit] is where that wiring goes.
class AddServerSheet extends StatefulWidget {
  const AddServerSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const AddServerSheet(),
    );
  }

  @override
  State<AddServerSheet> createState() => _AddServerSheetState();
}

class _AddServerSheetState extends State<AddServerSheet> {
  final _address = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();

  bool _quickConnect = true;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _address.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final scheme = context.colors;

    return Padding(
      // Lift the sheet above the keyboard rather than letting it overlap.
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            spacing.xl,
            0,
            spacing.xl,
            spacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Add a server',
                  style: context.texts.headlineSmall,
                ),
              ),
              SizedBox(height: spacing.xl - spacing.xs),
              TextField(
                controller: _address,
                autofocus: true,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  filled: true,
                  labelText: 'Server address',
                  hintText: 'http://192.168.1.20:8096',
                  border: UnderlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  spacing.lg,
                  spacing.xs,
                  spacing.lg,
                  0,
                ),
                child: Text(
                  _detectionLine,
                  style: context.texts.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
              SizedBox(height: spacing.xl - spacing.xs),
              TextField(
                controller: _username,
                decoration: const InputDecoration(labelText: 'Username'),
              ),
              if (!_quickConnect) ...<Widget>[
                SizedBox(height: spacing.lg),
                TextField(
                  controller: _password,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    suffixIcon: IconButton(
                      tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                      ),
                      onPressed: () => setState(
                        () => _obscurePassword = !_obscurePassword,
                      ),
                    ),
                  ),
                ),
              ],
              SizedBox(height: spacing.lg),
              SwitchListTile(
                value: _quickConnect,
                onChanged: (v) => setState(() => _quickConnect = v),
                contentPadding: EdgeInsets.zero,
                title: const Text('Quick connect instead'),
                subtitle: const Text('Approve from another signed-in device'),
              ),
              SizedBox(height: spacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  SizedBox(width: spacing.sm),
                  FilledButton(
                    onPressed: _address.text.trim().isEmpty ? null : _submit,
                    child: const Text('Connect'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Stands in for the real `/System/Info/Public` probe.
  String get _detectionLine {
    if (_address.text.trim().isEmpty) {
      return 'Enter an address to detect the server';
    }
    return 'Detection runs once the Jellyfin client lands';
  }

  void _submit() {
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Server connection — not implemented yet')),
    );
  }
}
