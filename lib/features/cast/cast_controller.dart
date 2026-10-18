// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../cast/cast_device.dart';
import '../../cast/cast_discovery.dart';
import '../../cast/cast_renderer.dart';
import '../../cast/chromecast.dart';
import '../../cast/dlna_renderer.dart';
import '../../sources/media_source.dart';

@immutable
class CastState {
  const CastState({
    this.searching = false,
    this.devices = const <CastDevice>[],
    this.device,
    this.status = const CastStatus(),
    this.error,
  });

  final bool searching;
  final List<CastDevice> devices;

  /// The device being played on, or null when playback is local.
  final CastDevice? device;

  /// What that device last reported. Polled, since neither protocol pushes.
  final CastStatus status;

  final String? error;

  bool get isCasting => device != null;

  CastState copyWith({
    bool? searching,
    List<CastDevice>? devices,
    CastDevice? device,
    bool clearDevice = false,
    CastStatus? status,
    String? error,
    bool clearError = false,
  }) {
    return CastState(
      searching: searching ?? this.searching,
      devices: devices ?? this.devices,
      device: clearDevice ? null : device ?? this.device,
      status: status ?? this.status,
      error: clearError ? null : error ?? this.error,
    );
  }
}

final castControllerProvider = NotifierProvider<CastController, CastState>(
  CastController.new,
);

/// Finding devices, and playing on one instead of on this screen.
///
/// **There is no proxy any more.** It used to be the part worth
/// understanding: libmpv played local files from a loopback address, which
/// means nothing to a television, so casting started a second server bound to
/// every interface and handed the device a LAN URL. Nothing local plays now —
/// every stream comes from a media server, which is already an address on the
/// network with its token in the query — so the URL goes straight across and
/// nothing this app runs is reachable from the network at all.
class CastController extends Notifier<CastState> {
  static const _pollInterval = Duration(seconds: 2);

  CastRenderer? _renderer;
  Timer? _poll;
  StreamSubscription<List<CastDevice>>? _chromecasts;

  /// Kept apart because they arrive differently: DLNA answers a search once,
  /// while the Cast router keeps reporting as televisions wake up. Merging
  /// one into the other would drop whichever finished first.
  List<CastDevice> _dlna = const <CastDevice>[];
  List<CastDevice> _chromecast = const <CastDevice>[];

  @override
  CastState build() {
    _chromecasts = Chromecast.instance.devices.listen((devices) {
      _chromecast = devices;
      state = state.copyWith(devices: _merged());
    });

    ref.onDispose(() {
      _poll?.cancel();
      unawaited(_chromecasts?.cancel());
      unawaited(Chromecast.instance.stopDiscovery());
      unawaited(_renderer?.dispose());
    });
    return const CastState();
  }

  /// Chromecasts first: on a phone they are the likelier answer, and the DLNA
  /// list can be long on a network full of media servers.
  List<CastDevice> _merged() => <CastDevice>[..._chromecast, ..._dlna];

  /// Looks for devices. Safe to call again; the list is replaced, not merged,
  /// so a television switched off since the last search disappears.
  Future<void> search() async {
    if (state.searching) return;
    state = state.copyWith(searching: true, clearError: true);

    // Both at once. The Cast router answers almost immediately from what the
    // platform already knows, while SSDP has to wait out its timeout, so
    // running them in sequence would mean staring at an empty sheet.
    try {
      final results = await Future.wait(<Future<List<CastDevice>>>[
        discoverDlnaDevices(),
        Chromecast.instance.startDiscovery(),
      ]);

      _dlna = results[0];
      _chromecast = results[1];
      state = state.copyWith(devices: _merged(), searching: false);
    } catch (e) {
      debugPrint('Cast search failed: $e');
      state = state.copyWith(
        searching: false,
        error: 'Could not search the network for devices.',
      );
    }
  }

  /// Called when the picker closes: an active Cast scan costs battery, and
  /// nothing is watching the list any more.
  Future<void> stopSearching() => Chromecast.instance.stopDiscovery();

  /// Starts playing [media] on [device], from [from].
  ///
  /// Returns false and leaves [CastState.error] set on failure — the caller
  /// keeps playing locally, which is the right fallback for a television that
  /// did not answer.
  Future<bool> castTo(
    CastDevice device,
    PlayableMedia media, {
    Duration from = Duration.zero,
  }) async {
    await _teardown();
    state = state.copyWith(clearError: true);

    try {
      final url = _publish(media);
      final renderer = _rendererFor(device);

      await renderer.load(
        url,
        title: media.title,
        contentType: contentTypeFor(media.title),
        position: from,
      );

      _renderer = renderer;
      state = state.copyWith(device: device, status: const CastStatus());
      _startPolling();
      return true;
    } on CastException catch (e) {
      state = state.copyWith(error: e.message);
      await _teardown();
      return false;
    } catch (e) {
      debugPrint('Cast failed: $e');
      state = state.copyWith(error: 'Could not start playing on ${device.name}.');
      await _teardown();
      return false;
    }
  }

