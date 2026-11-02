// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/desktop_window.dart' show isDesktop;
import '../../app/television.dart';
import '../../remote/remote_discovery.dart';
import '../../remote/remote_protocol.dart';
import '../../remote/remote_server.dart';
import '../../remote/remote_trust.dart';
import '../../servers/server_profile.dart';
import '../../servers/server_registry.dart';
import '../../sources/media_source.dart';
import '../player/playback_controller.dart';
import '../player/playback_state.dart';
import '../servers/server_library.dart';
import '../settings/player_settings.dart';

final remoteTrustStoreProvider =
    Provider<RemoteTrustStore>((ref) => RemoteTrustStore());

/// Whether the remote may touch the network at all.
///
/// Never under `flutter test`. The widget tests pump the whole app on a
/// Windows or Linux host, which *is* a desktop, and a test suite opening
/// ports on the LAN is a test suite the firewall asks about — besides real
/// sockets never completing inside a widget test's fake clock.
final remoteNetworkAllowedProvider = Provider<bool>(
  (ref) => !kIsWeb && !Platform.environment.containsKey('FLUTTER_TEST'),
);

/// Whether this installation can be a receiver at all: a desktop or a
/// television, which is what sits across the room from a sofa.
final remoteReceiverAvailableProvider = Provider<bool>((ref) {
  if (!ref.watch(remoteNetworkAllowedProvider)) return false;
  return isDesktop || ref.watch(isTelevisionProvider);
});

/// The General settings switch. On by default: a stranger on the LAN still
/// meets the PIN, and a feature that has to be found and switched on first
/// is one most people never learn exists.
final remoteReceiverEnabledProvider =
    NotifierProvider<RemoteReceiverEnabled, bool>(RemoteReceiverEnabled.new);

class RemoteReceiverEnabled extends Notifier<bool> {
  static const _prefsKey = 'remote_receiver_enabled_v1';

  @override
  bool build() {
    Future<void>.microtask(_restore);
    return true;
  }

  Future<void> _restore() async {
    final stored = (await SharedPreferences.getInstance()).getBool(_prefsKey);
    if (stored != null && stored != state) state = stored;
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    await (await SharedPreferences.getInstance()).setBool(_prefsKey, enabled);
  }
}

@immutable
class RemoteReceiverState {
  const RemoteReceiverState({
    this.running = false,
    this.pairing,
    this.controllers = const <String>[],
  });

  final bool running;

  /// A PIN for the screen, while a phone is pairing.
  final RemotePairing? pairing;

  /// Phones connected and trusted now, by name.
  final List<String> controllers;

  RemoteReceiverState copyWith({
    bool? running,
    RemotePairing? pairing,
    bool clearPairing = false,
    List<String>? controllers,
  }) {
    return RemoteReceiverState(
      running: running ?? this.running,
      pairing: clearPairing ? null : pairing ?? this.pairing,
      controllers: controllers ?? this.controllers,
    );
  }
}

/// The keys proving "signed in to the same Jellyfin user", one per profile.
List<List<int>> accountKeysFor(List<ServerProfile> profiles) => <List<int>>[
      for (final ServerProfile p in profiles)
        if (p.serverId.isNotEmpty && p.userId.isNotEmpty)
          RemoteAuth.accountKey(p.serverId, p.userId),
    ];

/// What this installation calls itself to a phone choosing between devices.
///
/// The machine's own name on a desktop — "Windows PC" twice in a list says
/// nothing. A television reports `localhost`, so it is named for what it is.
String remoteDeviceName({required bool television}) {
  if (television) return 'Android TV';
  try {
    final host = Platform.localHostname.trim();
    if (host.isNotEmpty && host != 'localhost') return host;
  } catch (_) {
    // Fall through to the platform's name.
  }
  return switch (Platform.operatingSystem) {
    'windows' => 'Windows PC',
    'linux' => 'Linux PC',
    'macos' => 'Mac',
    'android' => 'Android',
    'ios' => 'iPhone',
    final other => other,
  };
}

