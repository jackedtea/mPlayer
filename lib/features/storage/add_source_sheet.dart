// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/tokens.dart';
import '../../core/models/media_models.dart';
import '../../sources/media_source.dart';
import '../../sources/source_config.dart';
import '../../sources/source_registry.dart';
import '../../sources/webdav_source.dart';

/// Adds an SMB, WebDAV or NFS share.
///
/// Connection is tested before saving, so a typo surfaces here rather than as
/// an empty folder later.
class AddSourceSheet extends ConsumerStatefulWidget {
  const AddSourceSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const AddSourceSheet(),
    );
  }

  @override
  ConsumerState<AddSourceSheet> createState() => _AddSourceSheetState();
}

class _AddSourceSheetState extends ConsumerState<AddSourceSheet> {
  static const _kinds = <SourceKind>[
    SourceKind.webdav,
    SourceKind.smb,
    SourceKind.nfs,
  ];

  final _name = TextEditingController();
  final _uri = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();

  SourceKind _kind = SourceKind.webdav;
  bool _obscure = true;
  bool _testing = false;
  String? _status;
  bool _statusIsError = false;

  @override
  void dispose() {
    _name.dispose();
    _uri.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Only WebDAV has a driver; the others save but cannot be browsed yet.
  bool get _supported => _kind == SourceKind.webdav;

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
                child: Text('Add a share', style: context.texts.headlineSmall),
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
                decoration: const InputDecoration(
                  labelText: 'Name',
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
                  labelText: 'Address',
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
                decoration: const InputDecoration(
                  labelText: 'Username',
                  helperText: 'Leave empty for an anonymous share',
                ),
              ),
              SizedBox(height: spacing.lg),
              TextField(
                controller: _password,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: 'Password',
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
                    child: const Text('Cancel'),
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
                          : const Text('Test'),
                    ),
                  SizedBox(width: spacing.sm),
                  FilledButton(
                    onPressed: _canSubmit ? _save : null,
                    child: const Text('Save'),
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
      // Timestamp-based so editing an existing share keeps its credentials
      // while a new one never collides.
      id: '${_kind.name}_${DateTime.now().millisecondsSinceEpoch}',
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
    final source = WebDavSource(
      config: config,
      password: _password.text.isEmpty ? null : _password.text,
    );

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
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _save() async {
    final config = _buildConfig();
    await ref.read(sourceRegistryProvider.notifier).add(
          config,
          _password.text.isEmpty ? null : _password.text,
        );

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
