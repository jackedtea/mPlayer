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
import '../../servers/server_registry.dart';

/// Screen 1c, second frame — the modal "Add a server" bottom sheet.
///
/// The address is probed as it is typed, before any password is asked for:
/// telling someone their address is wrong is far better than leaving them to
/// wonder whether their password is.
class AddServerSheet extends ConsumerStatefulWidget {
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
  ConsumerState<AddServerSheet> createState() => _AddServerSheetState();
}

/// What the sheet is doing, which decides everything it shows.
enum _Stage { typing, probing, found, signingIn, waitingForApproval }

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

  /// Bumped whenever the address changes, so a probe that finishes after the
  /// user has typed on cannot overwrite a newer answer.
  int _probeGeneration = 0;

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
    await ref
        .read(serverRegistryProvider.notifier)
        .add(info: server, auth: result);

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
                  'Add a server',
                  style: context.texts.headlineSmall,
                ),
              ),
              SizedBox(height: spacing.xl - spacing.xs),
              TextField(
                controller: _address,
                autofocus: true,
                keyboardType: TextInputType.url,
                autocorrect: false,
                enabled: _stage != _Stage.waitingForApproval,
                decoration: const InputDecoration(
                  filled: true,
                  labelText: 'Server address',
                  hintText: 'http://192.168.1.20:8096',
                  border: UnderlineInputBorder(),
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
                child: _DetectionLine(
                  stage: _stage,
                  server: _server,
                  error: _error,
                ),
              ),

              if (_stage == _Stage.waitingForApproval)
                _QuickConnectPanel(request: _quickConnectRequest)
              else ...<Widget>[
                SizedBox(height: spacing.xl - spacing.xs),
                if (!_quickConnect) ...<Widget>[
                  TextField(
                    controller: _username,
                    autocorrect: false,
                    decoration: const InputDecoration(labelText: 'Username'),
                    onChanged: (_) => setState(() {}),
                  ),
                  SizedBox(height: spacing.lg),
                  TextField(
                    controller: _password,
                    obscureText: _obscurePassword,
                    onSubmitted: (_) => _canSignIn ? _signIn() : null,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      suffixIcon: IconButton(
                        tooltip: _obscurePassword
                            ? 'Show password'
                            : 'Hide password',
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
                    title: const Text('Quick connect instead'),
                    subtitle:
                        const Text('Approve from another signed-in device'),
                  ),
              ],

              SizedBox(height: spacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
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
                      onPressed: _quickConnect
                          ? (_server == null ? null : _startQuickConnect)
                          : (_canSignIn ? _signIn : null),
                      child: Text(_quickConnect ? 'Get a code' : 'Connect'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _canSignIn =>
      _server != null &&
      _username.text.trim().isNotEmpty &&
      _stage == _Stage.found;
}

/// The line under the address field: what was found, or what went wrong.
class _DetectionLine extends StatelessWidget {
  const _DetectionLine({
    required this.stage,
    required this.server,
    required this.error,
  });

  final _Stage stage;
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

    if (stage == _Stage.probing) {
      return Row(
        children: <Widget>[
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: scheme.onSurfaceVariant,
            ),
          ),
          SizedBox(width: context.spacing.sm),
          Text(
            'Looking for a server…',
            style: context.texts.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      );
    }

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
      'Enter an address to detect the server',
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
            'Enter this code in Jellyfin',
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
