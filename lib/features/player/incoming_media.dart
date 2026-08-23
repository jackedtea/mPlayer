// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:async';
import 'dart:io' show Platform;

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../sources/local_source.dart';
import '../../sources/media_source.dart';

/// What `main` was invoked with, overridden in `main.dart`.
///
/// A provider rather than a global so a test can hand the controller an
/// argument list without touching process state.
final startupArgumentsProvider =
    Provider<List<String>>((ref) => const <String>[]);

/// A file handed to mPlayer by another app.
///
/// Three ways in: the system chooser ("Open with"), the share sheet, and — on
/// desktop — a path on the command line, which is also how Windows and Linux
/// file associations open a file. The first two arrive as a URI, and the URI
/// is what reaches libmpv: nothing is copied and nothing is read ahead of
/// playback. That rules out the usual plugin behaviour of staging the file in
/// the app cache first, which for the multi-gigabyte containers this player
/// exists for means a minutes-long launch and a full internal storage.
///
/// See `android/app/src/main/kotlin/dev/icedtea/mplayer/IntentChannel.kt`.
final incomingMediaProvider =
    NotifierProvider<IncomingMediaController, MediaRef?>(
  IncomingMediaController.new,
);

class IncomingMediaController extends Notifier<MediaRef?> {
  static const _channel = MethodChannel('dev.icedtea.mplayer/intent');
  static const _events = EventChannel('dev.icedtea.mplayer/intent-events');

  StreamSubscription<Object?>? _sub;

  @override
  MediaRef? build() {
    // The channels are registered by MainActivity, so they exist on Android
    // and nowhere else.
    if (Platform.isAndroid) {
      _listen();
      ref.onDispose(() => _sub?.cancel());
      return null;
    }

    _acceptStartupArguments();
    return null;
  }

  /// `mPlayer video.mkv`, and every desktop file association — Windows and
  /// Linux both open a file by launching the app with its path.
  ///
  /// Published a microtask later rather than returned: the app root watches
  /// this provider for *changes*, so a file that is already there when the
  /// first listener attaches would otherwise never be seen.
  void _acceptStartupArguments() {
    final path = ref
        .read(startupArgumentsProvider)
        // Flags belong to the engine, not to us. Nothing here takes an
        // option, so the first bare argument is the file.
        .where((a) => a.isNotEmpty && !a.startsWith('-'))
        .firstOrNull;
    if (path == null) return;

    Future<void>.microtask(() {
      state = MediaRef(
        sourceId: LocalSource.sourceId,
        itemId: path,
        title: p.basename(path),
      );
    });
  }

  void _listen() {
    // Subscribed before the first read on purpose. The native side holds an
    // intent that arrives with no listener attached and releases it on the
    // `initialMedia` call below, so doing it in this order cannot drop one.
    _sub = _events.receiveBroadcastStream().listen(
          _accept,
          onError: (Object e) => debugPrint('Incoming file stream failed: $e'),
        );

    unawaited(
      _channel.invokeMapMethod<String, Object?>('initialMedia').then(
        _accept,
        onError: (Object e) => debugPrint('Initial incoming file failed: $e'),
      ),
    );
  }

  void _accept(Object? payload) {
    final mediaRef = _refFrom(payload);
    if (mediaRef != null) state = mediaRef;
  }

  MediaRef? _refFrom(Object? payload) {
    if (payload is! Map) return null;

    final raw = payload['uri'] as String?;
    if (raw == null || raw.isEmpty) return null;

    final uri = Uri.tryParse(raw);
    // A file:// hand-off is nothing but a path, and the device source reads
    // paths directly. Everything else — content://, rtsp://, https:// — stays
    // a URI and is opened as one.
    final itemId =
        uri != null && uri.scheme == 'file' ? uri.toFilePath() : raw;

    final title = (payload['title'] as String?)?.trim();

    return MediaRef(
      sourceId: LocalSource.sourceId,
      itemId: itemId,
      // A content provider is free to answer nothing for the display name, in
      // which case the tail of the URI is the best that is on offer.
      title: title != null && title.isNotEmpty ? title : p.basename(itemId),
    );
  }

  /// Clears the pending file once it has been routed to the player, so a
  /// rebuild does not open it a second time.
  void consume() => state = null;
}
