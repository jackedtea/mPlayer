// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sources/media_source.dart';
import '../../remote/remote_client.dart';
import '../../remote/remote_discovery.dart';
import '../../remote/remote_protocol.dart';
import '../../servers/server_registry.dart';
import 'remote_receiver.dart';

enum RemotePhase {
  /// Not connected to anything.
  idle,
  connecting,

  /// The receiver is showing a PIN and waiting for it.
  pin,
  connected,
}

@immutable
class RemoteSessionState {
  const RemoteSessionState({
    this.searching = false,
    this.devices = const <RemoteDevice>[],
    this.phase = RemotePhase.idle,
    this.device,
    this.triesLeft,
    this.snapshot = const RemoteSnapshot(),
    this.unreachable = false,
    this.failure,
    this.failureCount = 0,
  });

  final bool searching;
  final List<RemoteDevice> devices;
  final RemotePhase phase;

  /// The receiver being connected to or controlled.
  final RemoteDevice? device;

  /// After a wrong PIN, how many more the receiver will take.
  final int? triesLeft;

  final RemoteSnapshot snapshot;

  /// The last connection attempt never reached the receiver.
  final bool unreachable;

  /// The last thing the receiver refused, with a count that moves on every
  /// refusal so the same one twice is still noticed.
  final RemoteFailed? failure;
  final int failureCount;

  bool get connected => phase == RemotePhase.connected;

  RemoteSessionState copyWith({
    bool? searching,
    List<RemoteDevice>? devices,
    RemotePhase? phase,
    RemoteDevice? device,
    bool clearDevice = false,
    int? triesLeft,
    bool clearTries = false,
    RemoteSnapshot? snapshot,
    bool? unreachable,
    RemoteFailed? failure,
  }) {
    return RemoteSessionState(
      searching: searching ?? this.searching,
      devices: devices ?? this.devices,
      phase: phase ?? this.phase,
      device: clearDevice ? null : device ?? this.device,
      triesLeft: clearTries ? null : triesLeft ?? this.triesLeft,
      snapshot: snapshot ?? this.snapshot,
      unreachable: unreachable ?? this.unreachable,
      failure: failure ?? this.failure,
      failureCount: failure != null ? failureCount + 1 : failureCount,
    );
  }
}

final remoteSessionProvider =
    NotifierProvider<RemoteSession, RemoteSessionState>(RemoteSession.new);

/// The phone as a remote: finding receivers, pairing with one, driving it.
///
/// Kept alive for the app's lifetime rather than the remote screen's, so the
/// connection survives going back to the library to pick something — which
/// is exactly when "Play" should go to the receiver instead of this screen.
class RemoteSession extends Notifier<RemoteSessionState> {
  RemoteDiscovery? _discovery;
  StreamSubscription<List<RemoteDevice>>? _found;
  RemoteClient? _client;
  StreamSubscription<RemoteEvent>? _events;

  @override
  RemoteSessionState build() {
    // Sockets only: Riverpod forbids touching `state` from a dispose.
    ref.onDispose(() {
      _closeDiscovery();
      unawaited(_drop());
    });
    return const RemoteSessionState();
  }

  /// Started with the device list and stopped with it: there is no reason
  /// to keep a socket listening for beacons while nobody is choosing.
  Future<void> startSearching() async {
    if (_discovery != null || !ref.read(remoteNetworkAllowedProvider)) return;
    final ownId = ref.read(remoteReceiverAvailableProvider)
        ? await ref.read(serverRepositoryProvider).deviceId()
        : null;
    final discovery = RemoteDiscovery(ownId: ownId);
    _discovery = discovery;
    _found = discovery.devices.listen(
      (devices) => state = state.copyWith(devices: devices),
    );
    state = state.copyWith(searching: true, devices: const <RemoteDevice>[]);
    await discovery.start();
  }

  void stopSearching() {
    _closeDiscovery();
    if (state.searching) state = state.copyWith(searching: false);
  }

  void _closeDiscovery() {
    unawaited(_found?.cancel());
    _found = null;
    unawaited(_discovery?.dispose());
    _discovery = null;
  }

