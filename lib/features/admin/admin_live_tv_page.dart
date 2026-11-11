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

/// The tuners and guide providers Live TV is set up with, each removable.
///
/// **Adding** either is left to the web dashboard: each tuner type (HDHomeRun,
/// M3U, …) and each guide provider (Schedules Direct, XMLTV) has its own
/// form, sign-in or file, and a half-set-up tuner is worse than none.
class AdminLiveTvPage extends ConsumerWidget {
  const AdminLiveTvPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final config = ref.watch(adminConfigProvider('livetv'));

    final tuners = liveTvEntries(config.value, 'TunerHosts');
    final providers = liveTvEntries(config.value, 'ListingProviders');

    return AdminScaffold(
      title: l10n.adminLiveTv,
      onRefresh: () async {
        ref.invalidate(adminConfigProvider('livetv'));
        await ref.read(adminConfigProvider('livetv').future);
      },
      child: switch (config) {
        AsyncError(:final error) => AdminList(
          emptyText: '$error',
          children: const <Widget>[],
        ),
        AsyncLoading() => const Center(child: CircularProgressIndicator()),
        _ => AdminList(
          children: <Widget>[
            SectionHeader(title: l10n.adminTuners),
            if (tuners.isEmpty) _empty(context, l10n.adminNoTuners),
            for (final LiveTvEntry t in tuners)
              _EntryRow(
                entry: t,
                icon: Icons.settings_input_antenna_rounded,
                remove: (admin) => admin.deleteTuner(t.id),
              ),
            SectionHeader(title: l10n.adminGuideProviders),
            if (providers.isEmpty) _empty(context, l10n.adminNoGuideProviders),
            for (final LiveTvEntry p in providers)
              _EntryRow(
                entry: p,
                icon: Icons.event_note_outlined,
                remove: (admin) => admin.deleteGuideProvider(p.id),
              ),
            _empty(context, l10n.adminLiveTvAddOnWeb),
          ],
        ),
      },
    );
  }

  Widget _empty(BuildContext context, String text) => Padding(
    padding: EdgeInsets.symmetric(vertical: context.spacing.sm),
    child: AdminNote(text: text),
  );
}

class _EntryRow extends ConsumerWidget {
  const _EntryRow({
    required this.entry,
    required this.icon,
    required this.remove,
  });

  final LiveTvEntry entry;
  final IconData icon;
  final Future<void> Function(ServerAdmin admin) remove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      leading: Icon(icon),
      title: Text(entry.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: entry.detail.isEmpty
          ? null
          : Text(entry.detail, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline_rounded),
        tooltip: l10n.adminRemove,
        onPressed: () async {
          final sure = await confirmAdminAction(
            context,
            title: l10n.adminRemoveQuestion(entry.title),
            body: l10n.adminRemoveLiveTvBody,
            confirmLabel: l10n.adminRemove,
          );
          if (!sure || !context.mounted) return;
          await runAdminAction(
            context,
            ref,
            action: (admin) => remove(admin),
            success: l10n.adminRemoved(entry.title),
            refresh: () => ref.invalidate(adminConfigProvider('livetv')),
          );
        },
      ),
    );
  }
}

/// A tuner or guide provider, as a row names it.
@immutable
class LiveTvEntry {
  const LiveTvEntry({required this.id, required this.title, this.detail = ''});

  final String id;
  final String title;
  final String detail;
}

/// The entries under [listKey] of the `livetv` configuration: a tuner's
/// friendly name (else its type) over its address; a provider's type over
/// its listings id or file.
List<LiveTvEntry> liveTvEntries(Map<String, dynamic>? config, String listKey) {
  final list = config?[listKey];
  if (list is! List) return const <LiveTvEntry>[];
  String text(Map<Object?, Object?> m, String k) =>
      (m[k] as String?)?.trim() ?? '';

  return <LiveTvEntry>[
    for (final Object? e in list)
      if (e is Map && text(e, 'Id').isNotEmpty)
        LiveTvEntry(
          id: text(e, 'Id'),
          title: <String>[
            text(e, 'FriendlyName'),
            text(e, 'Type'),
          ].firstWhere((s) => s.isNotEmpty, orElse: () => text(e, 'Id')),
          detail: <String>[
            if (text(e, 'FriendlyName').isNotEmpty) text(e, 'Type'),
            text(e, 'Url'),
            text(e, 'ListingsId'),
            text(e, 'Path'),
          ].where((s) => s.isNotEmpty).join(' · '),
        ),
  ];
}
