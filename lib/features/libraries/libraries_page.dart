// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../servers/media_library_source.dart';
import '../../widgets/no_server_note.dart';
import '../servers/library_grid_page.dart';
import '../servers/server_library.dart';
import 'last_library.dart';

/// The Libraries tab — opens straight into a library rather than onto a list
/// of them.
///
/// Which one is the library last browsed on this server, or the first one
/// when there is none yet. Moving to another is the switcher in the library's
/// own title, so a list in front of it would be a tap that does nothing for
/// the common case of carrying on where the user left off.
class LibrariesPage extends ConsumerWidget {
  const LibrariesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final source = ref.watch(connectedServerProvider);
    if (source == null) return _Placeholder(child: const NoServerNote());

    final viewsRequest = ref.watch(serverViewsProvider);
    final lastRequest = ref.watch(lastLibraryProvider);
    final views = viewsRequest.value;

    // Both, before choosing: the first library drawn while the remembered
    // one is still on its way would be replaced a moment later.
    if (views == null || (lastRequest.isLoading && !lastRequest.hasValue)) {
      return const _Placeholder(child: CircularProgressIndicator());
    }
    if (views.isEmpty) {
      return _Placeholder(
        child: Text(
          l10n.noResults,
          style: context.texts.bodyMedium
              ?.copyWith(color: context.colors.onSurfaceVariant),
        ),
      );
    }

    final profileId = source.profile.id;
    final remembered = lastRequest.value?[profileId];
    final viewId = views.any((LibraryView v) => v.id == remembered)
        ? remembered!
        : views.first.id;

    return LibraryGridPage(
      // A new library is a new page: its filters, sort and tab do not carry
      // over, since a genre picked in Films need not exist in Television.
      key: ValueKey<String>(viewId),
      viewId: viewId,
      onSwitchLibrary: (id) =>
          ref.read(lastLibraryProvider.notifier).remember(profileId, id),
    );
  }
}

/// The tab before a library can be shown.
class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).libraries)),
      body: Center(child: child),
    );
  }
}
