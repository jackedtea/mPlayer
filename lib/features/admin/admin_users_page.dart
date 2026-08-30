// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../servers/server_admin.dart';
import '../../widgets/section_header.dart';
import 'admin_providers.dart';
import 'admin_widgets.dart';

/// Accounts and the devices they have signed in from.
///
/// One screen rather than two, because the two questions are asked together:
/// an administrator wondering about an account is usually wondering what it
/// has been signing in from.
class AdminUsersPage extends ConsumerWidget {
  const AdminUsersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;

    final users = ref.watch(adminUsersProvider);
    final devices = ref.watch(adminDevicesProvider);

    return AdminScaffold(
      title: l10n.adminUsers,
      onRefresh: () async {
        ref
          ..invalidate(adminUsersProvider)
          ..invalidate(adminDevicesProvider);
        await ref.read(adminUsersProvider.future);
      },
      child: AdminList(
        loading: users.isLoading && devices.isLoading,
        children: <Widget>[
          SectionHeader(title: l10n.adminUsers),
          if (users.value?.isEmpty ?? true)
            Padding(
              padding: EdgeInsets.symmetric(vertical: spacing.md),
              child: AdminNote(text: l10n.adminNoUsers),
            )
          else
            for (final AdminUser user in users.value!) _UserRow(user: user),

          SizedBox(height: spacing.sectionGap),
          SectionHeader(title: l10n.adminDevices),
          if (devices.value?.isEmpty ?? true)
            Padding(
              padding: EdgeInsets.symmetric(vertical: spacing.md),
              child: AdminNote(text: l10n.adminNoDevices),
            )
          else
            for (final AdminDevice device in devices.value!)
              _DeviceRow(device: device),
        ],
      ),
    );
  }
}

class _UserRow extends ConsumerWidget {
  const _UserRow({required this.user});

  final AdminUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = context.colors;

    final tags = <String>[
      if (user.isAdministrator) l10n.adminUserAdmin,
      if (user.isDisabled) l10n.adminUserDisabled,
      if (user.lastActivity != null) relativeTime(user.lastActivity, l10n),
    ].where((s) => s.isNotEmpty).join(' · ');

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: user.isDisabled
            ? scheme.surfaceContainerHighest
            : scheme.primaryContainer,
        child: Icon(
          user.isAdministrator
              ? Icons.shield_outlined
              : Icons.person_outline_rounded,
          color: user.isDisabled
              ? scheme.onSurfaceVariant
              : scheme.onPrimaryContainer,
        ),
      ),
      title: Text(
        user.name,
        style: TextStyle(
          color: user.isDisabled ? scheme.onSurfaceVariant : null,
        ),
      ),
      subtitle: tags.isEmpty ? null : Text(tags),
      trailing: TextButton(
        onPressed: () => runAdminAction(
          context,
          ref,
          action: (admin) =>
              admin.setUserDisabled(user.id, disabled: !user.isDisabled),
          success: user.isDisabled
              ? l10n.adminUserEnabled(user.name)
              : l10n.adminUserNowDisabled(user.name),
          refresh: () => ref.invalidate(adminUsersProvider),
        ),
        child: Text(
          user.isDisabled ? l10n.adminUserEnable : l10n.adminUserDisable,
        ),
      ),
    );
  }
}

class _DeviceRow extends ConsumerWidget {
  const _DeviceRow({required this.device});

  final AdminDevice device;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    final detail = <String>[
      <String>[device.appName, device.appVersion]
          .where((s) => s.isNotEmpty)
          .join(' '),
      device.username,
      relativeTime(device.lastSeen, l10n),
    ].where((s) => s.isNotEmpty).join(' · ');

    return ListTile(
      leading: const Icon(Icons.devices_rounded),
      title: Text(
        device.name.isEmpty ? device.appName : device.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: detail.isEmpty ? null : Text(detail),
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
    );
  }
}
