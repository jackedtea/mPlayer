// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The device's own media volume, for "Sync volume with device".
///
/// See `android/app/src/main/kotlin/dev/icedtea/mplayer/VolumeChannel.kt`.
/// Android only: a desktop's master volume belongs to the whole machine, and
/// a player that moves it is a player that makes the notification chime
/// deafening.
class DeviceVolume {
  const DeviceVolume._();

  static const _channel = MethodChannel('dev.icedtea.mplayer/volume');
  static const _events = EventChannel('dev.icedtea.mplayer/volume-events');

  static bool get available => Platform.isAndroid;

  /// 0–1, or null when the device will not say.
  static Future<double?> get() async {
    if (!available) return null;
    try {
      return (await _channel.invokeMethod<num>('get'))?.toDouble();
    } catch (e) {
      debugPrint('Could not read the device volume: $e');
      return null;
    }
  }

  /// Sets it to [fraction] (0–1); returns the level the device settled on,
  /// which is a step of its own and rarely exactly what was asked.
  static Future<double?> set(double fraction) async {
    if (!available) return null;
    try {
      final settled = await _channel.invokeMethod<num>('set', <String, Object>{
        'fraction': fraction.clamp(0.0, 1.0),
      });
      return settled?.toDouble();
    } catch (e) {
      debugPrint('Could not set the device volume: $e');
      return null;
    }
  }

  /// Every change made outside the player — the buttons, the system panel.
  static Stream<double> changes() {
    if (!available) return const Stream<double>.empty();
    return _events
        .receiveBroadcastStream()
        .where((v) => v is num)
        .map((v) => (v as num).toDouble());
  }
}

/// Where a combined volume [level] (0 to the boost ceiling) puts the device
/// and the player, when the two are synced.
///
/// Up to 100 the device does the work and the player stays at its recorded
/// level; past it the device is at its maximum and the player amplifies.
/// That is how one swipe runs from silence to 200% without two controls.
({double device, double player}) splitVolumeLevel(double level) {
  if (level <= 100) return (device: (level / 100).clamp(0.0, 1.0), player: 100);
  return (device: 1, player: level);
}

/// The combined level for a device at [device] (0–1) and a player at
/// [player] (percent): the inverse of [splitVolumeLevel].
double combinedVolumeLevel(double device, double player) =>
    player > 100 && device >= 0.999 ? player : device * 100;
