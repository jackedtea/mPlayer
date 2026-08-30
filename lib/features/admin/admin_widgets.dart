// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

/// The handful of pieces every administration screen is built from.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../servers/server_registry.dart';
import 'admin_providers.dart';

/// An administration screen: the app bar, the guard, and pull-to-refresh.
///
/// The guard is the point. Every one of these screens is meaningless without
/// an administrator behind it, and each re-deriving "signed in? admin? still
/// loading?" is three chances to get a different answer on a different screen.
class AdminScaffold extends ConsumerWidget {
  const AdminScaffold({
    super.key,
    required this.title,
    required this.child,
    required this.onRefresh,
    this.actions = const <Widget>[],
    this.floatingActionButton,
  });

  final String title;
  final Widget child;

  /// What a pull invalidates. Passed rather than inferred: only the screen
  /// knows which providers it is showing.
  final Future<void> Function() onRefresh;

  final List<Widget> actions;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final admin = ref.watch(serverAdminProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: context.colors.surfaceContainerHigh,
        title: Text(title),
        actions: actions,
      ),
      floatingActionButton: floatingActionButton,
      body: switch (admin) {
        // The client is built from the stored token, which means a read from
        // the keychain — brief, but not instant, and a flash of "not an
        // administrator" before it lands would be a lie.
        AsyncLoading() => const Center(child: CircularProgressIndicator()),
        AsyncError(:final error) => AdminNote(text: '$error'),
        AsyncData(value: null) => AdminNote(
            text: ref.watch(serverRegistryProvider).hasServer
                ? l10n.adminNotAdmin
                : l10n.adminNoServer,
          ),
        AsyncData() => RefreshIndicator(
            onRefresh: onRefresh,
            child: child,
          ),
      },
    );
  }
}

/// A centred sentence where a list would be.
class AdminNote extends StatelessWidget {
  const AdminNote({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.spacing.screenHorizontal(context.windowSize),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: context.texts.bodyMedium
              ?.copyWith(color: context.colors.onSurfaceVariant),
        ),
      ),
    );
  }
}

/// A list that scrolls even when it is empty.
///
/// `RefreshIndicator` needs a scrollable that reaches its edge, and a `Column`
/// holding one line of text does not — so an empty state that is not built
/// this way silently cannot be pulled to refresh, which is the one gesture
/// that would fix it.
class AdminList extends StatelessWidget {
  const AdminList({
    super.key,
    required this.children,
    this.emptyText,
    this.loading = false,
  });

  final List<Widget> children;
  final String? emptyText;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      if (loading) return const Center(child: CircularProgressIndicator());

      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: <Widget>[
          SizedBox(height: MediaQuery.sizeOf(context).height / 4),
          if (emptyText != null) AdminNote(text: emptyText!),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(
        bottom: context.spacing.xl + context.systemBottomInset,
      ),
      children: children,
    );
  }
}

/// Asks before something that cannot be undone from here.
///
/// Returns true only on an explicit yes; dismissing the dialog is a no.
Future<bool> confirmAdminAction(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  bool destructive = true,
}) async {
  final l10n = AppLocalizations.of(context);

  final answer = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: context.colors.error,
                  foregroundColor: context.colors.onError,
                )
              : null,
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );

  return answer ?? false;
}

/// "3 minutes ago", "yesterday", "12 Mar".
///
/// Relative near the present and absolute beyond it, because that is how the
/// two are actually read: "four days ago" needs counting, and "12 Mar" tells
/// nobody whether a session is live.
String relativeTime(DateTime? at, AppLocalizations l10n) {
  if (at == null) return '';

  final delta = DateTime.now().difference(at.toLocal());
  if (delta.isNegative) return l10n.justNow;

  if (delta.inMinutes < 1) return l10n.justNow;
  if (delta.inMinutes < 60) return l10n.minutesAgo(delta.inMinutes);
  if (delta.inHours < 24) return l10n.hoursAgo(delta.inHours);
  if (delta.inDays < 7) return l10n.daysAgo(delta.inDays);

  final local = at.toLocal();
  return '${local.day}/${local.month}/${local.year}';
}
