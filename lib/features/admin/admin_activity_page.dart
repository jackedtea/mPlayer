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

/// What the server has been doing — sign-ins, playbacks, scans, failures.
class AdminActivityPage extends ConsumerWidget {
  const AdminActivityPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final entries = ref.watch(activityLogProvider);

    return AdminScaffold(
      title: l10n.adminActivity,
      onRefresh: () async {
        ref.invalidate(activityLogProvider);
        await ref.read(activityLogProvider.future);
      },
      child: AdminList(
        loading: entries.isLoading,
        emptyText: l10n.adminNoActivity,
        children: <Widget>[
          for (final ActivityEntry entry
              in entries.value ?? const <ActivityEntry>[])
            _EntryRow(entry: entry),
        ],
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry});

  final ActivityEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = context.colors;
    final semantic = context.semantic;

    final (IconData icon, Color colour) = switch (entry.severity) {
      ActivitySeverity.error => (Icons.error_outline_rounded, scheme.error),
      ActivitySeverity.warning => (
          Icons.warning_amber_rounded,
          semantic.warning,
        ),
      ActivitySeverity.information => (
          Icons.info_outline_rounded,
          scheme.onSurfaceVariant,
        ),
    };

    return ListTile(
      leading: Icon(icon, color: colour),
      title: Text(entry.name),
      subtitle: Text(
        <String>[
          relativeTime(entry.at, l10n),
          // The server writes a second line on some events and not on
          // others; an empty one would just be a gap under the title.
          entry.overview,
        ].where((s) => s.isNotEmpty).join(' · '),
      ),
      isThreeLine: entry.overview.length > 40,
    );
  }
}
