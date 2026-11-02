// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'remote_protocol.dart';

/// How often a receiver announces itself, and how often a phone asks.
const _announceInterval = Duration(seconds: 3);

/// A receiver not heard from for this long has left the list. Three missed
/// beacons: UDP drops one now and then, and a device blinking in and out of
/// the list is worse than one lingering a few seconds after it went.
const _staleAfter = Duration(seconds: 10);

final InternetAddress _broadcast = InternetAddress('255.255.255.255');

/// Finding each other on the LAN, both ways round.
///
/// A receiver **broadcasts a beacon** every few seconds *and* **answers a
/// phone's query** with the same beacon sent straight back to it. Either alone
/// loses devices: some access points drop broadcast towards wireless clients,
/// which kills the beacon on a phone, while a unicast answer gets through —
/// the same reason `ssdp.dart` needs no Android `MulticastLock`.
///
/// One socket per interface for sending. `255.255.255.255` from a socket
/// bound to "any" leaves by the default route alone, so a desktop with a VPN
/// or a virtual adapter up would announce itself to nobody.
Future<List<RawDatagramSocket>> _bindPerInterface() async {
  final sockets = <RawDatagramSocket>[];
  List<NetworkInterface> interfaces;
  try {
    interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
  } catch (e) {
    debugPrint('Remote: could not list interfaces: $e');
    interfaces = const <NetworkInterface>[];
  }
  for (final NetworkInterface i in interfaces) {
    for (final InternetAddress address in i.addresses) {
      if (address.isLoopback || address.isLinkLocal) continue;
      try {
        final socket = await RawDatagramSocket.bind(address, 0)
          ..broadcastEnabled = true;
        sockets.add(socket);
      } catch (e) {
        debugPrint('Remote: could not bind ${address.address}: $e');
      }
    }
  }
  return sockets;
}

/// The well-known port, shared: a desktop can be a receiver and control a
/// television at the same time, and both halves listen here.
Future<RawDatagramSocket?> _bindShared() async {
  try {
    return await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      RemoteProtocol.discoveryPort,
      reuseAddress: true,
      // Unsupported on Windows, where reuseAddress alone already shares it.
      reusePort: !Platform.isWindows,
    );
  } catch (e) {
    debugPrint('Remote: could not listen on the discovery port: $e');
    return null;
  }
}

void _drain(RawDatagramSocket socket, void Function(Datagram) onDatagram) {
  socket.listen((event) {
    if (event != RawSocketEvent.read) return;
    Datagram? datagram;
    while ((datagram = socket.receive()) != null) {
      onDatagram(datagram!);
    }
  }, onError: (Object e) => debugPrint('Remote: datagram socket: $e'));
}

/// The receiver's half: announce, and answer.
class RemoteAdvertiser {
  RemoteAdvertiser(this.beacon);

  /// What is announced. `host` is unused here — the phone takes the address
  /// from the datagram itself.
  final RemoteDevice beacon;

  RawDatagramSocket? _listener;
  List<RawDatagramSocket> _senders = const <RawDatagramSocket>[];
  Timer? _timer;

  Future<void> start() async {
    _listener = await _bindShared();
    _senders = await _bindPerInterface();
    final listener = _listener;
    if (listener != null) {
      _drain(listener, (d) {
        if (!RemoteDevice.isQuery(d.data)) return;
        // Straight back to whoever asked, from the socket they reached.
        listener.send(_payload, d.address, d.port);
      });
    }
    _announce();
    _timer = Timer.periodic(_announceInterval, (_) => _announce());
  }

  List<int> get _payload => utf8.encode(jsonEncode(beacon.toBeacon()));

  void _announce() {
    final payload = _payload;
    for (final RawDatagramSocket s in _senders) {
      try {
        s.send(payload, _broadcast, RemoteProtocol.discoveryPort);
      } catch (e) {
        // An interface that went away; the others still announce.
        debugPrint('Remote: beacon not sent from ${s.address.address}: $e');
      }
    }
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _listener?.close();
    _listener = null;
    for (final RawDatagramSocket s in _senders) {
      s.close();
    }
    _senders = const <RawDatagramSocket>[];
  }
}

/// The phone's half: listen for beacons, and ask.
class RemoteDiscovery {
  RemoteDiscovery({this.ownId});

  /// This installation's own receiver, if it runs one — never listed.
  final String? ownId;

  final Map<String, (RemoteDevice, DateTime)> _seen =
      <String, (RemoteDevice, DateTime)>{};
  final StreamController<List<RemoteDevice>> _devices =
      StreamController<List<RemoteDevice>>.broadcast();

  RawDatagramSocket? _listener;
  List<RawDatagramSocket> _askers = const <RawDatagramSocket>[];
  Timer? _timer;

  Stream<List<RemoteDevice>> get devices => _devices.stream;

  Future<void> start() async {
    _listener = await _bindShared();
    _askers = await _bindPerInterface();
    final listener = _listener;
    if (listener != null) _drain(listener, _onDatagram);
    for (final RawDatagramSocket s in _askers) {
      _drain(s, _onDatagram);
    }
    _tick();
    _timer = Timer.periodic(_announceInterval, (_) => _tick());
  }

  void _tick() {
    final query = RemoteDevice.queryDatagram();
    for (final RawDatagramSocket s in _askers) {
      try {
        s.send(query, _broadcast, RemoteProtocol.discoveryPort);
      } catch (e) {
        debugPrint('Remote: query not sent from ${s.address.address}: $e');
      }
    }

    final now = DateTime.now();
    final before = _seen.length;
    _seen.removeWhere((_, entry) => now.difference(entry.$2) > _staleAfter);
    if (_seen.length != before) _emit();
  }

  void _onDatagram(Datagram d) {
    final device = RemoteDevice.fromBeacon(d.data, d.address.address);
    if (device == null || device.id == ownId) return;
    final previous = _seen[device.id]?.$1;
    _seen[device.id] = (device, DateTime.now());
    if (previous != device) _emit();
  }

  void _emit() {
    if (_devices.isClosed) return;
    final list = <RemoteDevice>[for (final e in _seen.values) e.$1]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    _devices.add(list);
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _listener?.close();
    _listener = null;
    for (final RawDatagramSocket s in _askers) {
      s.close();
    }
    _askers = const <RawDatagramSocket>[];
    _seen.clear();
  }

  Future<void> dispose() async {
    stop();
    await _devices.close();
  }
}