final remoteReceiverProvider =
    NotifierProvider<RemoteReceiver, RemoteReceiverState>(RemoteReceiver.new);

/// This installation as a receiver: the server, the beacon, and the bridge
/// from a phone's commands to the one [PlaybackController].
///
/// The player does not know a phone exists. Every command lands on the same
/// controller methods the on-screen buttons, the notification and the
/// picture-in-picture window already call, so there is one player whatever
/// is driving it.
class RemoteReceiver extends Notifier<RemoteReceiverState>
    implements RemoteReceiverDelegate {
  RemoteServer? _server;
  RemoteAdvertiser? _advertiser;

  /// Set by `RemoteReceiverHost`, which sits where the app's router is known.
  GoRouter? router;

  /// Bumped on every start and stop, so a start still binding when the
  /// switch goes off again does not come back to life afterwards.
  int _generation = 0;

  @override
  RemoteReceiverState build() {
    final available = ref.watch(remoteReceiverAvailableProvider);
    final enabled = ref.watch(remoteReceiverEnabledProvider);
    ref.onDispose(_stop);

    if (available && enabled) unawaited(_start(++_generation));

    ref.listen<PlaybackState>(
      playbackControllerProvider,
      (_, next) => _server?.publish(_snapshotOf(next)),
    );
    return const RemoteReceiverState();
  }

  Future<void> _start(int generation) async {
    final television = ref.read(isTelevisionProvider);
    final id = await ref.read(serverRepositoryProvider).deviceId();
    final name = remoteDeviceName(television: television);
    if (generation != _generation) return;

    final server = RemoteServer(
      id: id,
      name: name,
      delegate: this,
      trust: ref.read(remoteTrustStoreProvider),
    );
    final int port;
    try {
      port = await server.start();
    } catch (e) {
      debugPrint('Remote: the receiver could not start: $e');
      return;
    }
    if (generation != _generation) {
      await server.stop();
      return;
    }
    _server = server;
    server.publish(_snapshotOf(ref.read(playbackControllerProvider)));

    final advertiser = RemoteAdvertiser(
      RemoteDevice(
        id: id,
        name: name,
        kind: television ? RemoteDeviceKind.television : RemoteDeviceKind.desktop,
        host: '',
        port: port,
      ),
    );
    _advertiser = advertiser;
    await advertiser.start();
    state = state.copyWith(running: true);
  }

  void _stop() {
    _generation++;
    _advertiser?.stop();
    _advertiser = null;
    unawaited(_server?.stop());
    _server = null;
  }

  RemoteSnapshot _snapshotOf(PlaybackState playback) {
    final settings = ref.read(playerSettingsProvider);
    final media = playback.media;
    final active = ref.read(serverRegistryProvider).active;

    List<RemoteTrack> tracks(List<MediaTrack> all) => <RemoteTrack>[
          // The phone draws its own "Off", in its own language.
          for (final MediaTrack t in all)
            if (!t.isAuto && !t.isOff) RemoteTrack(id: t.id, label: t.label),
        ];

    return RemoteSnapshot(
      title: media?.title,
      subtitle: media?.sourceLine,
      itemId: media?.ref.itemId,
      serverId: media != null && active?.id == media.ref.sourceId
          ? active!.serverId
          : null,
      position: playback.position,
      duration: playback.duration,
      playing: playback.playing,
      buffering: playback.buffering,
      volume: playback.volume,
      hasPrevious: playback.queue.hasPrevious,
      hasNext: playback.queue.hasNext,
      audioTracks: tracks(playback.audioTracks),
      subtitleTracks: tracks(playback.subtitleTracks),
      activeAudio: playback.activeAudio?.id,
      activeSubtitle: playback.activeSubtitle?.id,
      skipBack: settings.skipBack,
      skipForward: settings.skipForward,
      error: playback.error,
    );
  }

  @override
  List<List<int>> accountKeys() =>
      accountKeysFor(ref.read(serverRegistryProvider).profiles);

  @override
  void showPairing(RemotePairing? pairing) {
    state = pairing == null
        ? state.copyWith(clearPairing: true)
        : state.copyWith(pairing: pairing);
  }

  @override
  void controllersChanged(List<String> names) {
    state = state.copyWith(controllers: names);
  }

  @override
  Future<(RemoteErrorCode, String?)?> handle(RemoteCommand command) async {
    final playback = ref.read(playbackControllerProvider.notifier);
    final now = ref.read(playbackControllerProvider);

    switch (command.kind) {
      case RemoteCommandKind.playPause:
        await playback.playOrPause();
      case RemoteCommandKind.play:
        await playback.play();
      case RemoteCommandKind.pause:
        await playback.pause();
      case RemoteCommandKind.seek:
        await playback.seek(command.at!);
      case RemoteCommandKind.skip:
        await playback.skip(command.at!);
      case RemoteCommandKind.next:
        await playback.playNext();
      case RemoteCommandKind.previous:
        await playback.playPrevious();
      case RemoteCommandKind.volume:
        await playback.setVolume(command.volume!);
      case RemoteCommandKind.audio:
        final track =
            now.audioTracks.where((t) => t.id == command.trackId).firstOrNull;
        if (track != null) await playback.chooseAudioTrack(track);
      case RemoteCommandKind.subtitle:
        final id = command.trackId;
        if (id == null) {
          await playback.chooseSubtitleTrack(null);
        } else {
          final track = now.subtitleTracks.where((t) => t.id == id).firstOrNull;
          if (track != null) await playback.chooseSubtitleTrack(track);
        }
      case RemoteCommandKind.stop:
        _stopPlayer(playback);
      case RemoteCommandKind.playItem:
        return _playItem(command);
    }
    return null;
  }

  bool get _playerShowing =>
      router?.routerDelegate.currentConfiguration.uri.path == '/player';

  /// Leaves the player the way Back would, so the screen's own teardown —
  /// closing report, orientation, system bars — runs exactly as it always
  /// does. Only without a player screen is the controller stopped directly.
  void _stopPlayer(PlaybackController playback) {
    final router = this.router;
    if (router != null && _playerShowing && router.canPop()) {
      router.pop();
    } else {
      unawaited(playback.stop());
    }
  }

  /// Plays a server item here, resolved with this installation's own
  /// sign-in. The phone sent an id, not a stream: a URL carries the phone's
  /// token, and this receiver has one of its own.
  Future<(RemoteErrorCode, String?)?> _playItem(RemoteCommand command) async {
    final active = ref.read(serverRegistryProvider).active;
    if (active == null || active.serverId != command.serverId) {
      return (RemoteErrorCode.wrongServer, active?.name);
    }
    // A PIN-guarded server nobody has unlocked here stays shut to a phone
    // too — the remote is not a way round the lock on the receiver's door.
    if (ref.read(connectedServerProvider) == null) {
      return (RemoteErrorCode.locked, null);
    }
    final source = ref.read(mediaSourcesProvider)[active.id];
    final router = this.router;
    if (source == null || router == null) {
      return (RemoteErrorCode.locked, null);
    }

    final PlayableMedia media;
    try {
      final resolved = await source.resolve(
        MediaRef(sourceId: active.id, itemId: command.itemId!, title: ''),
      );
      media = command.fromStart ? resolved.startingAt(Duration.zero) : resolved;
    } on MediaSourceException catch (e) {
      return (RemoteErrorCode.playFailed, e.message);
    }

    if (_playerShowing && ref.read(playbackControllerProvider).hasMedia) {
      await ref.read(playbackControllerProvider.notifier).openInstead(media);
    } else {
      unawaited(router.push('/player', extra: media));
    }
    return null;
  }
}
