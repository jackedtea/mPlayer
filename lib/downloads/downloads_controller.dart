// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../servers/media_library_source.dart';
import '../servers/server_registry.dart';
import 'download_engine.dart';
import 'download_models.dart';
import 'download_snapshot.dart';
import 'download_store.dart';

/// Where the copies live: application support, not documents.
///
/// Documents is the user's own folder on desktop, and a film dropped into
/// it under a GUID would read as clutter. Support is the app's, is kept
/// across updates, and is never offered to a cleaner the way a cache is.
final downloadStoreProvider = FutureProvider<DownloadStore>((ref) async {
  final base = await getApplicationSupportDirectory();
  return DownloadStore(Directory(p.join(base.path, 'downloads')));
});

final downloadEngineProvider = FutureProvider<DownloadEngine>((ref) async {
  return DownloadEngine(store: await ref.watch(downloadStoreProvider.future));
});

/// The signed-in client for a profile, or null while it is not signed in.
///
/// Only the active server has a live client, so a copy queued against
/// another one waits — its URL needs that server's token, and the token is
/// never written into the index.
final downloadSourceProvider =
    Provider<MediaLibrarySource? Function(String profileId)>((ref) {
  final source = ref.watch(serverRegistryProvider).source;
  return (profileId) => source?.profile.id == profileId ? source : null;
});

/// The profiles with at least one whole copy on the device.
///
/// Narrowed through a joined string because a set has no value equality:
/// selecting one directly would rebuild every watcher on every chunk.
final downloadedProfilesProvider = Provider<Set<String>>((ref) {
  final joined = ref.watch(
    downloadsProvider.select((entries) {
      final ids = <String>{
        for (final e in entries)
          if (e.status == DownloadStatus.completed) e.profileId,
      }.toList()
        ..sort();
      return ids.join('\n');
    }),
  );
  return joined.isEmpty ? const <String>{} : joined.split('\n').toSet();
});

final downloadsProvider =
    NotifierProvider<DownloadsController, List<DownloadEntry>>(
  DownloadsController.new,
);

/// The offline copies, and the queue that fills them.
///
/// One file at a time: a server's disk and a phone's radio both do better
/// with one stream than with several fighting, and a queue that finishes
/// items is worth more than one that has every item half done.
///
/// Empty until the index has loaded. The state is written to disk on every
/// change of status, not on every chunk — the partial file is the true byte
/// count and [DownloadStore.load] reads it from there.
class DownloadsController extends Notifier<List<DownloadEntry>> {
  late final Future<void> _ready;
  DownloadStore? _store;
  DownloadEngine? _engine;

  /// The key of the entry being fetched, and how to stop it.
  String? _running;
  CancelToken? _cancel;

  /// Progress reaches the screen this often, not once per 64 KB chunk.
  static const _progressInterval = Duration(milliseconds: 500);

  @override
  List<DownloadEntry> build() {
    ref.onDispose(() => _cancel?.cancel());
    // A server signing in is what lets a waiting copy start, and what the
    // positions played offline have been waiting for.
    ref.listen(downloadSourceProvider, (_, _) {
      unawaited(_pump());
      unawaited(_flushReports());
    });
    _ready = _load();
    return const <DownloadEntry>[];
  }

  Future<void> _load() async {
    try {
      _store = await ref.read(downloadStoreProvider.future);
      _engine = await ref.read(downloadEngineProvider.future);
      state = await _store!.load();
      _unreported.addAll(await _store!.readPendingReports());
    } catch (e) {
      debugPrint('Could not open the downloads: $e');
      return;
    }
    unawaited(_pump());
    unawaited(_flushReports());
  }

  /// Resolves once the index is loaded; for callers that need the list.
  Future<void> get ready => _ready;

  /// The list as it stands, for a caller holding the notifier rather than a
  /// ref — the offline source, which outlives any one rebuild of the map
  /// it sits in.
  List<DownloadEntry> get entries => state;

  /// Null until the index has loaded.
  DownloadStore? get store => _store;

  /// Where offline playback stopped, per entry key, not yet told to the
  /// server. Held here and in `pending_reports.json`.
  final Map<String, Duration> _unreported = <String, Duration>{};

  /// The latest position played offline and not yet reported, if any.
  Duration? unreportedPosition(String profileId, String itemId) =>
      _unreported[DownloadEntry.keyOf(profileId, itemId)];

  /// Keeps a stop the server could not be told about, to tell it later.
  ///
  /// Only the latest per item: the server wants where the user is, not the
  /// history of how they got there.
  Future<void> recordUnreported(
    String profileId,
    String itemId,
    Duration position,
  ) async {
    await _ready;
    _unreported[DownloadEntry.keyOf(profileId, itemId)] = position;
    await _savePending();
  }

  /// Hands each kept stop to its server, where that server is signed in.
  /// One that fails stays for the next sign-in.
  Future<void> _flushReports() async {
    if (!ref.mounted || _unreported.isEmpty) return;
    final sources = ref.read(downloadSourceProvider);
    var changed = false;

    for (final MapEntry<String, Duration> e in _unreported.entries.toList()) {
      final slash = e.key.indexOf('/');
      if (slash < 0) continue;
      final source = sources(e.key.substring(0, slash));
      if (source == null) continue;
      try {
        await source.reportStopped(e.key.substring(slash + 1), position: e.value);
        // Unless it was replaced by a newer stop while this one was in flight.
        if (_unreported[e.key] == e.value) _unreported.remove(e.key);
        changed = true;
      } catch (err) {
        debugPrint('Could not report an offline stop yet: $err');
      }
    }
    if (changed) await _savePending();
  }

