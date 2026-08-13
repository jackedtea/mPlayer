// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../../sources/local_source.dart';
import '../../sources/media_source.dart';

/// A file handed to mPlayer by another app.
///
/// Two ways in: the system chooser ("Open with") and the share sheet. Both
/// arrive here as a path, because the plugin copies a `content://` URI out to
/// a readable file first — which also sidesteps the open question of whether
/// libmpv can open a content URI directly.
final incomingMediaProvider =
    NotifierProvider<IncomingMediaController, MediaRef?>(
  IncomingMediaController.new,
);

class IncomingMediaController extends Notifier<MediaRef?> {
  StreamSubscription<List<SharedMediaFile>>? _sub;

  @override
  MediaRef? build() {
    // Desktop has no share sheet; the plugin's platform channels are absent
    // there and calling them throws.
    if (!_isSupported) return null;

    _listen();
    ref.onDispose(() => _sub?.cancel());
    return null;
  }

  static bool get _isSupported => Platform.isAndroid || Platform.isIOS;

  void _listen() {
    // Files that arrived while the app was already running.
    _sub = ReceiveSharingIntent.instance.getMediaStream().listen(
      _accept,
      onError: (Object e) => debugPrint('Shared media stream failed: $e'),
    );

    // The file that launched the app, if it was launched by one.
    unawaited(
      ReceiveSharingIntent.instance.getInitialMedia().then(
        (files) {
          _accept(files);
          // Without this the same file is replayed every time the app
          // resumes, dragging the user back into the player.
          ReceiveSharingIntent.instance.reset();
        },
        onError: (Object e) => debugPrint('Initial shared media failed: $e'),
      ),
    );
  }

  void _accept(List<SharedMediaFile> files) {
    if (files.isEmpty) return;

    // A chooser can hand over several files; the player takes one at a time,
    // so the first is opened and the rest ignored rather than silently
    // dropping the lot.
    final file = files.first;
    final path = file.path;
    if (path.isEmpty) return;

    state = MediaRef(
      sourceId: LocalSource.sourceId,
      itemId: path,
      title: p.basename(path),
    );
  }

  /// Clears the pending file once it has been routed to the player, so a
  /// rebuild does not open it a second time.
  void consume() => state = null;
}
