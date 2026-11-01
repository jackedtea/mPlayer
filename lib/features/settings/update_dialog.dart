// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/tokens.dart';
import '../../core/update_check.dart';
import '../../core/updater.dart';
import '../../l10n/app_localizations.dart';

/// Offers [found], and carries it through download and install if taken.
///
/// [automatic] adds "Skip this version", which only makes sense for a prompt
/// the user did not ask for.
Future<void> showUpdateDialog(
  BuildContext context,
  UpdateAvailable found, {
  bool automatic = false,
}) {
  return showDialog<void>(
    context: context,
    // A download in flight must not be dismissed by a stray tap outside.
    barrierDismissible: false,
    builder: (_) => _UpdateDialog(found: found, automatic: automatic),
  );
}

enum _Stage { offer, downloading, installing, done }

class _UpdateDialog extends ConsumerStatefulWidget {
  const _UpdateDialog({required this.found, required this.automatic});

  final UpdateAvailable found;
  final bool automatic;

  @override
  ConsumerState<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends ConsumerState<_UpdateDialog> {
  _Stage _stage = _Stage.offer;
  double? _progress;
  String? _message;
  bool _offerPermission = false;
  CancelToken? _cancel;

  ReleaseInfo get _release => widget.found.release;

  @override
  void dispose() {
    _cancel?.cancel();
    super.dispose();
  }

  Future<void> _update() async {
    final asset = widget.found.asset;
    final platform = ref.read(updatePlatformProvider);
    if (asset == null || platform == null) {
      await _openReleasePage();
      return;
    }

    final l10n = AppLocalizations.of(context);
    final installer = ref.read(updateInstallerProvider);
    final cancel = _cancel = CancelToken();

    setState(() {
      _stage = _Stage.downloading;
      _progress = null;
      _message = null;
      _offerPermission = false;
    });

    try {
      final file = await installer.download(
        asset,
        cancel: cancel,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      if (!mounted) return;
      setState(() => _stage = _Stage.installing);

      // On Windows and Linux a successful hand-over ends the process here.
      final outcome = await installer.apply(file, platform);
      if (!mounted) return;

      setState(() {
        _stage = _Stage.done;
        switch (outcome) {
          case InstallOutcome.started:
            _message = l10n.updateInstallerOpened;
          case InstallOutcome.needsPermission:
            _message = l10n.updateNeedsPermission;
            _offerPermission = true;
          case InstallOutcome.notWritable:
            _message = l10n.updateNotWritable;
          case InstallOutcome.failed:
            _message = l10n.updateFailed;
        }
      });
    } on DioException catch (e) {
      if (!mounted || CancelToken.isCancel(e)) return;
      setState(() {
        _stage = _Stage.done;
        _message = l10n.updateDownloadFailed;
      });
    }
  }

  Future<void> _openReleasePage() async {
    try {
      await launchUrl(
        Uri.parse(_release.url),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      // Nothing to open it with; the dialog stays, and so does the version.
    }
  }

  Future<void> _skip() async {
    await ref.read(updateSettingsProvider.notifier).skip(_release.tag);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final scheme = context.colors;
    final asset = widget.found.asset;
    final canInstall =
        asset != null && ref.watch(updatePlatformProvider) != null;

    final content = switch (_stage) {
      _Stage.offer => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              asset == null || asset.size == 0
                  ? l10n.updateOfferBody
                  : l10n.updateOfferBodySized(_megabytes(asset.size)),
              style: context.texts.bodyMedium,
            ),
            if (_release.notes.trim().isNotEmpty) ...<Widget>[
              SizedBox(height: spacing.md),
              Text(l10n.releaseNotes, style: context.texts.titleSmall),
              SizedBox(height: spacing.xs),
              // Its own scroll, capped, so long notes do not push the
              // buttons off a landscape phone.
              Container(
                constraints: const BoxConstraints(maxHeight: 220),
                padding: EdgeInsets.all(spacing.md),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: context.radii.cardAll,
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _plainNotes(_release.notes),
                    style: context.texts.bodySmall,
                  ),
                ),
              ),
            ],
          ],
        ),
      _Stage.downloading || _Stage.installing => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              _stage == _Stage.downloading
                  ? l10n.updateDownloading
                  : l10n.updateInstalling,
            ),
            SizedBox(height: spacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: _stage == _Stage.downloading ? _progress : null,
                minHeight: 6,
              ),
            ),
            if (_stage == _Stage.downloading && _progress != null) ...<Widget>[
              SizedBox(height: spacing.sm),
              Text(
                '${(_progress! * 100).round()}%',
                textAlign: TextAlign.end,
                style: context.texts.labelMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      _Stage.done => Text(_message ?? ''),
    };

    final actions = switch (_stage) {
      _Stage.offer => <Widget>[
          if (widget.automatic)
            TextButton(onPressed: _skip, child: Text(l10n.updateSkip)),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.updateLater),
          ),
          FilledButton(
            onPressed: _update,
            child: Text(canInstall ? l10n.updateNow : l10n.updateOpenPage),
          ),
        ],
      _Stage.downloading => <Widget>[
          TextButton(
            onPressed: () {
              _cancel?.cancel();
              Navigator.of(context).pop();
            },
            child: Text(l10n.cancel),
          ),
        ],
      _Stage.installing => const <Widget>[],
      _Stage.done => <Widget>[
          if (_offerPermission)
            TextButton(onPressed: _update, child: Text(l10n.updateTryAgain))
          else
            TextButton(
              onPressed: _openReleasePage,
              child: Text(l10n.updateOpenPage),
            ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.close),
          ),
        ],
    };

    return AlertDialog(
      icon: const Icon(Icons.system_update_rounded),
      title: Text(l10n.updateAvailable(_release.version)),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: content,
      ),
      actions: actions,
    );
  }
}

String _megabytes(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(1);

/// Release notes without the Markdown furniture a dialog cannot render.
///
/// CI writes a table of files under the notes; that is for the web page, and
/// drawn as text it is a wall of pipes, so it is cut off.
String _plainNotes(String markdown) {
  final lines = <String>[];
  for (final String raw in markdown.split('\n')) {
    final line = raw.trimRight();
    if (line.startsWith('|')) break;
    lines.add(
      line
          .replaceFirst(RegExp(r'^#+\s*'), '')
          .replaceAll(RegExp(r'\*\*|__|`'), '')
          .replaceFirst(RegExp(r'^\s*[-*]\s+'), '• '),
    );
  }
  return lines.join('\n').trim();
}
