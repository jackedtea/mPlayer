// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/tokens.dart';
import '../../servers/jellyfin_source.dart';
import '../../servers/media_library_source.dart';
import '../../l10n/app_localizations.dart';
import '../../servers/server_profile.dart';
import '../../servers/auto_connect.dart';
import '../../servers/server_registry.dart';

/// Screen 1c, second frame — the modal "Add a server" bottom sheet.
///
/// The address is probed as it is typed, before any password is asked for:
/// telling someone their address is wrong is far better than leaving them to
/// wonder whether their password is.
class AddServerSheet extends ConsumerStatefulWidget {
  const AddServerSheet({super.key, this.editing});

  /// The server being changed, or null when one is being added.
  ///
  /// Editing keeps the profile's id, so the stored token and every resume
  /// point written against this server survive a move to a new address. It
  /// still goes through the whole probe-and-sign-in flow: an address or a
  /// password that changed has to be proved before it replaces one that
  /// works.
  final ServerProfile? editing;

  static Future<void> show(BuildContext context, {ServerProfile? editing}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => AddServerSheet(editing: editing),
    );
  }

  @override
  ConsumerState<AddServerSheet> createState() => _AddServerSheetState();
}

/// What the sheet is doing, which decides everything it shows.
enum _Stage {
  typing,
  probing,
  found,

  /// Editing a server whose stored session still works.
  ///
  /// Nothing to type: the app already holds a credential this address
  /// accepts, so the sheet has one button on it and no password field.
  signedIn,

  signingIn,
  waitingForApproval,
}

class _AddServerSheetState extends ConsumerState<AddServerSheet> {
  final _address = TextEditingController();

  /// The name this device shows for the server being edited. Absent when
  /// adding: a server not yet found has no name to start from.
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();

  _Stage _stage = _Stage.typing;
  ServerInfo? _server;
  bool _quickConnectAvailable = false;
  bool _quickConnect = false;
  QuickConnectRequest? _quickConnectRequest;

  /// What went wrong finding the server — said under the address.
  String? _error;

  /// What went wrong signing in — said under the account, where the thing to
  /// fix is. A wrong password reported under the address reads as a wrong
  /// address.
  String? _signInError;

  bool _obscurePassword = true;

  /// Bumped to abandon a Quick Connect attempt: on cancel, on a new code, and
  /// when the sheet closes. The poll checks it, so an abandoned code stops
  /// being asked about at once rather than at its deadline.
  int _quickConnectAttempt = 0;

  /// Seconds left before the code on screen stops being waited on, counted
  /// down by [_ticker].
  int _codeSeconds = 0;

  /// Redraws the countdown once a second while a code is up.
  Timer? _ticker;

  /// Whether the code was just copied, which the copy button says briefly.
  bool _copied = false;

  Timer? _debounce;
  JellyfinAuth? _auth;

  /// The session already stored for the server being edited, once it has been
  /// checked and found to still work. Null means a password is needed.
  AuthResult? _existingSession;

  /// Bumped whenever the address changes, so a probe that finishes after the
  /// user has typed on cannot overwrite a newer answer.
  int _probeGeneration = 0;

  @override
  void initState() {
    super.initState();

    final editing = widget.editing;
    if (editing == null) return;

    // Prefilled, then probed straight away: the sheet opens on a server it
    // already knows the address of, and making the user re-trigger detection
    // by typing a character is busywork.
    _address.text = editing.uri;
    _name.text = editing.name;
    _username.text = editing.username;
    WidgetsBinding.instance.addPostFrameCallback((_) => _onAddressChanged());
  }

