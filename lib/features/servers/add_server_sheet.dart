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
    } else {
      await registry.updateProfile(editing.id, info: server, auth: result);
    }

    if (mounted) Navigator.of(context).pop();
  }

  // ------------------------------------------------------------------ UI

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final scheme = context.colors;

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
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.editing == null
                      ? AppLocalizations.of(context).addServer
                      : AppLocalizations.of(context).editServer,
                  style: context.texts.headlineSmall,
                ),
              ),
              SizedBox(height: spacing.xl - spacing.xs),
              TextField(
                controller: _address,
                autofocus: widget.editing == null,
                keyboardType: TextInputType.url,
                autocorrect: false,
                enabled: _stage != _Stage.waitingForApproval,
                decoration: InputDecoration(
                  filled: true,
                  labelText: AppLocalizations.of(context).serverAddress,
                  // Not translated: an address is an address, and the design
                  // uses this exact one as its example.
                  hintText: 'http://192.168.1.20:8096',
                  border: const UnderlineInputBorder(),
                ),
                onChanged: (_) => _onAddressChanged(),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  spacing.lg,
                  spacing.xs,
                  spacing.lg,
                  0,
                ),
                child: _DetectionLine(server: _server, error: _error),
              ),

              if (_signedInAlready)
                // No password field, because none is needed: the credential
                // already stored was just checked against this address and
                // accepted. Asking again would be asking the user to re-prove
                // something the app can verify for itself.
                Padding(
                  padding: EdgeInsets.only(top: spacing.lg),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.verified_user_rounded,
                      color: context.semantic.success,
                    ),
                    title: Text(
                      AppLocalizations.of(context)
                          .signedInAs(_existingSession!.username),
                    ),
                    subtitle: Text(AppLocalizations.of(context).signInAgain),
                    trailing: TextButton(
                      // A way out for the case this cannot detect: the account
                      // itself is being changed, not just the address.
                      onPressed: () => setState(() {
                        _existingSession = null;
                        _password.clear();
                        _stage = _Stage.found;
                      }),
                      child: Text(AppLocalizations.of(context).change),
                    ),
                  ),
                )
              else if (_stage == _Stage.waitingForApproval)
                _QuickConnectPanel(request: _quickConnectRequest)
              else ...<Widget>[
                SizedBox(height: spacing.xl - spacing.xs),
                if (!_quickConnect) ...<Widget>[
                  TextField(
                    controller: _username,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context).username,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  SizedBox(height: spacing.lg),
                  TextField(
                    controller: _password,
                    obscureText: _obscurePassword,
                    onSubmitted: (_) => _canSignIn ? _signIn() : null,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context).password,
                      suffixIcon: IconButton(
                        tooltip: _obscurePassword
                            ? AppLocalizations.of(context).showPassword
                            : AppLocalizations.of(context).hidePassword,
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
                // Only offered where the server actually has it: Emby answers
                // 404 to every Quick Connect route, and a Jellyfin admin can
                // switch it off.
                if (_quickConnectAvailable)
                  SwitchListTile(
                    value: _quickConnect,
                    onChanged: (v) => setState(() => _quickConnect = v),
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      AppLocalizations.of(context).quickConnectInstead,
                    ),
                    subtitle: Text(
                      AppLocalizations.of(context).quickConnectHint,
                    ),
                  ),
              ],

              SizedBox(height: spacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(AppLocalizations.of(context).cancel),
                  ),
                  SizedBox(width: spacing.sm),
                  if (_stage == _Stage.signingIn ||
                      _stage == _Stage.waitingForApproval)
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: spacing.lg),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: scheme.primary,
                        ),
                      ),
                    )
                  else
                    FilledButton(
                      onPressed: _signedInAlready
                          ? _saveWithStoredSession
                          : (_quickConnect
                              ? (_server == null ? null : _startQuickConnect)
                              : (_canSignIn ? _signIn : null)),
                      child: Text(
                        _signedInAlready
                            ? AppLocalizations.of(context).save
                            : (_quickConnect
                                  ? AppLocalizations.of(context).getACode
                                  : AppLocalizations.of(context).connect),
                      ),
                    ),
                ],
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

/// The line under the address field: what was found, or what went wrong.
class _DetectionLine extends StatelessWidget {
  const _DetectionLine({required this.server, required this.error});

  final ServerInfo? server;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final semantic = context.semantic;

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
    //
    // The line keeps its idle prompt rather than collapsing, so the fields
    // below do not jump each time.

    final found = server;
    if (found != null) {
      return Row(
        children: <Widget>[
          Icon(Icons.check_circle_rounded, size: 14, color: semantic.success),
          SizedBox(width: context.spacing.sm),
          Expanded(
            child: Text(
              '${found.kind.label} ${found.version} · ${found.name}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.texts.bodySmall?.copyWith(color: semantic.success),
            ),
          ),
        ],
      );
    }

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

    return Padding(
      padding: EdgeInsets.only(top: spacing.xl),
      child: Column(
        children: <Widget>[
          Text(
            AppLocalizations.of(context).enterCodeInJellyfin,
            style: context.texts.bodyMedium,
          ),
          SizedBox(height: spacing.md),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: spacing.xl,
              vertical: spacing.md,
            ),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: context.radii.cardAll,
            ),
            child: Text(
              request?.code ?? '…',
              style: context.texts.headlineMedium?.copyWith(
                fontFeatures: const <FontFeature>[
                  FontFeature.tabularFigures(),
                ],
                letterSpacing: 6,
              ),
            ),
          ),
          SizedBox(height: spacing.md),
          Text(
            'Settings → Quick Connect on any device already signed in. '
            'No password is typed here.',
            textAlign: TextAlign.center,
            style: context.texts.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
