// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

/// The screens around a server's PIN: the lock in front of a guarded server,
/// and the dialogs that set, change and remove it.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../servers/auto_connect.dart';
import '../../servers/server_pin.dart';
import '../../servers/server_profile.dart';
import '../../servers/server_registry.dart';

/// Wrong guesses allowed before a pause, and how long the pause is.
///
/// Not a defence against someone with time — the PIN is a lock on the app's
/// door — but it turns working through a four-digit space by hand from a
/// minute's tapping into an afternoon.
const int _triesBeforePause = 5;
const Duration _pause = Duration(seconds: 30);

/// The Home tab's face for a PIN-guarded server that has not been unlocked.
///
/// A whole screen rather than a dialog over the home: with the server locked,
/// nothing of its library is drawn behind it, and the navigation bar is gone
/// with the rest — so there is nothing to tap around it.
class PinLockPage extends ConsumerStatefulWidget {
  const PinLockPage({super.key, required this.profile});

  final ServerProfile profile;

  @override
  ConsumerState<PinLockPage> createState() => _PinLockPageState();
}

class _PinLockPageState extends ConsumerState<PinLockPage> {
  final _pin = TextEditingController();
  final _focus = FocusNode();

  bool _checking = false;
  String? _error;
  int _wrong = 0;

  /// Seconds left of the pause after too many wrong tries. Counted down by a
  /// ticker rather than measured against the wall clock, so a clock changed
  /// under it neither lengthens nor skips the pause.
  int _pauseSeconds = 0;
  Timer? _ticker;

  @override
  void dispose() {
    _ticker?.cancel();
    _pin.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool get _paused => _pauseSeconds > 0;

  Future<void> _unlock() async {
    final pin = _pin.text;
    if (_checking || _paused || pin.length < minPinLength) return;

    final l10n = AppLocalizations.of(context);
    setState(() {
      _checking = true;
      _error = null;
    });

    final ok = await ref
        .read(serverRegistryProvider.notifier)
        .verifyPinFor(widget.profile.id, pin);
    if (!mounted) return;

    if (ok) {
      ref.read(unlockedServersProvider.notifier).unlock(widget.profile.id);
      return;
    }

    _wrong++;
    _pin.clear();
    if (_wrong % _triesBeforePause == 0) {
      _pauseSeconds = _pause.inSeconds;
      _ticker?.cancel();
      _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        setState(() => _pauseSeconds--);
        if (!_paused) {
          timer.cancel();
          _focus.requestFocus();
        }
      });
    }
    setState(() {
      _checking = false;
      _error = l10n.pinWrong;
    });
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final scheme = context.colors;
    final l10n = AppLocalizations.of(context);
    final paused = _paused;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(spacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.lock_rounded,
                      size: 40,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  SizedBox(height: spacing.xl),
                  Text(
                    widget.profile.name,
                    textAlign: TextAlign.center,
                    style: context.texts.headlineSmall,
                  ),
                  SizedBox(height: spacing.sm),
                  Text(
                    l10n.pinEnterBody,
                    textAlign: TextAlign.center,
                    style: context.texts.bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  SizedBox(height: spacing.xl),
                  PinField(
                    controller: _pin,
                    focusNode: _focus,
                    label: l10n.pinEnterTitle,
                    autofocus: true,
                    enabled: !paused && !_checking,
                    errorText: paused
                        ? l10n.pinPaused('$_pauseSeconds')
                        : _error,
                    onChanged: (_) => setState(() => _error = null),
                    onSubmitted: (_) => _unlock(),
                  ),
                  SizedBox(height: spacing.lg),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: paused ||
                              _checking ||
                              _pin.text.length < minPinLength
                          ? null
                          : _unlock,
                      child: _checking
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l10n.pinUnlock),
                    ),
                  ),
                  SizedBox(height: spacing.sm),
                  // The way out for someone who is not meant to be here, or
                  // who forgot: another server needs no PIN to reach.
                  TextButton.icon(
                    icon: const Icon(Icons.swap_horiz_rounded),
                    label: Text(l10n.changeServer),
                    onPressed: () =>
                        ref.read(serverSessionProvider.notifier).leave(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A digits-only, obscured field for a PIN.
class PinField extends StatelessWidget {
  const PinField({
    super.key,
    required this.controller,
    required this.label,
    this.focusNode,
    this.autofocus = false,
    this.enabled = true,
    this.errorText,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction,
  });

  final TextEditingController controller;
  final String label;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool enabled;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      enabled: enabled,
      obscureText: true,
      obscuringCharacter: '●',
      keyboardType: TextInputType.number,
      textInputAction: textInputAction,
      textAlign: TextAlign.center,
      maxLength: maxPinLength,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.digitsOnly,
      ],
      style: context.texts.headlineSmall?.copyWith(letterSpacing: 10),
      decoration: InputDecoration(
        labelText: label,
        errorText: errorText,
        errorMaxLines: 2,
        counterText: '',
        border: const OutlineInputBorder(),
      ),
      onChanged: onChanged,
      onSubmitted: onSubmitted,
    );
  }
}

