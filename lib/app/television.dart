// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether this device is a television: an Android TV box or a TV with
/// Android built in.
///
/// Asked once, before the first frame, because it decides the shape of the
/// whole shell — a remote has no pointer and no touch, so everything has to
/// be reachable by moving focus, and the focused thing has to be obvious from
/// across a room.
///
/// Kotlin only reports the fact (`MainActivity`'s device channel); every
/// decision about what a television gets is made here in Dart.
Future<bool> detectTelevision() async {
  if (!Platform.isAndroid) return false;
  try {
    return await const MethodChannel('dev.icedtea.mplayer/device')
            .invokeMethod<bool>('isTelevision') ??
        false;
  } on PlatformException {
    return false;
  } on MissingPluginException {
    return false;
  }
}

/// True on a television. Overridden in `main` with [detectTelevision]'s
/// answer; false everywhere else, tests included.
final isTelevisionProvider = Provider<bool>((ref) => false);
