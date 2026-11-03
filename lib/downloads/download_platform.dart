// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The platform's part in downloading: on Android, the foreground service
/// that keeps the engine alive in the background and the notification that
/// must come with it. Nothing anywhere else, where a backgrounded app keeps
/// running anyway.
///
/// Overridden in tests, which run on no Android at all.
final downloadPlatformProvider =
    Provider<DownloadPlatform>((ref) => DownloadPlatform());

class DownloadPlatform {
  static const _channel = MethodChannel('dev.icedtea.mplayer/downloads');

  /// Whether there is anything to show a notification on. Checked before
  /// the text is even worded, so a desktop never pays for it.
  bool get enabled => !kIsWeb && Platform.isAndroid;

  /// Shows (or updates) the notification. [percent] is null while the size
  /// is unknown, which draws an indeterminate bar.
  Future<void> show({
    required String title,
    required String text,
    int? percent,
  }) async {
    if (!enabled) return;
    try {
      await _channel.invokeMethod<void>('update', <String, Object?>{
        'title': title,
        'text': text,
        'percent': percent ?? -1,
      });
    } on PlatformException catch (e) {
      debugPrint('Could not update the download notification: $e');
    }
  }

  Future<void> hide() async {
    if (!enabled) return;
    try {
      await _channel.invokeMethod<void>('stop');
    } on PlatformException catch (e) {
      debugPrint('Could not stop the download service: $e');
    }
  }
}