/// Sets a new PIN on [profile], asking for it twice. True once it is saved.
Future<bool> showSetPinDialog(BuildContext context, ServerProfile profile) async {
  final saved = await showDialog<bool>(
    context: context,
    builder: (_) => _SetPinDialog(profile: profile),
  );
  return saved ?? false;
}

class _SetPinDialog extends ConsumerStatefulWidget {
  const _SetPinDialog({required this.profile});

  final ServerProfile profile;

  @override
  ConsumerState<_SetPinDialog> createState() => _SetPinDialogState();
}

class _SetPinDialogState extends ConsumerState<_SetPinDialog> {
  final _first = TextEditingController();
  final _second = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _first.dispose();
    _second.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    if (!isValidPin(_first.text)) {
      setState(() => _error = l10n.pinLength);
      return;
    }
    if (_first.text != _second.text) {
      setState(() => _error = l10n.pinMismatch);
      return;
    }

    setState(() => _saving = true);
    final registry = ref.read(serverRegistryProvider.notifier);
    await registry.setPin(widget.profile.id, _first.text);
    // The person setting it is already in; asking them for it straight away
    // would be a test, not a lock.
    ref.read(unlockedServersProvider.notifier).unlock(widget.profile.id);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;

    return AlertDialog(
      icon: const Icon(Icons.lock_outline_rounded),
      title: Text(l10n.pinSetTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            l10n.pinSetBody,
            style: context.texts.bodyMedium
                ?.copyWith(color: context.colors.onSurfaceVariant),
          ),
          SizedBox(height: spacing.lg),
          PinField(
            controller: _first,
            label: l10n.pinNew,
            autofocus: true,
            enabled: !_saving,
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() => _error = null),
          ),
          SizedBox(height: spacing.md),
          PinField(
            controller: _second,
            label: l10n.pinConfirm,
            enabled: !_saving,
            errorText: _error,
            onChanged: (_) => setState(() => _error = null),
            onSubmitted: (_) => _save(),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(l10n.save),
        ),
      ],
    );
  }
}

/// Asks for [profile]'s current PIN. True when it was given correctly.
///
/// Changing or removing a PIN asks for it first: otherwise anyone handed the
/// unlocked phone could turn the lock off for next time.
Future<bool> showCheckPinDialog(
  BuildContext context,
  ServerProfile profile,
) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => _CheckPinDialog(profile: profile),
  );
  return ok ?? false;
}

class _CheckPinDialog extends ConsumerStatefulWidget {
  const _CheckPinDialog({required this.profile});

  final ServerProfile profile;

  @override
  ConsumerState<_CheckPinDialog> createState() => _CheckPinDialogState();
}

class _CheckPinDialogState extends ConsumerState<_CheckPinDialog> {
  final _pin = TextEditingController();
  String? _error;
  bool _checking = false;

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    if (_checking || _pin.text.length < minPinLength) return;

    final wrong = AppLocalizations.of(context).pinWrong;
    setState(() => _checking = true);
    final ok = await ref
        .read(serverRegistryProvider.notifier)
        .verifyPinFor(widget.profile.id, _pin.text);
    if (!mounted) return;

    if (ok) {
      Navigator.of(context).pop(true);
      return;
    }
    _pin.clear();
    setState(() {
      _checking = false;
      _error = wrong;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      icon: const Icon(Icons.lock_rounded),
      title: Text(l10n.pinCurrent),
      content: PinField(
        controller: _pin,
        label: l10n.pinEnterTitle,
        autofocus: true,
        enabled: !_checking,
        errorText: _error,
        onChanged: (_) => setState(() => _error = null),
        onSubmitted: (_) => _check(),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _checking ? null : () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _checking ? null : _check,
          child: Text(l10n.pinUnlock),
        ),
      ],
    );
  }
}

/// The Settings action for [profile]'s PIN: set one, or change or remove
/// the one it has.
Future<void> managePin(BuildContext context, WidgetRef ref, ServerProfile profile) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);

  if (!profile.pinProtected) {
    if (await showSetPinDialog(context, profile)) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.pinSaved)));
    }
    return;
  }

  final action = await showModalBottomSheet<_PinAction>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ListTile(
            leading: const Icon(Icons.password_rounded),
            title: Text(l10n.pinChange),
            onTap: () => Navigator.of(sheetContext).pop(_PinAction.change),
          ),
          ListTile(
            leading: const Icon(Icons.lock_open_rounded),
            title: Text(l10n.pinRemove),
            onTap: () => Navigator.of(sheetContext).pop(_PinAction.remove),
          ),
        ],
      ),
    ),
  );
  if (action == null || !context.mounted) return;
  if (!await showCheckPinDialog(context, profile) || !context.mounted) return;

  switch (action) {
    case _PinAction.change:
      if (await showSetPinDialog(context, profile)) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.pinSaved)));
      }
    case _PinAction.remove:
      await ref.read(serverRegistryProvider.notifier).setPin(profile.id, null);
      messenger.showSnackBar(SnackBar(content: Text(l10n.pinRemoved)));
  }
}

enum _PinAction { change, remove }