  /// A receiver typed in by address, for a network where broadcast does not
  /// get through. Its id is only learnt from its hello, so a placeholder
  /// stands in and the hello check is skipped for it.
  Future<void> connectToAddress(String input) async {
    final trimmed = input.trim();
    final parts = trimmed.split(':');
    final host = parts.first;
    final port = parts.length > 1
        ? int.tryParse(parts[1]) ?? RemoteProtocol.preferredPort
        : RemoteProtocol.preferredPort;
    if (host.isEmpty) return;
    await connect(
      RemoteDevice(
        id: '',
        name: host,
        kind: RemoteDeviceKind.desktop,
        host: host,
        port: port,
      ),
    );
  }

  Future<void> connect(RemoteDevice device) async {
    await _drop();
    state = state.copyWith(
      phase: RemotePhase.connecting,
      device: device,
      clearTries: true,
      unreachable: false,
      snapshot: const RemoteSnapshot(),
    );

    final registry = ref.read(serverRegistryProvider);
    final client = RemoteClient(
      device: device,
      phoneId: await ref.read(serverRepositoryProvider).deviceId(),
      phoneName: remoteDeviceName(television: false),
      accountKeys: accountKeysFor(registry.profiles),
      trust: ref.read(remoteTrustStoreProvider),
    );
    _client = client;
    _events = client.events.listen(_onEvent);

    try {
      await client.connect();
    } catch (e) {
      debugPrint('Remote: could not reach ${device.host}: $e');
      if (!identical(_client, client)) return;
      await _drop();
      state = state.copyWith(
        phase: RemotePhase.idle,
        clearDevice: true,
        unreachable: true,
      );
    }
  }

  void _onEvent(RemoteEvent event) {
    switch (event) {
      case RemoteWelcomed():
        state = state.copyWith(phase: RemotePhase.connected, clearTries: true);
      case RemotePinRequested(:final triesLeft):
        state = state.copyWith(
          phase: RemotePhase.pin,
          triesLeft: triesLeft,
          clearTries: triesLeft == null,
        );
      case RemoteStateChanged(:final snapshot):
        state = state.copyWith(snapshot: snapshot);
      case RemoteFailed():
        state = state.copyWith(failure: event);
      case RemoteClosed():
        unawaited(_drop());
        state = state.copyWith(
          phase: RemotePhase.idle,
          clearDevice: true,
          clearTries: true,
          snapshot: const RemoteSnapshot(),
        );
    }
  }

  void submitPin(String pin) => _client?.sendPin(pin);

  void send(RemoteCommand command) {
    if (state.connected) _client?.send(command);
  }

  /// Sends [itemId] to the receiver to play there. False when there is no
  /// receiver to send it to, and the caller plays it here instead.
  bool playOnReceiver(String serverId, String itemId, {bool fromStart = false}) {
    if (!state.connected || serverId.isEmpty) return false;
    _client?.send(
      RemoteCommand(
        RemoteCommandKind.playItem,
        serverId: serverId,
        itemId: itemId,
        fromStart: fromStart,
      ),
    );
    return true;
  }

  /// The same, for a whole queue. False as [playOnReceiver] is.
  bool playQueueOnReceiver(
    String serverId,
    List<MediaRef> items,
    int index,
  ) {
    if (!state.connected || serverId.isEmpty) return false;
    _client?.send(
      RemoteCommand.playQueue(
        serverId: serverId,
        items: <(String, String)>[
          for (final MediaRef item in items) (item.itemId, item.title),
        ],
        index: index,
      ),
    );
    return true;
  }

  Future<void> disconnect() async {
    await _drop();
    state = state.copyWith(
      phase: RemotePhase.idle,
      clearDevice: true,
      clearTries: true,
      snapshot: const RemoteSnapshot(),
    );
  }

  Future<void> _drop() async {
    final events = _events;
    final client = _client;
    _events = null;
    _client = null;
    await events?.cancel();
    await client?.close();
  }
}
