// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

/// What the administration screens read, and the one place they act through.
///
/// Every screen here follows the same shape: a `FutureProvider` for the list
/// and [runAdminAction] for anything that changes the server. The pairing is
/// deliberate — an action that succeeds has to invalidate what it changed, or
/// the screen goes on showing the state from before it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../servers/media_library_source.dart' show ServerException;
import '../../servers/server_admin.dart';
import '../../servers/server_registry.dart';

/// Whether the signed-in account may see the administration section at all.
///
/// A courtesy, not the security boundary: every route behind it answers 403
/// on its own. Hiding the section spares a non-administrator a row of screens
/// that could only ever show them an error.
final isAdministratorProvider = Provider<bool>(
  (ref) => ref.watch(serverRegistryProvider).active?.isAdministrator ?? false,
);

/// The administration client, rebuilt whenever the active server changes.
///
/// Disposed with the provider, because it owns an HTTP client: leaving one
/// open per server the user ever switched to is a socket leak with a long
/// fuse.
final serverAdminProvider = FutureProvider<ServerAdmin?>((ref) async {
  // Watched, not read: signing out or switching servers has to tear this down
  // and build the next one, and a client still pointed at the old server
  // would answer questions about it.
  ref.watch(serverRegistryProvider);

  final admin = await ref.read(serverRegistryProvider.notifier).admin();
  if (admin != null) ref.onDispose(admin.dispose);
  return admin;
});

/// Runs [read] against the administration client, or answers empty.
///
/// The null case is not an error: it is "nothing is signed in", or "this
/// account is not an administrator", and both are states the screen draws
/// rather than failures it reports.
Future<T> _withAdmin<T>(
  Ref ref,
  Future<T> Function(ServerAdmin admin) read,
  T empty,
) async {
  final admin = await ref.watch(serverAdminProvider.future);
  if (admin == null) return empty;
  return read(admin);
}

final systemInfoProvider = FutureProvider<ServerSystemInfo?>(
  (ref) => _withAdmin(ref, (a) => a.systemInfo(), null),
);

/// Who is connected right now.
///
/// Deliberately **not** polled on a timer. A list that refreshes itself every
/// few seconds is a request every few seconds for as long as the screen is
/// open, on a phone, to answer a question that is rarely urgent — the screen
/// offers a pull to refresh instead, which is the same information at the
/// moment it is actually wanted.
final adminSessionsProvider = FutureProvider<List<AdminSession>>(
  (ref) => _withAdmin(ref, (a) => a.sessions(), const <AdminSession>[]),
);

final scheduledTasksProvider = FutureProvider<List<ScheduledTask>>(
  (ref) => _withAdmin(ref, (a) => a.tasks(), const <ScheduledTask>[]),
);

final adminUsersProvider = FutureProvider<List<AdminUser>>(
  (ref) => _withAdmin(ref, (a) => a.users(), const <AdminUser>[]),
);

/// One account and its policy, asked again each time its screen opens.
///
/// `autoDispose` because the policy is exactly the thing another
/// administrator may have changed since, and an editor opening on a cached
/// copy would show — and then save — the old one.
final adminUserProvider = FutureProvider.autoDispose
    .family<AdminUserDetail?, String>(
      (ref, userId) =>
          _withAdmin<AdminUserDetail?>(ref, (a) => a.user(userId), null),
    );

/// The libraries an account can be given, for the access list.
final adminLibrariesProvider = FutureProvider.autoDispose<List<AdminLibrary>>(
  (ref) => _withAdmin(ref, (a) => a.libraries(), const <AdminLibrary>[]),
);

/// The ratings the parental limit can be set to. A server that will not say
/// costs the editor that one row and nothing else.
final parentalRatingsProvider =
    FutureProvider.autoDispose<List<ParentalRatingOption>>((ref) async {
      try {
        return await _withAdmin(
          ref,
          (a) => a.parentalRatings(),
          const <ParentalRatingOption>[],
        );
      } on ServerException {
        return const <ParentalRatingOption>[];
      }
    });

/// The signed-in account's id, so the screens can refuse to let an
/// administrator delete, disable or demote themselves.
///
/// The server refuses some of those on its own (the last administrator) and
/// not others (an administrator demoting themselves while another exists),
/// and losing the section mid-edit is not an outcome anybody chose.
final currentAdminUserIdProvider = Provider<String?>(
  (ref) => ref.watch(serverRegistryProvider).active?.userId,
);

/// The devices one account has signed in from, for its Activity tab.
final adminUserDevicesProvider = FutureProvider.autoDispose
    .family<List<AdminDevice>, String>(
      (ref, userId) => _withAdmin(
        ref,
        (a) => a.devices(userId: userId),
        const <AdminDevice>[],
      ),
    );