  @override
  void dispose() {
    _quickConnectAttempt++;
    _ticker?.cancel();
    _debounce?.cancel();
    unawaited(_auth?.dispose());
    _address.dispose();
    _name.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<JellyfinAuth> _authService() async {
    return _auth ??= await ref.read(serverRegistryProvider.notifier).auth();
  }

  // ------------------------------------------------------------- probing

  void _onAddressChanged() {
    _debounce?.cancel();
    setState(() {
      _server = null;
      _error = null;
      // Checked against the address that was there a moment ago, which is not
      // the one being typed now.
      _existingSession = null;
      _quickConnectAvailable = false;
      _stage = _address.text.trim().isEmpty ? _Stage.typing : _Stage.probing;
    });

    if (_address.text.trim().isEmpty) return;
    // Long enough that a probe is not fired at every keystroke of a host name.
    _debounce = Timer(const Duration(milliseconds: 700), _probe);
  }

  Future<void> _probe() async {
    final generation = ++_probeGeneration;
    final address = _address.text.trim();

    try {
      final auth = await _authService();
      final info = await auth.probe(address);
      final quickConnect = await auth.isQuickConnectEnabled(info);

      if (!mounted || generation != _probeGeneration) return;
      setState(() {
        _server = info;
        _quickConnectAvailable = quickConnect;
        if (!quickConnect) _quickConnect = false;
        _stage = _Stage.found;
        _error = null;
        _signInError = null;
      });

      await _tryStoredSession(info, generation);
    } on ServerException catch (e) {
      if (!mounted || generation != _probeGeneration) return;
      setState(() {
        _server = null;
        _error = e.message;
        _stage = _Stage.typing;
      });
    }
  }

  // ------------------------------------------------------------ signing in

  Future<void> _signIn() async {
    final server = _server;
    if (server == null) return;

    setState(() {
      _stage = _Stage.signingIn;
      _signInError = null;
    });

    try {
      final auth = await _authService();
      final result = await auth.signIn(
        server,
        username: _username.text.trim(),
        password: _password.text,
      );

      await _finish(server, result);
    } on ServerException catch (e) {
      if (!mounted) return;
      setState(() {
        _signInError = e.message;
        _stage = _Stage.found;
      });
    }
  }

  /// Sees whether the credential already held still opens this address.
  ///
  /// Renaming a server, or moving it to an address it answers on just the
  /// same, does not invalidate the session stored for it — so demanding the
  /// password again is asking the user to re-prove something the app can
  /// check for itself. It only falls through to the form when the server
  /// actually refuses the token.
  Future<void> _tryStoredSession(ServerInfo info, int generation) async {
    final editing = widget.editing;
    if (editing == null) return;

    final token = await ref
        .read(serverRegistryProvider.notifier)
        .tokenFor(editing.id);
    if (token == null || token.isEmpty) return;
    if (!mounted || generation != _probeGeneration) return;

    try {
      final auth = await _authService();
      final session = await auth.validate(info, token);
      if (!mounted || generation != _probeGeneration) return;
      if (session == null) return;

      setState(() {
        _existingSession = session;
        _username.text = session.username;
        _stage = _Stage.signedIn;
      });
    } on ServerException {
      // Unreachable rather than refused. The form is still the right next
      // step, and the probe has already said what went wrong.
      return;
    }
  }

  /// Saves an edit that needed no new password.
  Future<void> _saveWithStoredSession() async {
    final server = _server;
    final session = _existingSession;
    if (server == null || session == null) return;

    setState(() => _stage = _Stage.signingIn);
    await _finish(server, session);
  }

  /// Asks the server for a code, shows it, and waits for another device to
  /// approve it. Called again for a new code, which abandons the old one.
  Future<void> _startQuickConnect() async {
    final server = _server;
    if (server == null) return;

    final expired = AppLocalizations.of(context).quickConnectExpired;
    final attempt = ++_quickConnectAttempt;
    bool cancelled() => !mounted || attempt != _quickConnectAttempt;

    setState(() {
      _signInError = null;
      _quickConnectRequest = null;
      _codeSeconds = 0;
      _copied = false;
      _stage = _Stage.waitingForApproval;
    });

    try {
      final auth = await _authService();
      final request = await auth.initiateQuickConnect(server);
      if (cancelled()) return;

      setState(() {
        _quickConnectRequest = request;
        _codeSeconds = JellyfinAuth.quickConnectTimeout.inSeconds;
      });
      _ticker?.cancel();
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted && _codeSeconds > 0) setState(() => _codeSeconds--);
      });

