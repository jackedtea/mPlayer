// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../servers/auto_connect.dart';
import '../../servers/server_profile.dart';
import '../../servers/server_registry.dart';
import '../servers/add_server_sheet.dart';
import '../servers/rename_server.dart';
import '../servers/server_library.dart';

/// The server this app is talking to, at the top of Settings, with the two
/// things a user does to it from here: fix its details, or go to another.
///
/// With nothing configured it offers to add one instead, so Settings is never
/// a dead end for someone who skipped the empty state.
class CurrentServerCard extends ConsumerWidget {
  const CurrentServerCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = context.spacing;
    final scheme = context.colors;
    final l10n = AppLocalizations.of(context);
    final profile = ref.watch(serverRegistryProvider).active;
    final connected = ref.watch(connectedServerProvider) != null;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        spacing.screenHorizontal(context.windowSize),
        spacing.sm,
        spacing.screenHorizontal(context.windowSize),
        0,
      ),
      child: Container(
        padding: EdgeInsets.all(spacing.lg),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(context.radii.sheet),
        ),
        child: profile == null
            ? _NoServer(onAdd: () => AddServerSheet.show(context))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _ServerSummary(profile: profile, connected: connected),
                  SizedBox(height: spacing.lg),
                  // Wraps rather than overflowing: two labelled buttons do not
                  // share a narrow phone in Vietnamese at large text.
                  Wrap(
                    spacing: spacing.sm,
                    runSpacing: spacing.sm,
                    alignment: WrapAlignment.end,
                    children: <Widget>[
                      OutlinedButton.icon(
                        icon: const Icon(
                          Icons.drive_file_rename_outline_rounded,
                          size: 18,
                        ),
                        label: Text(l10n.adminRename),
                        onPressed: () => renameServer(context, ref, profile),
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.edit_rounded, size: 18),
                        label: Text(l10n.editServer),
                        onPressed: () =>
                            AddServerSheet.show(context, editing: profile),
                      ),
                      FilledButton.tonalIcon(
                        icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                        label: Text(l10n.changeServer),
                        // The list lives in the Home tab, so going there is
                        // what switching means.
                        onPressed: () {
                          ref.read(serverSessionProvider.notifier).leave();
                          context.go('/home');
                        },
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

class _ServerSummary extends StatelessWidget {
  const _ServerSummary({required this.profile, required this.connected});

  final ServerProfile profile;

  /// Whether Home has gone into this server, rather than only remembering it.
  final bool connected;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final scheme = context.colors;
    final l10n = AppLocalizations.of(context);
    final host = Uri.tryParse(profile.uri)?.authority ?? profile.uri;

    return Row(
      children: <Widget>[
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: context.radii.cardAll,
          ),
          child: Icon(Icons.dns_rounded, color: scheme.onPrimaryContainer),
        ),
        SizedBox(width: spacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Flexible(
                    child: Text(
                      profile.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.texts.titleMedium,
                    ),
                  ),
                  SizedBox(width: spacing.sm),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: connected
                          ? context.semantic.success
                          : scheme.outline,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              Text(
                host,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.texts.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              SizedBox(height: spacing.xs),
              Row(
                children: <Widget>[
                  Icon(
                    Icons.person_rounded,
                    size: 14,
                    color: scheme.onSurfaceVariant,
                  ),
                  SizedBox(width: spacing.xs),
                  Flexible(
                    child: Text(
                      profile.username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.texts.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                  if (profile.isAdministrator) ...<Widget>[
                    SizedBox(width: spacing.sm),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: spacing.sm,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.tertiaryContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        l10n.adminUserAdmin,
                        style: context.texts.labelSmall
                            ?.copyWith(color: scheme.onTertiaryContainer),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NoServer extends StatelessWidget {
  const _NoServer({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final scheme = context.colors;
    final l10n = AppLocalizations.of(context);

    return Row(
      children: <Widget>[
        Icon(Icons.dns_outlined, color: scheme.onSurfaceVariant),
        SizedBox(width: spacing.lg),
        Expanded(
          child: Text(l10n.noServerTitle, style: context.texts.titleSmall),
        ),
        SizedBox(width: spacing.sm),
        FilledButton.tonalIcon(
          icon: const Icon(Icons.add_rounded, size: 18),
          label: Text(l10n.addServer),
          onPressed: onAdd,
        ),
      ],
    );
  }
}