/// What one account has done lately, for its Activity tab.
///
/// Keyed by id and name together because the server filters by name and the
/// client by id; a record has the value equality a family key needs.
final adminUserActivityProvider = FutureProvider.autoDispose
    .family<List<ActivityEntry>, ({String id, String name})>(
      (ref, user) => _withAdmin(
        ref,
        (a) => a.activity(limit: 100, user: user),
        const <ActivityEntry>[],
      ),
    );

/// Every library with its folders on disk.
final adminLibraryFoldersProvider =
    FutureProvider.autoDispose<List<AdminLibraryFolder>>(
      (ref) => _withAdmin(
        ref,
        (a) => a.libraryFolders(),
        const <AdminLibraryFolder>[],
      ),
    );

/// One item's editable metadata, asked again each time the editor opens.
final adminItemMetadataProvider = FutureProvider.autoDispose
    .family<ItemMetadata?, String>(
      (ref, itemId) =>
          _withAdmin<ItemMetadata?>(ref, (a) => a.itemMetadata(itemId), null),
    );

/// Where the server keeps things and how full the disks are, or null on a
/// server too old to say.
final serverStorageProvider = FutureProvider.autoDispose<ServerStorage?>(
  (ref) => _withAdmin<ServerStorage?>(ref, (a) => a.storage(), null),
);

final serverLogFilesProvider = FutureProvider.autoDispose<List<ServerLogFile>>(
  (ref) => _withAdmin(ref, (a) => a.logFiles(), const <ServerLogFile>[]),
);

/// One log file's text — its tail, when it is large.
final serverLogTextProvider = FutureProvider.autoDispose.family<String, String>(
  (ref, name) => _withAdmin(ref, (a) => a.logText(name), ''),
);

/// One configuration object, '' for the main one. Asked again each time a
/// page opens: these are exactly what another administrator may have changed.
final adminConfigProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>?, String>(
  (ref, key) => _withAdmin<Map<String, dynamic>?>(
    ref,
    (a) => a.configuration(key.isEmpty ? null : key),
    null,
  ),
);

final culturesProvider = FutureProvider.autoDispose<List<ConfigOption>>(
  (ref) => _withAdmin(ref, (a) => a.cultures(), const <ConfigOption>[]),
);

final countriesProvider = FutureProvider.autoDispose<List<ConfigOption>>(
  (ref) => _withAdmin(ref, (a) => a.countries(), const <ConfigOption>[]),
);

/// The accounts, as options — the NFO page's "whose watch data".
final userOptionsProvider = FutureProvider.autoDispose<List<ConfigOption>>(
  (ref) async => <ConfigOption>[
    for (final AdminUser u in await ref.watch(adminUsersProvider.future))
      ConfigOption(value: u.id, label: u.name),
  ],
);

/// Every device signed in to the server, for the Devices page.
final adminDevicesProvider = FutureProvider.autoDispose<List<AdminDevice>>(
  (ref) => _withAdmin(ref, (a) => a.devices(), const <AdminDevice>[]),
);

final apiKeysProvider = FutureProvider.autoDispose<List<ServerApiKey>>(
  (ref) => _withAdmin(ref, (a) => a.apiKeys(), const <ServerApiKey>[]),
);

final serverPluginsProvider = FutureProvider<List<ServerPlugin>>(
  (ref) => _withAdmin(ref, (a) => a.plugins(), const <ServerPlugin>[]),
);

/// Performs one administrative action and says what happened.
///
/// Every button on these screens goes through here, so that three things
/// happen the same way every time: the failure reaches the user as the
/// sentence the client wrote rather than as an exception, the affected
/// providers are invalidated so the screen redraws from the server rather
/// than from hope, and a success says so — an action whose only feedback is a
/// list that looks identical afterwards leaves the user pressing it again.
///
/// Returns true when the action was accepted.
Future<bool> runAdminAction(
  BuildContext context,
  WidgetRef ref, {
  required Future<void> Function(ServerAdmin admin) action,
  required String success,
  VoidCallback? refresh,
}) async {
  final messenger = ScaffoldMessenger.of(context);

  final admin = await ref.read(serverAdminProvider.future);
  if (admin == null) return false;

  try {
    await action(admin);
  } on ServerException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
    return false;
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('$e')));
    return false;
  }

  // The caller invalidates rather than naming providers here: Riverpod does
  // not export the common supertype of a provider and a family, so a list of
  // "things to refresh" cannot be typed, and a closure says the same thing
  // without the ceremony.
  refresh?.call();

  messenger.showSnackBar(SnackBar(content: Text(success)));
  return true;
}
