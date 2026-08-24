// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/tokens.dart';
import '../../core/update_check.dart';
import '../../l10n/app_localizations.dart';
import 'settings_widgets.dart';

/// Screen 1m, About.
///
/// The version is read from the running build rather than written here, so it
/// cannot drift from what was installed. The update chip only makes a claim
/// once it has actually asked: "Up to date" printed unconditionally is worth
/// less than nothing.
class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

enum _UpdateState { unknown, checking, current, available, failed }

class _AboutPageState extends State<AboutPage> {
  PackageInfo? _info;
  _UpdateState _update = _UpdateState.unknown;
  ReleaseInfo? _latest;

  @override
  void initState() {
    super.initState();
    // Local and instant. The update check deliberately does not run here:
    // nothing should touch the network because a settings page was opened.
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _info = info);
    });
  }

  String get _version => _info?.version ?? '-';
  String get _build => _info?.buildNumber ?? '-';

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final scheme = context.colors;

    return SettingsScaffold(
      title: AppLocalizations.of(context).settingsAbout,
      children: <Widget>[
        SizedBox(height: spacing.xl),
        Center(
          child: Column(
            children: <Widget>[
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(context.radii.action),
                ),
                child: Icon(
                  Icons.play_circle_rounded,
                  size: 44,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              SizedBox(height: spacing.md),
              Text('mPlayer', style: context.texts.titleLarge),
              SizedBox(height: spacing.xs),
              Text(
                'Version $_version · build $_build',
                style: context.texts.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              SizedBox(height: spacing.md),
              if (_update != _UpdateState.unknown) _updateChip(context),
            ],
          ),
        ),
        SizedBox(height: spacing.xl),
        _Row(
          icon: Icons.system_update_rounded,
          title: AppLocalizations.of(context).checkForUpdates,
          subtitle: AppLocalizations.of(context).checkForUpdatesSub,
          onTap: (_) => _checkForUpdates(),
        ),
        _Row(
          icon: Icons.description_rounded,
          title: AppLocalizations.of(context).releaseNotes,
          onTap: (c) => _open(c, releasesUrl),
        ),
        _Row(
          icon: Icons.bug_report_rounded,
          title: AppLocalizations.of(context).diagnostics,
          subtitle: AppLocalizations.of(context).diagnosticsSub,
          onTap: (c) => c.push('/settings/diagnostics'),
        ),
        _Row(
          icon: Icons.gavel_rounded,
          title: AppLocalizations.of(context).openSourceLicences,
          onTap: (c) => showLicensePage(
            context: c,
            applicationName: 'mPlayer',
            applicationVersion: 'Version $_version · build $_build',
            applicationLegalese:
                'Copyright (C) 2026 Nam\nGPL-3.0-or-later',
          ),
        ),
        _Row(
          icon: Icons.shield_rounded,
          title: AppLocalizations.of(context).privacy,
          subtitle: AppLocalizations.of(context).privacySub,
          onTap: (c) => c.push('/settings/privacy'),
        ),
        _Row(
          icon: Icons.code_rounded,
          title: AppLocalizations.of(context).sourceCode,
          subtitle: 'GPL-3.0-or-later',
          onTap: (c) => _open(c, repositoryUrl),
        ),
        _Row(
          icon: Icons.devices_rounded,
          title: AppLocalizations.of(context).thisDeviceInfo,
          onTap: (c) => c.push('/settings/diagnostics'),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            spacing.screenHorizontal(context.windowSize),
            spacing.xl,
            spacing.screenHorizontal(context.windowSize),
            spacing.lg,
          ),
          child: Text(
            'mPlayer is not affiliated with, endorsed by, or sponsored by the '
            'Jellyfin, Emby or Plex projects.',
            style: context.texts.bodySmall?.copyWith(color: scheme.outline),
          ),
        ),
      ],
    );
  }

  Widget _updateChip(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = context.colors;

    final (IconData icon, Color colour, String label) = switch (_update) {
      _UpdateState.checking => (
          Icons.hourglass_empty_rounded,
          scheme.onSurfaceVariant,
          l10n.checking,
        ),
      _UpdateState.current => (
          Icons.check_circle_rounded,
          context.semantic.success,
          l10n.upToDate,
        ),
      _UpdateState.available => (
          Icons.new_releases_rounded,
          scheme.primary,
          l10n.updateAvailable(_latest?.version ?? ''),
        ),
      _UpdateState.failed => (
          Icons.cloud_off_rounded,
          scheme.onSurfaceVariant,
          l10n.couldNotCheck,
        ),
      _UpdateState.unknown => (
          Icons.help_outline_rounded,
          scheme.onSurfaceVariant,
          '',
        ),
    };

    return ActionChip(
      avatar: Icon(icon, size: 18, color: colour),
      label: Text(label),
      backgroundColor: scheme.surfaceContainerHigh,
      side: BorderSide.none,
      // Only the "there is a newer one" chip does anything: it is the one
      // state where the user has somewhere to go.
      onPressed: _update == _UpdateState.available
          ? () => _open(context, _latest?.url ?? releasesUrl)
          : null,
    );
  }

  Future<void> _checkForUpdates() async {
    setState(() => _update = _UpdateState.checking);

    final latest = await latestRelease();
    if (!mounted) return;

    setState(() {
      _latest = latest;
      _update = switch (latest) {
        null => _UpdateState.failed,
        final r when isNewerVersion(r.version, _version) =>
          _UpdateState.available,
        _ => _UpdateState.current,
      };
    });
  }

  Future<void> _open(BuildContext context, String url) async {
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      opened = false;
    }

    if (opened || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).couldNotOpen(url))),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final void Function(BuildContext) onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: context.spacing.screenPadding(context.windowSize),
      leading: Icon(icon, color: context.colors.onSurfaceVariant),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: context.colors.outline,
      ),
      onTap: () => onTap(context),
    );
  }
}
