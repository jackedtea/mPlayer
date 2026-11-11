// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../servers/server_admin.dart';
import 'admin_providers.dart';
import 'admin_widgets.dart';

/// Every device signed in to the server, whoever's — the web dashboard's
/// Devices page. One account's devices are also on that account's own tab.
class AdminDevicesPage extends ConsumerWidget {
  const AdminDevicesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final devices = ref.watch(adminDevicesProvider);

    return AdminScaffold(
      title: l10n.adminDevices,
      onRefresh: () async {
        ref.invalidate(adminDevicesProvider);
        await ref.read(adminDevicesProvider.future);
      },
      child: switch (devices) {
        AsyncError(:final error) => AdminList(
          emptyText: '$error',
          children: const <Widget>[],
        ),
        _ => AdminList(
          loading: devices.isLoading,
          emptyText: l10n.adminNoDevices,
          children: <Widget>[
            for (final AdminDevice device
                in devices.value ?? const <AdminDevice>[])
              ListTile(
                leading: const Icon(Icons.devices_rounded),
                title: Text(
                  device.name.isEmpty ? device.appName : device.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  <String>[
                    <String>[
                      device.appName,
                      device.appVersion,
                    ].where((s) => s.isNotEmpty).join(' '),
                    device.username,
                    relativeTime(device.lastSeen, l10n),
                  ].where((s) => s.isNotEmpty).join(' · '),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline_rounded),
                  tooltip: l10n.adminForgetDevice,
                  onPressed: () => runAdminAction(
                    context,
                    ref,
                    action: (admin) => admin.deleteDevice(device.id),
                    success: l10n.adminDeviceForgotten,
                    refresh: () => ref.invalidate(adminDevicesProvider),
                  ),
                ),
              ),
          ],
        ),
      },
    );
  }
}