  Future<void> play() => _command((r) => r.play());

  Future<void> pause() => _command((r) => r.pause());

  Future<void> seek(Duration to) => _command((r) => r.seek(to));

  Future<void> playOrPause() {
    return state.status.isPlaying ? pause() : play();
  }

  /// Stops the device and brings playback back to this screen.
  Future<void> disconnect() async {
    final renderer = _renderer;
    if (renderer != null) {
      // Best effort: a television already switched off cannot be told to
      // stop, and the local player still has to be handed back.
      try {
        await renderer.stop();
      } catch (e) {
        debugPrint('Could not stop the device: $e');
      }
    }

    await _teardown();
    state = state.copyWith(
      clearDevice: true,
      status: const CastStatus(),
    );
  }

  Future<void> _command(Future<void> Function(CastRenderer) action) async {
    final renderer = _renderer;
    if (renderer == null) return;

    try {
      await action(renderer);
      // Ask straight away rather than waiting for the next poll, so a button
      // press does not appear to do nothing for two seconds.
      await _refresh();
    } on CastException catch (e) {
      state = state.copyWith(error: e.message);
    }
  }

  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(_pollInterval, (_) => unawaited(_refresh()));
  }

  Future<void> _refresh() async {
    final renderer = _renderer;
    if (renderer == null) return;

    try {
      state = state.copyWith(status: await renderer.status());
    } catch (e) {
      // A dropped poll is not worth surfacing; the next one usually works,
      // and a device that has really gone will fail a command too.
      debugPrint('Cast status poll failed: $e');
    }
  }

  CastRenderer _rendererFor(CastDevice device) {
    return switch (device.kind) {
      CastKind.dlna => DlnaRenderer(device),
      CastKind.chromecast => ChromecastRenderer(device),
    };
  }

  /// The URL the television is given.
  ///
  /// A server stream is already fetchable from the network, so the device
  /// gets it unchanged and this app stays out of the data path.
  ///
  /// The three refusals are each a case that would otherwise leave a
  /// television on a black screen with no explanation:
  ///
  /// - **Not http(s)** — nothing else is left that resolves anything, so this
  ///   means the server answered with something unexpected.
  /// - **Auth headers** — they do not travel with a URL and a device cannot
  ///   be told about them. Jellyfin puts its token in the query (`api_key`),
  ///   so no server the app signs into hits this today; the check is here so
  ///   that one which does fails with a sentence.
  /// - **Loopback** — a server reachable only from this device cannot be
  ///   reached by a television on the same network.
  Uri _publish(PlayableMedia media) {
    final uri = media.uri;

    if (uri.scheme != 'http' && uri.scheme != 'https') {
      throw const CastException(
        'This item cannot be cast — the server did not give an address a '
        'device could fetch.',
      );
    }
    if (media.headers.isNotEmpty) {
      throw const CastException(
        'This item cannot be cast — it needs a sign-in a device cannot be '
        'given.',
      );
    }
    if (_isLoopback(uri)) {
      throw const CastException(
        'This item cannot be cast — the server is only reachable from this '
        'device.',
      );
    }

    return uri;
  }

  bool _isLoopback(Uri uri) =>
      uri.host == '127.0.0.1' ||
      uri.host == 'localhost' ||
      uri.host == '::1';

  Future<void> _teardown() async {
    _poll?.cancel();
    _poll = null;

    final renderer = _renderer;
    _renderer = null;
    await renderer?.dispose();
  }
}

/// A MIME type from the file's extension.
///
/// A television decides whether it can play a stream from this, so guessing
/// `video/mp4` for an unknown container is the useful default: it makes the
/// device try, where `application/octet-stream` makes many refuse outright.
String contentTypeFor(String name) {
  return switch (p.extension(name).toLowerCase()) {
    '.mkv' => 'video/x-matroska',
    '.webm' => 'video/webm',
    '.avi' => 'video/x-msvideo',
    '.mov' => 'video/quicktime',
    '.wmv' || '.asf' => 'video/x-ms-wmv',
    '.flv' => 'video/x-flv',
    '.ts' || '.m2ts' || '.mts' => 'video/mp2t',
    '.mpg' || '.mpeg' => 'video/mpeg',
    '.3gp' => 'video/3gpp',
    '.ogv' => 'video/ogg',
    _ => 'video/mp4',
  };
}
