// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:async';

import 'package:flutter/material.dart';
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
  final _username = TextEditingController();
  final _password = TextEditingController();

  _Stage _stage = _Stage.typing;
  ServerInfo? _server;
  bool _quickConnectAvailable = false;
  bool _quickConnect = false;
  QuickConnectRequest? _quickConnectRequest;
  String? _error;
  bool _obscurePassword = true;

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
    _username.text = editing.username;
    WidgetsBinding.instance.addPostFrameCallback((_) => _onAddressChanged());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    unawaited(_auth?.dispose());
    _address.dispose();
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
        _stage = _Stage.found;
        _error = null;
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
      _error = null;
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
        _error = e.message;
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

    final token =
        await ref.read(serverRegistryProvider.notifier).tokenFor(editing.id);
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

  Future<void> _startQuickConnect() async {
    final server = _server;
    if (server == null) return;

    setState(() {
      _error = null;
      _stage = _Stage.waitingForApproval;
    });

    try {
      final auth = await _authService();
      final request = await auth.initiateQuickConnect(server);

      if (!mounted) return;
      setState(() => _quickConnectRequest = request);

      final result = await auth.awaitQuickConnect(server, request);
      if (!mounted) return;

      if (result == null) {
        // Nobody approved it. Not a failure worth an error colour — the code
        // simply timed out.
        setState(() {
          _quickConnectRequest = null;
          _stage = _Stage.found;
        });
        return;
      }

      await _finish(server, result);
    } on ServerException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _quickConnectRequest = null;
        _stage = _Stage.found;
      });
    }
  }

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
      await registry.updateProfile(editing.id, info: server, auth: result);
    }

    if (mounted) Navigator.of(context).pop();
  }

  // ------------------------------------------------------------------ UI

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final l10n = AppLocalizations.of(context);
    final busy =
        _stage == _Stage.signingIn || _stage == _Stage.waitingForApproval;

    return Padding(
      // Lift the sheet above the keyboard rather than letting it overlap.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
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
                    ? _ServerCard(key: const ValueKey('found'), server: _server!)
                    : Padding(
                        key: const ValueKey('line'),
                        padding: EdgeInsets.symmetric(horizontal: spacing.lg),
                        child: _DetectionLine(error: _error),
                      ),
              ),
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
              else if (_stage == _Stage.waitingForApproval)
                _QuickConnectPanel(request: _quickConnectRequest)
              else ...<Widget>[
                // Only offered where the server actually has it: a Jellyfin
                // administrator can switch it off. Before a server is found
                // there is nothing to choose between.
                if (_quickConnectAvailable) ...<Widget>[
                  SegmentedButton<bool>(
                    segments: <ButtonSegment<bool>>[
                      ButtonSegment<bool>(
                        value: false,
                        icon: const Icon(Icons.password_rounded),
                        label: Text(l10n.password),
                      ),
                      ButtonSegment<bool>(
                        value: true,
                        icon: const Icon(Icons.qr_code_rounded),
                        label: Text(l10n.quickConnectShort),
                      ),
                    ],
                    selected: <bool>{_quickConnect},
                    onSelectionChanged: (v) =>
                        setState(() => _quickConnect = v.single),
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

              SizedBox(height: spacing.xl),
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
                              : (_quickConnect ? l10n.getACode : l10n.connect),
                        ),
                ),
              ),
              SizedBox(height: spacing.xs),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
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
    border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
    enabledBorder:
        OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
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
                style: context.texts.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
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
                  style: context.texts.titleSmall
                      ?.copyWith(color: scheme.onSecondaryContainer),
                ),
                Text(
                  <String>[
                    'Jellyfin ${server.version}'.trim(),
                    host,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.texts.bodySmall
                      ?.copyWith(color: scheme.onSecondaryContainer),
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

/// The code to read out, while this device waits for it to be approved.
class _QuickConnectPanel extends StatelessWidget {
  const _QuickConnectPanel({required this.request});

  final QuickConnectRequest? request;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final scheme = context.colors;
    final l10n = AppLocalizations.of(context);

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
          Text(
            request?.code ?? '…',
            style: context.texts.displaySmall?.copyWith(
              color: scheme.primary,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              letterSpacing: 8,
            ),
          ),
          SizedBox(height: spacing.md),
          Text(
            l10n.quickConnectSteps,
            textAlign: TextAlign.center,
            style: context.texts.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
