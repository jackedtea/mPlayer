// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../servers/server_admin.dart';
import 'admin_providers.dart';
import 'admin_widgets.dart';

/// Installed plugins — enable, disable, uninstall.
///
/// Deliberately not a catalogue: installing from a repository means browsing
/// remote packages, checking versions against the server's ABI and reading
/// release notes, which is a job for the machine it runs on rather than a
/// phone. What is useful here is turning off the plugin that has started
/// misbehaving, which is exactly what this does.
class AdminPluginsPage extends ConsumerWidget {
  const AdminPluginsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final plugins = ref.watch(serverPluginsProvider);

    return AdminScaffold(
      title: l10n.adminPlugins,
      onRefresh: () async {
        ref.invalidate(serverPluginsProvider);
        await ref.read(serverPluginsProvider.future);
      },
      child: AdminList(
        loading: plugins.isLoading,
        emptyText: l10n.adminNoPlugins,
        children: <Widget>[
          for (final ServerPlugin plugin
              in plugins.value ?? const <ServerPlugin>[])
            _PluginRow(plugin: plugin),
        ],
      ),
    );
  }
}

class _PluginRow extends ConsumerWidget {
  const _PluginRow({required this.plugin});

  final ServerPlugin plugin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = context.colors;

    final status = _statusLabel(l10n);

    return ListTile(
      title: Text(plugin.name),
      subtitle: Text(
        <String>[plugin.version, status].where((s) => s.isNotEmpty).join(' · '),
        style: TextStyle(
          color: switch (plugin.status) {
            PluginStatus.malfunctioned ||
            PluginStatus.notSupported =>
              scheme.error,
            PluginStatus.restartPending => context.semantic.warning,
            _ => scheme.onSurfaceVariant,
          },
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Switch(
            value: plugin.isEnabled,
            onChanged: (enabled) => runAdminAction(
              context,
              ref,
              action: (admin) => admin.setPluginEnabled(
                plugin.id,
                plugin.version,
                enabled: enabled,
              ),
              success: l10n.adminPluginChanged(plugin.name),
              refresh: () => ref.invalidate(serverPluginsProvider),
            ),
          ),
          // A plugin the server ships with cannot be removed, so the button
          // is absent rather than present and refused.
          if (plugin.canUninstall)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: l10n.adminPluginUninstall,
              onPressed: () => _uninstall(context, ref, l10n),
            ),
        ],
      ),
    );
  }

  String _statusLabel(AppLocalizations l10n) {
    return switch (plugin.status) {
      PluginStatus.active => '',
      PluginStatus.disabled => l10n.adminUserDisabled,
      PluginStatus.restartPending => l10n.adminPluginRestartPending,
      PluginStatus.malfunctioned => l10n.adminPluginBroken,
      PluginStatus.notSupported => l10n.adminPluginUnsupported,
      PluginStatus.superceded => l10n.adminPluginSuperceded,
    };
  }

  Future<void> _uninstall(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final go = await confirmAdminAction(
      context,
      title: l10n.adminUninstallPluginQuestion(plugin.name),
      body: l10n.adminUninstallPluginBody,
      confirmLabel: l10n.adminPluginUninstall,
    );
    if (!go || !context.mounted) return;

    await runAdminAction(
      context,
      ref,
      action: (admin) => admin.uninstallPlugin(plugin.id, plugin.version),
      success: l10n.adminPluginRemoved(plugin.name),
      refresh: () => ref.invalidate(serverPluginsProvider),
    );
  }
}
