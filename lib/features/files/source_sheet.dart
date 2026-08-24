// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../core/models/media_models.dart';
import '../../sources/media_source.dart';
import '../../sources/source_config.dart';
import '../../sources/source_registry.dart';
import '../../sources/media_proxy_server.dart';
import '../../sources/smb_source.dart';
import '../../sources/webdav_source.dart';

/// Adds or edits an SMB, WebDAV or NFS share.
///
/// Connection is tested before saving, so a typo surfaces here rather than as
/// an empty folder later. Editing reuses the same form: a share is usually
/// wrong in one field, and retyping the other four to fix it is busywork.
class SourceSheet extends ConsumerStatefulWidget {
  const SourceSheet({super.key, this.existing});

  /// The share being edited, or null when adding a new one.
  final SourceConfig? existing;

  static Future<void> showAdd(BuildContext context) => _show(context, null);

  static Future<void> showEdit(BuildContext context, SourceConfig config) =>
      _show(context, config);

  static Future<void> _show(BuildContext context, SourceConfig? existing) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => SourceSheet(existing: existing),
    );
  }

  @override
  ConsumerState<SourceSheet> createState() => _SourceSheetState();
}

class _SourceSheetState extends ConsumerState<SourceSheet> {
  static const _kinds = <SourceKind>[
    SourceKind.webdav,
    SourceKind.smb,
    SourceKind.nfs,
  ];

  final _name = TextEditingController();
  final _uri = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();

  late SourceKind _kind;
  bool _obscure = true;
  bool _testing = false;
  String? _status;
  bool _statusIsError = false;

  /// Set once the user types in the password field. Until then the field only
  /// mirrors what is in the keychain, and saving leaves that credential alone —
  /// an unreadable keychain must not erase a working password.
  bool _passwordTouched = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();

    final existing = widget.existing;
    _kind = existing?.kind ?? SourceKind.webdav;
    if (existing != null) {
      _name.text = existing.name;
      _uri.text = existing.uri;
      _username.text = existing.username;
      _loadPassword(existing);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _uri.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _loadPassword(SourceConfig config) async {
    final stored =
        await ref.read(sourceRegistryProvider.notifier).passwordFor(config);
    // The read is slow enough that the user may already be typing; their input
    // wins.
    if (!mounted || stored == null || _passwordTouched) return;
    _password.text = stored;
  }

  /// NFS still has no driver; it saves but cannot be browsed yet.
  bool get _supported =>
      _kind == SourceKind.webdav || _kind == SourceKind.smb;

  bool get _canSubmit =>
      _uri.text.trim().isNotEmpty && _name.text.trim().isNotEmpty && !_testing;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    return Padding(
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
                  _isEditing ? 'Edit share' : 'Add a share',
                  style: context.texts.headlineSmall,
                ),
              ),
              SizedBox(height: spacing.lg),
              SegmentedButton<SourceKind>(
                segments: <ButtonSegment<SourceKind>>[
                  for (final SourceKind k in _kinds)
                    ButtonSegment<SourceKind>(
                      value: k,
                      label: Text(k.label),
                      icon: Icon(k.icon),
                    ),
                ],
                selected: <SourceKind>{_kind},
                onSelectionChanged: (s) => setState(() {
                  _kind = s.first;
                  _status = null;
                }),
              ),
              if (!_supported) ...<Widget>[
                SizedBox(height: spacing.md),
                _Notice(
                  text: '${_kind.label} has no driver yet. The share will be '
                      'saved and listed, but cannot be browsed until it lands.',
                ),
              ],
              SizedBox(height: spacing.lg),
              TextField(
                controller: _name,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).fieldName,
                  // A placeholder, not a label: it is an example of a name,
                  // and reads the same in every language.
                  hintText: 'NAS',
                ),
                onChanged: (_) => setState(() {}),
              ),
              SizedBox(height: spacing.lg),
              TextField(
                controller: _uri,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).fieldAddress,
                  hintText: _kind == SourceKind.webdav
                      ? 'https://dav.example.com/remote.php/dav/files/me'
                      : '${_kind.name}://192.168.1.10/media',
                ),
                onChanged: (_) => setState(() => _status = null),
              ),
              SizedBox(height: spacing.lg),
              TextField(
                controller: _username,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).fieldUsername,
                  helperText: AppLocalizations.of(context).anonymousHint,
                ),
              ),
              SizedBox(height: spacing.lg),
              TextField(
                controller: _password,
                obscureText: _obscure,
                onChanged: (_) => _passwordTouched = true,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).fieldPassword,
                  suffixIcon: IconButton(
                    tooltip: _obscure ? 'Show password' : 'Hide password',
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              if (_status != null) ...<Widget>[
                SizedBox(height: spacing.md),
                Text(
                  _status!,
                  style: context.texts.bodySmall?.copyWith(
                    color: _statusIsError
                        ? context.colors.error
                        : context.semantic.success,
                  ),
                ),
              ],
              SizedBox(height: spacing.xl),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(AppLocalizations.of(context).actionCancel),
                  ),
                  SizedBox(width: spacing.sm),
                  if (_supported)
                    OutlinedButton(
                      onPressed: _canSubmit ? _test : null,
                      child: _testing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(AppLocalizations.of(context).actionTest),
                    ),
                  SizedBox(width: spacing.sm),
                  FilledButton(
                    onPressed: _canSubmit ? _save : null,
                    child: Text(AppLocalizations.of(context).actionSave),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  SourceConfig _buildConfig() {
    return SourceConfig(
      // The id is what credentials are stored under, so an edit keeps the one
      // the share already has; a new share gets a timestamp, which never
      // collides.
      id: widget.existing?.id ??
          '${_kind.name}_${DateTime.now().millisecondsSinceEpoch}',
      kind: _kind,
      name: _name.text.trim(),
      uri: _uri.text.trim(),
      username: _username.text.trim(),
    );
  }

  Future<void> _test() async {
    setState(() {
      _testing = true;
      _status = null;
    });

    final config = _buildConfig();
    final password = _password.text.isEmpty ? null : _password.text;

    // Built directly rather than through the registry: the share is not saved
    // yet, and testing must not register a half-configured source.
    final BrowsableSource source = switch (config.kind) {
      SourceKind.smb => SmbSource(
          config: config,
          password: password,
          proxy: ref.read(mediaProxyServerProvider),
        ),
      _ => WebDavSource(config: config, password: password),
    };

    try {
      final listing = await source.listDirectory('');
      if (!mounted) return;
      setState(() {
        _statusIsError = false;
        _status = 'Connected — ${listing.folderCount} folders, '
            '${listing.fileCount} files';
      });
    } on MediaSourceException catch (e) {
      if (!mounted) return;
      setState(() {
        _statusIsError = true;
        _status = e.message;
      });
    } finally {
      // A test connection must not outlive the test; SMB opens a worker pool.
      if (source is SmbSource) await source.dispose();
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _save() async {
    final config = _buildConfig();
    final registry = ref.read(sourceRegistryProvider.notifier);

    if (_isEditing) {
      await registry.update(
        config,
        // Untouched means "whatever is already in the keychain".
        _passwordTouched ? _password.text : null,
      );
    } else {
      await registry.add(
        config,
        _password.text.isEmpty ? null : _password.text,
      );
    }

    if (!mounted) return;
    Navigator.of(context).pop();
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final scheme = context.colors;

    return Container(
      padding: EdgeInsets.all(spacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: context.radii.cardAll,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.info_rounded, size: 20, color: scheme.primary),
          SizedBox(width: spacing.md),
          Expanded(
            child: Text(
              text,
              style: context.texts.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
