// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../app/tokens.dart';
import '../player/playback_controller.dart';
import '../player/playback_state.dart';
import '../../l10n/app_localizations.dart';
import 'settings_widgets.dart';

/// Screen 1m, Diagnostics.
///
/// What someone needs when they report a bug, in one place and copyable in
/// one press: the build, the machine, and what libmpv last said. The log is
/// the valuable half — image-based subtitles failing, a codec missing, a
/// share timing out, all of it shows up there and nowhere else.
class DiagnosticsPage extends ConsumerWidget {
  const DiagnosticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final state = ref.watch(playbackControllerProvider);

    return SettingsScaffold(
      title: l10n.diagnostics,
      children: <Widget>[
        SettingsSection(title: l10n.build),
        FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (context, snapshot) {
            final info = snapshot.data;
            return Column(
              children: <Widget>[
                SettingsValueRow(
                  title: l10n.version,
                  value: info == null
                      ? '—'
                      : '${info.version} · build ${info.buildNumber}',
                ),
                SettingsValueRow(
                  title: l10n.applicationId,
                  value: info?.packageName ?? '—',
                ),
              ],
            );
          },
        ),
        SettingsSection(title: l10n.thisDevice),
        SettingsValueRow(title: l10n.platform, value: _platform()),
        SettingsValueRow(
          title: l10n.operatingSystem,
          value: Platform.operatingSystemVersion,
        ),
        SettingsValueRow(
          title: l10n.locale,
          value: Platform.localeName,
        ),
        SettingsValueRow(
          title: l10n.screen,
          value: _screen(context),
        ),

        SettingsSection(title: l10n.playerLog),
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: spacing.screenHorizontal(context.windowSize),
          ),
          child: _Log(lines: state.logLines),
        ),

        Padding(
          padding: EdgeInsets.fromLTRB(
            spacing.screenHorizontal(context.windowSize),
            spacing.lg,
            spacing.screenHorizontal(context.windowSize),
            spacing.xl,
          ),
          child: FilledButton.tonalIcon(
            icon: const Icon(Icons.copy_rounded),
            label: Text(l10n.copyEverything),
            onPressed: () => _copy(context, state),
          ),
        ),
      ],
    );
  }

  static String _platform() {
    final name = switch (Platform.operatingSystem) {
      'android' => 'Android',
      'windows' => 'Windows',
      'linux' => 'Linux',
      'macos' => 'macOS',
      'ios' => 'iOS',
      final other => other,
    };
    return '$name · ${Platform.numberOfProcessors} cores';
  }

  static String _screen(BuildContext context) {
    final view = MediaQuery.of(context);
    final size = view.size;
    return '${size.width.round()}×${size.height.round()} '
        '@ ${view.devicePixelRatio}x';
  }

  Future<void> _copy(BuildContext context, PlaybackState state) async {
    final info = await PackageInfo.fromPlatform();
    final report = StringBuffer()
      ..writeln('mPlayer ${info.version} (build ${info.buildNumber})')
      ..writeln('${_platform()} · ${Platform.operatingSystemVersion}')
      ..writeln('Locale: ${Platform.localeName}')
      ..writeln();

    final media = state.media;
    if (media != null) {
      // The URI is deliberately left out: it can carry a share's host, a user
      // name or a token, and a bug report is usually pasted somewhere public.
      report
        ..writeln('Playing: ${media.kind.name} · ${media.sourceLine}')
        ..writeln('Video: ${state.stats.width}×${state.stats.height} '
            '${state.stats.videoCodec ?? '—'} '
            '(${state.stats.videoDecoder ?? '—'})')
        ..writeln('Audio: ${state.stats.audioCodec ?? '—'} '
            '${state.stats.audioChannels ?? ''}')
        ..writeln();
    }

    report
      ..writeln('Player log:')
      ..writeAll(state.logLines, '\n');

    await Clipboard.setData(ClipboardData(text: report.toString()));
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).diagnosticsCopied)),
    );
  }
}

/// The last lines libmpv reported, oldest first.
class _Log extends StatelessWidget {
  const _Log({required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    if (lines.isEmpty) {
      return Text(
        AppLocalizations.of(context).logEmpty,
        style: context.texts.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 320),
      padding: EdgeInsets.all(context.spacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: context.radii.cardAll,
      ),
      child: SingleChildScrollView(
        child: SelectableText(
          lines.join('\n'),
          style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
        ),
      ),
    );
  }
}
