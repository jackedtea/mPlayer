// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How downloads behave on this device.
///
/// Kept on the device, not the server: which network is metered and how
/// much disk there is to spare are facts about this phone, and another
/// device of the same user has its own answers.
@immutable
class DownloadSettings {
  const DownloadSettings({this.wifiOnly = true, this.removeWatched = false});

  /// Hold the queue on a metered network. On by default, as the design's
  /// Downloads screen promises: a film is gigabytes, and a cellular plan
  /// spent without asking is not something to find out about afterwards.
  final bool wifiOnly;

  /// Delete a copy once it has been watched to the end on this device.
  final bool removeWatched;

  DownloadSettings copyWith({bool? wifiOnly, bool? removeWatched}) =>
      DownloadSettings(
        wifiOnly: wifiOnly ?? this.wifiOnly,
        removeWatched: removeWatched ?? this.removeWatched,
      );
}

final downloadSettingsProvider =
    NotifierProvider<DownloadSettingsController, DownloadSettings>(
  DownloadSettingsController.new,
);

class DownloadSettingsController extends Notifier<DownloadSettings> {
  static const _wifiOnlyKey = 'downloads_wifi_only_v1';
  static const _removeWatchedKey = 'downloads_remove_watched_v1';

  @override
  DownloadSettings build() {
    Future<void>.microtask(_restore);
    return const DownloadSettings();
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!ref.mounted) return;
      state = DownloadSettings(
        wifiOnly: prefs.getBool(_wifiOnlyKey) ?? state.wifiOnly,
        removeWatched: prefs.getBool(_removeWatchedKey) ?? state.removeWatched,
      );
    } catch (e) {
      debugPrint('Could not read the download settings: $e');
    }
  }

  Future<void> setWifiOnly(bool value) async {
    state = state.copyWith(wifiOnly: value);
    await _write(_wifiOnlyKey, value);
  }

  Future<void> setRemoveWatched(bool value) async {
    state = state.copyWith(removeWatched: value);
    await _write(_removeWatchedKey, value);
  }

  Future<void> _write(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (e) {
      debugPrint('Could not save a download setting: $e');
    }
  }
}

/// What the network the device is on means for a download.
enum DownloadNetwork { unmetered, metered, none }

/// Cellular is metered; Wi-Fi and Ethernet are not; nothing is nothing.
///
/// Android reports Wi-Fi alone when both radios are up, which is the one it
/// routes over. A VPN rides on whichever of the others is there, so it
/// decides nothing by itself.
@visibleForTesting
DownloadNetwork downloadNetworkFrom(List<ConnectivityResult> results) {
  if (results.contains(ConnectivityResult.wifi) ||
      results.contains(ConnectivityResult.ethernet)) {
    return DownloadNetwork.unmetered;
  }
  if (results.contains(ConnectivityResult.mobile) ||
      results.contains(ConnectivityResult.satellite)) {
    return DownloadNetwork.metered;
  }
  if (results.isEmpty ||
      results.every((r) => r == ConnectivityResult.none)) {
    return DownloadNetwork.none;
  }
  return DownloadNetwork.unmetered;
}

/// The network as it is now, and as it changes.
final downloadNetworkProvider = StreamProvider<DownloadNetwork>((ref) async* {
  final connectivity = Connectivity();
  yield downloadNetworkFrom(await connectivity.checkConnectivity());
  yield* connectivity.onConnectivityChanged.map(downloadNetworkFrom);
});

/// Why the queue is not moving, or null when nothing is holding it.
enum DownloadHold { waitingForWifi, offline }

final downloadHoldProvider = Provider<DownloadHold?>((ref) {
  final wifiOnly = ref.watch(downloadSettingsProvider.select((s) => s.wifiOnly));
  // A platform that cannot say — or has not said yet — holds nothing back;
  // the server's own refusal is the better signal there.
  final network = ref.watch(downloadNetworkProvider).value;
  return switch (network) {
    DownloadNetwork.none => DownloadHold.offline,
    DownloadNetwork.metered when wifiOnly => DownloadHold.waitingForWifi,
    _ => null,
  };
});
