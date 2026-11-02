// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'remote_protocol.dart';
import 'remote_trust.dart';

/// Something the receiver said.
sealed class RemoteEvent {
  const RemoteEvent();
}

/// Trusted; commands may follow.
class RemoteWelcomed extends RemoteEvent {
  const RemoteWelcomed();
}

/// A PIN is on the receiver's screen; [RemoteClient.sendPin] answers it.
class RemotePinRequested extends RemoteEvent {
  const RemotePinRequested({this.triesLeft});

  /// Null on the first request, a count after a wrong PIN.
  final int? triesLeft;
}

class RemoteStateChanged extends RemoteEvent {
  const RemoteStateChanged(this.snapshot);

  final RemoteSnapshot snapshot;
}

class RemoteFailed extends RemoteEvent {
  const RemoteFailed(this.code, [this.message]);

  final RemoteErrorCode code;
  final String? message;
}

/// The connection ended, whoever ended it.
class RemoteClosed extends RemoteEvent {
  const RemoteClosed();
}

/// The phone's end of one connection to one receiver.
class RemoteClient {
  RemoteClient({
    required this.device,
    required this.phoneId,
    required this.phoneName,
    required this.accountKeys,
    required this.trust,
  });

  final RemoteDevice device;
  final String phoneId;
  final String phoneName;

  /// One per server account this phone is signed in to.
  final List<List<int>> accountKeys;
  final RemoteTrustStore trust;

  static const _connectTimeout = Duration(seconds: 5);
  static const _pingInterval = Duration(seconds: 5);

  WebSocket? _socket;
  final List<int> _nonce = RemoteProtocol.newNonce();
  List<int>? _receiverNonce;
  String _receiverName = '';

  /// The beacon's id, or — for an address typed in by hand, which comes with
  /// none — the one the receiver's hello gives.
  late String _receiverId = device.id;
  String? _pin;

  final StreamController<RemoteEvent> _events =
      StreamController<RemoteEvent>.broadcast();

  Stream<RemoteEvent> get events => _events.stream;

  /// Throws a [SocketException] or [TimeoutException] when the receiver
  /// cannot be reached; everything after that arrives on [events].
  Future<void> connect() async {
    final socket = await WebSocket.connect(device.uri.toString())
        .timeout(_connectTimeout);
    socket.pingInterval = _pingInterval;
    _socket = socket;
    socket.listen(
      _onMessage,
      onDone: _onDone,
      onError: (Object e) => debugPrint('Remote: client: $e'),
      cancelOnError: true,
    );
  }

  void send(RemoteCommand command) =>
      _send(RemoteProtocol.encode(command.toJson()));

  void sendPin(String pin) {
    final receiverNonce = _receiverNonce;
    if (receiverNonce == null) return;
    _pin = pin;
    _send(RemoteProtocol.encode(<String, Object?>{
      't': RemoteProtocol.pair,
      'mac': RemoteAuth.proof(
        key: RemoteAuth.pinKey(pin),
        purpose: 'pair',
        receiverNonce: receiverNonce,
        phoneNonce: _nonce,
        receiverId: _receiverId,
        phoneId: phoneId,
      ),
    }));
  }

  Future<void> close() async {
    try {
      await _socket?.close();
    } catch (_) {
      // Already gone.
    }
  }

  void _send(String message) {
    try {
      _socket?.add(message);
    } catch (e) {
      debugPrint('Remote: send failed: $e');
    }
  }

  void _emit(RemoteEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  Future<void> _onMessage(Object? raw) async {
    final message = RemoteProtocol.decode(raw);
    if (message == null) return;

    switch (message['t']) {
      case RemoteProtocol.hello:
        await _onHello(message);
      case RemoteProtocol.welcome:
        _emit(const RemoteWelcomed());
      case RemoteProtocol.pairRequired:
        _emit(const RemotePinRequested());
      case RemoteProtocol.pairFailed:
        final left = message['triesLeft'];
        _emit(RemotePinRequested(triesLeft: left is int ? left : 0));
      case RemoteProtocol.paired:
        final pin = _pin;
        final receiverNonce = _receiverNonce;
        if (pin != null && receiverNonce != null) {
          await trust.addReceiver(
            RemotePeer(
              id: _receiverId,
              name: _receiverName,
              secret: RemoteAuth.pairedSecret(pin, receiverNonce, _nonce),
            ),
          );
        }
      case RemoteProtocol.state:
        _emit(RemoteStateChanged(RemoteSnapshot.fromJson(message)));
      case RemoteProtocol.error:
        final code = RemoteErrorCode.parse(message['code']);
        final text = message['message'];
        if (code != null) {
          _emit(RemoteFailed(code, text is String ? text : null));
        }
    }
  }

  Future<void> _onHello(Map<String, Object?> message) async {
    final rawNonce = message['nonce'];
    final id = message['id'];
    if (rawNonce is! String ||
        id is! String ||
        id.isEmpty ||
        (device.id.isNotEmpty && id != device.id)) {
      // A different installation answering at that address than the one the
      // beacon named; a pairing filed under one id must not be offered to it.
      await close();
      return;
    }
    _receiverId = id;
    if (message['v'] != RemoteProtocol.version) {
      _emit(const RemoteFailed(RemoteErrorCode.version));
      await close();
      return;
    }
    final receiverNonce = base64Decode(rawNonce);
    _receiverNonce = receiverNonce;
    final name = message['name'];
    _receiverName = name is String ? name : device.name;

    String proof(List<int> key, String purpose) => RemoteAuth.proof(
          key: key,
          purpose: purpose,
          receiverNonce: receiverNonce,
          phoneNonce: _nonce,
          receiverId: _receiverId,
          phoneId: phoneId,
        );

    final peer = (await trust.receivers())[_receiverId];
    _send(RemoteProtocol.encode(<String, Object?>{
      't': RemoteProtocol.auth,
      'v': RemoteProtocol.version,
      'id': phoneId,
      'name': phoneName,
      'nonce': base64Encode(_nonce),
      'account': <String>[for (final k in accountKeys) proof(k, 'account')],
      if (peer != null) 'paired': proof(peer.secret, 'paired'),
    }));
  }

  void _onDone() {
    _emit(const RemoteClosed());
    unawaited(_events.close());
  }
}