  Future<void> _savePending() async {
    try {
      await _store?.writePendingReports(Map<String, Duration>.of(_unreported));
    } catch (e) {
      debugPrint('Could not save the pending reports: $e');
    }
  }

  DownloadEntry? entryFor(String profileId, String itemId) {
    final key = DownloadEntry.keyOf(profileId, itemId);
    for (final DownloadEntry e in state) {
      if (e.key == key) return e;
    }
    return null;
  }

  /// Queues [item] from [source]. A copy that already exists is left alone
  /// unless it had stopped, in which case it is queued again.
  ///
  /// Only things with a file of their own: a series or a season has none,
  /// and expanding one into its episodes is the caller's decision.
  Future<void> enqueue(MediaLibrarySource source, ServerItem item) async {
    await _ready;
    final store = _store;
    if (store == null) return;
    if (!_downloadable(item.kind)) return;

    final existing = entryFor(source.profile.id, item.id);
    if (existing != null) {
      if (!existing.status.isActive &&
          existing.status != DownloadStatus.completed) {
        await resume(existing.key);
      }
      return;
    }

    final entry = DownloadEntry.fromItem(source.profile.id, item);
    await _set(<DownloadEntry>[...state, entry]);

    final poster = source.imageUrl(item, maxWidth: 400);
    if (poster != null) unawaited(_engine?.fetchPoster(entry, poster));

    unawaited(_pump());
  }

  /// Stops a copy where it is. A queued one simply never starts.
  Future<void> pause(String key) async {
    await _ready;
    if (_running == key) {
      // The engine hands the entry back as paused when the fetch unwinds.
      _cancel?.cancel();
      return;
    }
    await _update(key, (e) => e.status == DownloadStatus.queued
        ? e.copyWith(status: DownloadStatus.paused)
        : e);
  }

  /// Puts a paused or failed copy back in the queue, from the byte it
  /// stopped at.
  Future<void> resume(String key) async {
    await _ready;
    await _update(
      key,
      (e) => e.status == DownloadStatus.paused || e.status == DownloadStatus.failed
          ? e.copyWith(status: DownloadStatus.queued, clearError: true)
          : e,
    );
    unawaited(_pump());
  }

  /// Removes a copy and its files, whatever state it is in.
  Future<void> delete(String key) async {
    await _ready;
    final store = _store;
    final entry = state.where((e) => e.key == key).firstOrNull;
    if (store == null || entry == null) return;

    if (_running == key) {
      _cancel?.cancel();
      _running = null;
    }
    await _set(<DownloadEntry>[for (final e in state) if (e.key != key) e]);
    await store.delete(entry);
    unawaited(_pump());
  }

  /// Starts the next queued copy whose server is signed in, if nothing is
  /// running already.
  Future<void> _pump() async {
    final store = _store;
    final engine = _engine;
    if (!ref.mounted || store == null || engine == null || _running != null) {
      return;
    }

    final sources = ref.read(downloadSourceProvider);
    DownloadEntry? next;
    MediaLibrarySource? source;
    for (final DownloadEntry e in state) {
      if (e.status != DownloadStatus.queued) continue;
      source = sources(e.profileId);
      if (source != null) {
        next = e;
        break;
      }
    }
    if (next == null || source == null) return;

    final key = next.key;
    final cancel = CancelToken();
    _running = key;
    _cancel = cancel;
    await _update(key, (e) => e.copyWith(status: DownloadStatus.downloading));

    if (!store.metaFile(next).existsSync()) {
      await takeOfflineSnapshot(source, next, store: store, engine: engine);
      if (!ref.mounted) return;
    }

    final clock = Stopwatch()..start();
    final result = await engine.fetch(
      next,
      source.downloadUrl(next.itemId),
      cancel: cancel,
      onProgress: (received, total) {
        if (clock.elapsed < _progressInterval) return;
        clock.reset();
        _patch(key, (e) => e.copyWith(receivedBytes: received, totalBytes: total));
      },
    );
    // Disposed while it ran: the cancel in onDispose has already unwound it.
    if (!ref.mounted) return;

    // Deleted while it ran: the entry is gone, and so should its bytes be —
    // deleted again now the file is closed, which Windows insists on. Unless
    // it was queued afresh in the meantime, when the folder is the new copy's.
    if (_running != key) {
      if (!state.any((e) => e.key == key)) await store.delete(result);
      unawaited(_pump());
      return;
    }
    _running = null;
    _cancel = null;

    await _update(key, (_) => result);
    unawaited(_pump());
  }

  /// Applies [change] to one entry in memory only — for progress, which
  /// the disk does not need to hear about.
  void _patch(String key, DownloadEntry Function(DownloadEntry) change) {
    if (!ref.mounted) return;
    state = <DownloadEntry>[
      for (final e in state) e.key == key ? change(e) : e,
    ];
  }

  Future<void> _update(
    String key,
    DownloadEntry Function(DownloadEntry) change,
  ) async {
    _patch(key, change);
    await _save();
  }

  Future<void> _set(List<DownloadEntry> entries) async {
    state = entries;
    await _save();
  }

  Future<void> _save() async {
    try {
      await _store?.save(state);
    } catch (e) {
      debugPrint('Could not save the downloads index: $e');
    }
  }

  static bool _downloadable(ServerItemKind kind) =>
      kind == ServerItemKind.movie ||
      kind == ServerItemKind.episode ||
      kind == ServerItemKind.video;
}
