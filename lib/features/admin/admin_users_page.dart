// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../servers/server_admin.dart';
import 'admin_providers.dart';
import 'admin_user_page.dart' show showCreateUserDialog;
import 'admin_widgets.dart';

/// Accounts and the devices they have signed in from.
///
/// The server's accounts. A row opens that account, whose Devices tab is
/// where what it signs in from is listed and forgotten.
class AdminUsersPage extends ConsumerWidget {
  const AdminUsersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    final users = ref.watch(adminUsersProvider);

    return AdminScaffold(
      title: l10n.adminUsers,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'admin-add-user',
        onPressed: () => _createUser(context, ref, l10n),
        icon: const Icon(Icons.person_add_alt_rounded),
        label: Text(l10n.adminAddUser),
      ),
      onRefresh: () async {
        ref.invalidate(adminUsersProvider);
        await ref.read(adminUsersProvider.future);
      },
      child: AdminList(
        loading: users.isLoading,
        emptyText: l10n.adminNoUsers,
        children: <Widget>[
          for (final AdminUser user in users.value ?? const <AdminUser>[])
            _UserRow(user: user),
        ],
      ),
    );
  }
}

Future<void> _createUser(
  BuildContext context,
  WidgetRef ref,
  AppLocalizations l10n,
) async {
  final answer = await showCreateUserDialog(context);
  if (answer == null || !context.mounted) return;

  final router = GoRouter.of(context);
  AdminUser? made;
  await runAdminAction(
    context,
    ref,
    action: (admin) async =>
        made = await admin.createUser(answer.name, answer.password),
    success: l10n.adminUserCreated(answer.name),
    refresh: () => ref.invalidate(adminUsersProvider),
  );

  // Straight into the new account: a fresh one can see every library and do
  // nearly everything, and the next thing an administrator does is usually
  // narrow that.
  final id = made?.id ?? '';
  if (id.isNotEmpty) router.push('/admin/users/$id');
}

class _UserRow extends ConsumerWidget {
  const _UserRow({required this.user});

  final AdminUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = context.colors;

    final isSelf = ref.watch(currentAdminUserIdProvider) == user.id;

    final tags = <String>[
      if (isSelf) l10n.adminUserYou,
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
      onTap: () => context.push('/admin/users/${user.id}'),
      // No switch on your own row, and none on an administrator's that is
      // already on: the server refuses to disable an administrator, so the
      // button could only ever produce an error.
      trailing: isSelf || (user.isAdministrator && !user.isDisabled)
          ? const Icon(Icons.chevron_right_rounded)
          : TextButton(
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