      final result = await auth.awaitQuickConnect(
        server,
        request,
        cancelled: cancelled,
      );
      if (cancelled()) return;
      _ticker?.cancel();

      if (result == null) {
        // Nobody approved it in time. Said in words, with the way on: the
        // panel used to vanish back into the form with no reason given.
        setState(() {
          _quickConnectRequest = null;
          _signInError = expired;
          _stage = _Stage.found;
        });
        return;
      }

      setState(() => _stage = _Stage.signingIn);
      await _finish(server, result);
    } on ServerException catch (e) {
      if (cancelled()) return;
      _ticker?.cancel();
      setState(() {
        _signInError = e.message;
        _quickConnectRequest = null;
        _stage = _Stage.found;
      });
    }
  }

  /// Backs out of waiting, to the form — not out of the sheet.
  void _cancelQuickConnect() {
    _quickConnectAttempt++;
    _ticker?.cancel();
    setState(() {
      _quickConnectRequest = null;
      _codeSeconds = 0;
      _stage = _Stage.found;
    });
  }

  Future<void> _copyCode() async {
    final code = _quickConnectRequest?.code;
    if (code == null) return;

    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    setState(() => _copied = true);
    // Back to the copy glyph, so a second copy has something to confirm.
    Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  /// What is left of the code's time.
  Duration get _remaining => Duration(seconds: _codeSeconds);

  Future<void> _finish(ServerInfo server, AuthResult result) async {
    final registry = ref.read(serverRegistryProvider.notifier);
    final editing = widget.editing;

    if (editing == null) {
      await registry.add(info: server, auth: result);
      // A server just added is the one the user wants to be in, whether or
      // not launches open the last one by themselves.
      if (ref.read(serverRegistryProvider).source != null) {
        ref.read(serverSessionProvider.notifier).enter();
      }
    } else {
      await registry.updateProfile(
        editing.id,
        info: server,
        auth: result,
        name: _name.text,
      );
    }

    if (mounted) Navigator.of(context).pop();
  }

  // ------------------------------------------------------------------ UI

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final l10n = AppLocalizations.of(context);
    final waiting = _stage == _Stage.waitingForApproval;
    final busy = _stage == _Stage.signingIn || waiting;

    return Padding(
      // Lift the sheet above the keyboard rather than letting it overlap.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(spacing.xl, 0, spacing.xl, spacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _SheetHeader(editing: widget.editing != null),
              SizedBox(height: spacing.xl),

              // ---------------------------------------------- 1. server
              _StepLabel(number: 1, text: l10n.addServerStepServer),
              SizedBox(height: spacing.sm),
              TextField(
                controller: _address,
                autofocus: widget.editing == null,
                keyboardType: TextInputType.url,
                autocorrect: false,
                enabled: !busy,
                decoration: _fieldDecoration(
                  context,
                  label: l10n.serverAddress,
                  icon: Icons.link_rounded,
                  // Not translated: an address is an address, and the design
                  // uses this exact one as its example.
                  hint: 'http://192.168.1.20:8096',
                  suffix: _server != null
                      ? Icon(
                          Icons.check_circle_rounded,
                          color: context.semantic.success,
                        )
                      : (_error != null
                            ? Icon(
                                Icons.error_rounded,
                                color: context.colors.error,
                              )
                            : null),
                ),
                onChanged: (_) => _onAddressChanged(),
              ),
              SizedBox(height: spacing.sm),
              // A found server is a card, so the step reads as done; until
              // then the line under the field prompts or says what is wrong.
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _server != null
                    ? _ServerCard(
                        key: const ValueKey('found'),
                        server: _server!,
                      )
                    : Padding(
                        key: const ValueKey('line'),
                        padding: EdgeInsets.symmetric(horizontal: spacing.lg),
                        child: _DetectionLine(error: _error),
                      ),
              ),
              if (widget.editing != null) ...<Widget>[
                SizedBox(height: spacing.md),
                TextField(
                  controller: _name,
                  enabled: !busy,
                  textInputAction: TextInputAction.next,
                  decoration: _fieldDecoration(
                    context,
                    label: l10n.adminRenameHint,
                    icon: Icons.drive_file_rename_outline_rounded,
                    // Emptying the field is how to hand the name back to the
                    // server, so the hint shows which name that is.
                    hint: _server?.name,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    spacing.lg,
                    spacing.xs,
                    spacing.lg,
                    0,
                  ),
                  // Said here, not after Save: a name only this device knows
                  // surprises someone who expected the web app to change too.
                  child: Text(
                    l10n.renameServerLocal,
                    style: context.texts.bodySmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
              SizedBox(height: spacing.xl),

              // --------------------------------------------- 2. account
              _StepLabel(number: 2, text: l10n.addServerStepAccount),
              SizedBox(height: spacing.sm),
              if (_signedInAlready)
                // No password field, because none is needed: the credential
                // already stored was just checked against this address and
                // accepted. Asking again would be asking the user to re-prove
                // something the app can verify for itself.
                _SignedInCard(
                  username: _existingSession!.username,
                  // A way out for the case this cannot detect: the account
                  // itself is being changed, not just the address.
                  onChange: () => setState(() {
                    _existingSession = null;
                    _password.clear();
                    _stage = _Stage.found;
                  }),
                )
              else if (waiting)
                _QuickConnectPanel(
                  request: _quickConnectRequest,
                  remaining: _remaining,
                  copied: _copied,
                  onCopy: _copyCode,
                )
              else ...<Widget>[
                // Offered once a server is found — before that there is
                // nothing to sign in to. Shown even where the server has it
                // switched off, greyed with a sentence saying so: a choice
                // that silently is not there is a feature nobody learns of.
                if (_server != null) ...<Widget>[
                  SegmentedButton<bool>(
                    segments: <ButtonSegment<bool>>[
                      ButtonSegment<bool>(
                        value: false,
                        icon: const Icon(Icons.password_rounded),
                        label: Text(l10n.password),
                      ),
                      ButtonSegment<bool>(
                        value: true,
                        enabled: _quickConnectAvailable,
                        icon: const Icon(Icons.qr_code_rounded),
                        label: Text(l10n.quickConnectShort),
                      ),
                    ],
                    selected: <bool>{_quickConnect},
                    onSelectionChanged: (v) => setState(() {
                      _quickConnect = v.single;
                      _signInError = null;
                    }),
                  ),
                  if (!_quickConnectAvailable)
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        spacing.xs,
                        spacing.sm,
                        spacing.xs,
                        0,
                      ),
                      child: Text(
                        l10n.quickConnectOff,
                        style: context.texts.bodySmall?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  SizedBox(height: spacing.md),
                ],
                if (_quickConnect)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: spacing.xs),
                    child: Text(
                      l10n.quickConnectHint,
                      style: context.texts.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  )
                else ...<Widget>[
                  TextField(
                    controller: _username,
                    autocorrect: false,
                    textInputAction: TextInputAction.next,
                    autofillHints: const <String>[AutofillHints.username],
                    decoration: _fieldDecoration(
                      context,
                      label: l10n.username,
                      icon: Icons.person_outline_rounded,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  SizedBox(height: spacing.md),
                  TextField(
                    controller: _password,
                    obscureText: _obscurePassword,
                    autofillHints: const <String>[AutofillHints.password],
                    onSubmitted: (_) => _canSignIn ? _signIn() : null,
                    decoration: _fieldDecoration(
                      context,
                      label: l10n.password,
                      icon: Icons.lock_outline_rounded,
                      suffix: IconButton(
                        tooltip: _obscurePassword
                            ? l10n.showPassword
                            : l10n.hidePassword,
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
              ],

              if (_signInError != null)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    spacing.xs,
                    spacing.md,
                    spacing.xs,
                    0,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(
                        Icons.error_outline_rounded,
                        size: 18,
                        color: context.colors.error,
                      ),
                      SizedBox(width: spacing.sm),
                      Expanded(
                        child: Text(
                          _signInError!,
                          style: context.texts.bodySmall?.copyWith(
                            color: context.colors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              SizedBox(height: spacing.xl),
              if (waiting)
                // While a code is up the primary action is a fresh one — the
                // likeliest reason to touch anything is a code that expired
                // or was mistyped on the other device.
                SizedBox(
                  height: 52,
                  child: FilledButton.tonalIcon(
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(l10n.quickConnectNewCode),
                    onPressed: _quickConnectRequest == null
                        ? null
                        : _startQuickConnect,
                  ),
                )
              else
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: busy
                        ? null
                        : _signedInAlready
                        ? _saveWithStoredSession
                        : (_quickConnect
                              ? (_server == null ? null : _startQuickConnect)
                              : (_canSignIn ? _signIn : null)),
                    // The spinner sits in the button it belongs to, so the
                    // button does not vanish from under the thumb that pressed
                    // it.
                    child: busy
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: context.colors.onSurfaceVariant,
                            ),
                          )
                        : Text(
                            _signedInAlready
                                ? l10n.save
                                : (_quickConnect
                                      ? l10n.getACode
                                      : l10n.connect),
                          ),
                  ),
                ),
              SizedBox(height: spacing.xs),
              TextButton(
                // While waiting, back to the form; otherwise out of the sheet.
                onPressed: waiting
                    ? _cancelQuickConnect
                    : () => Navigator.of(context).pop(),
                child: Text(l10n.cancel),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Editing a server the app can still open without being told anything.
  bool get _signedInAlready =>
      _stage == _Stage.signedIn && _existingSession != null;

  bool get _canSignIn =>
      _server != null &&
      _username.text.trim().isNotEmpty &&
      _stage == _Stage.found;
}

/// The rounded, filled field every input on the sheet uses.
InputDecoration _fieldDecoration(
  BuildContext context, {
  required String label,
  required IconData icon,
  String? hint,
  Widget? suffix,
}) {
  final radius = BorderRadius.circular(context.radii.card);

  return InputDecoration(
    labelText: label,
    hintText: hint,
    filled: true,
    fillColor: context.colors.surfaceContainerHigh,
    prefixIcon: Icon(icon),
    suffixIcon: suffix,
    border: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: context.colors.primary, width: 2),
    ),
  );
}

/// The app mark, the title, and a sentence saying what the sheet is for.
class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.editing});

  final bool editing;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final scheme = context.colors;
    final l10n = AppLocalizations.of(context);

    return Row(
      children: <Widget>[
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(context.radii.card),
          ),
          child: Icon(
            editing ? Icons.edit_rounded : Icons.dns_rounded,
            color: scheme.onPrimaryContainer,
          ),
        ),
        SizedBox(width: spacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                editing ? l10n.editServer : l10n.addServer,
                style: context.texts.headlineSmall,
              ),
              SizedBox(height: spacing.xs),
              Text(
                l10n.addServerSub,
                style: context.texts.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// "① Server" — the numbered heading over each half of the sheet.
class _StepLabel extends StatelessWidget {
  const _StepLabel({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return Row(
      children: <Widget>[
        CircleAvatar(
          radius: 10,
          backgroundColor: scheme.primary,
          child: Text(
            '$number',
            style: context.texts.labelSmall?.copyWith(color: scheme.onPrimary),
          ),
        ),
        SizedBox(width: context.spacing.sm),
        Text(
          text,
          style: context.texts.titleSmall?.copyWith(color: scheme.primary),
        ),
      ],
    );
  }
}

/// The server the address answered with.
class _ServerCard extends StatelessWidget {
  const _ServerCard({super.key, required this.server});

  final ServerInfo server;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final scheme = context.colors;
    final host = Uri.tryParse(server.uri)?.authority ?? server.uri;

    return Container(
      padding: EdgeInsets.all(spacing.md),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: context.radii.cardAll,
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.check_circle_rounded, color: context.semantic.success),
          SizedBox(width: spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  server.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.texts.titleSmall?.copyWith(
                    color: scheme.onSecondaryContainer,
                  ),
                ),
                Text(
                  <String>[
                    'Jellyfin ${server.version}'.trim(),
                    host,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.texts.bodySmall?.copyWith(
                    color: scheme.onSecondaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The stored session that still opens the server being edited.
class _SignedInCard extends StatelessWidget {
  const _SignedInCard({required this.username, required this.onChange});

  final String username;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Container(
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerHigh,
        borderRadius: context.radii.cardAll,
      ),
      child: ListTile(
        leading: Icon(
          Icons.verified_user_rounded,
          color: context.semantic.success,
        ),
        title: Text(l10n.signedInAs(username)),
        subtitle: Text(l10n.signInAgain),
        trailing: TextButton(onPressed: onChange, child: Text(l10n.change)),
      ),
    );
  }
}

/// The line under the address field: a prompt, or what went wrong.
class _DetectionLine extends StatelessWidget {
  const _DetectionLine({required this.error});

  final String? error;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    if (error != null) {
      return Text(
        error!,
        style: context.texts.bodySmall?.copyWith(color: scheme.error),
      );
    }

    // Nothing is said while the probe is in flight. It fires on every pause
    // in typing, so a spinner and "Looking for a server…" appeared and
    // vanished under the address field on the way to typing one — motion
    // reporting on the app's own busywork rather than on anything the user
    // asked about. The outcome is what matters, and it arrives either way.
    return Text(
      AppLocalizations.of(context).detectHint,
      style: context.texts.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
    );
  }
}

/// The code to enter on the other device, how long it has left, and a way to
/// copy it, while this device waits for it to be approved.
class _QuickConnectPanel extends StatelessWidget {
  const _QuickConnectPanel({
    required this.request,
    required this.remaining,
    required this.copied,
    required this.onCopy,
  });

  /// Null while the server is still issuing the code.
  final QuickConnectRequest? request;
  final Duration remaining;
  final bool copied;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final scheme = context.colors;
    final l10n = AppLocalizations.of(context);
    final code = request?.code;
    final total = JellyfinAuth.quickConnectTimeout.inSeconds;
    final minutes = remaining.inMinutes;
    final seconds = (remaining.inSeconds % 60).toString().padLeft(2, '0');

    return Container(
      padding: EdgeInsets.all(spacing.lg),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: context.radii.cardAll,
      ),
      child: Column(
        children: <Widget>[
          Text(l10n.enterCodeInJellyfin, style: context.texts.bodyMedium),
          SizedBox(height: spacing.md),
          if (code == null)
            const Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                // Left room for the copy button on the other side, so the
                // code itself is what sits in the middle.
                const SizedBox(width: 48),
                // Shrinks rather than overflowing: six wide-spaced digits at
                // display size do not fit a narrow phone beside two buttons.
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      code,
                      style: context.texts.displaySmall?.copyWith(
                        color: scheme.primary,
                        fontFeatures: const <FontFeature>[
                          FontFeature.tabularFigures(),
                        ],
                        letterSpacing: 8,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l10n.copyCode,
                  icon: Icon(copied ? Icons.check_rounded : Icons.copy_rounded),
                  onPressed: onCopy,
                ),
              ],
            ),
          SizedBox(height: spacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: code == null ? null : remaining.inSeconds / total,
              minHeight: 4,
            ),
          ),
          SizedBox(height: spacing.sm),
          Text(
            code == null
                ? l10n.quickConnectRequesting
                : l10n.quickConnectWaiting('$minutes:$seconds'),
            style: context.texts.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: spacing.md),
          Text(
            l10n.quickConnectSteps,
            textAlign: TextAlign.center,
            style: context.texts.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
