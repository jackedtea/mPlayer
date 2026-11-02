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

/// A PIN on the receiver's screen, waiting to be typed into a phone.
@immutable
class RemotePairing {
  const RemotePairing({required this.phoneName, required this.pin});

  final String phoneName;
  final String pin;
}

/// What the server needs from the app around it. Kept to an interface so
/// the server knows nothing of Riverpod, the router or the player.
abstract interface class RemoteReceiverDelegate {
  /// One key per server account this receiver is signed in to — see
  /// [RemoteAuth.accountKey].
  List<List<int>> accountKeys();

  /// Does what [command] asks; returns why not, or null when done.
  Future<(RemoteErrorCode, String?)?> handle(RemoteCommand command);

  /// A PIN to show, or null to take it down.
  void showPairing(RemotePairing? pairing);

  /// The phones connected and trusted right now, by name.
  void controllersChanged(List<String> names);
}

/// The receiver: a WebSocket on the LAN that a trusted phone drives.
///
/// `dart:io` alone — `HttpServer` and `WebSocketTransformer` cover the whole
/// transport, so the remote adds no dependency, the same reasoning that kept
/// casting's SOAP hand-written.
class RemoteServer {
  RemoteServer({
    required this.id,
    required this.name,
    required this.delegate,
    required this.trust,
  });

  final String id;
  final String name;
  final RemoteReceiverDelegate delegate;
  final RemoteTrustStore trust;

  /// More than this many connections at once is not a family's phones.
  static const _maxSessions = 4;

  /// Long enough to read a PIN off a television and type it on a phone.
  static const _handshakeTimeout = Duration(minutes: 2);

  /// Notices a phone that walked out of Wi-Fi range without saying goodbye.
  static const _pingInterval = Duration(seconds: 5);

  /// How often the position alone is worth a message.
  static const _positionInterval = Duration(seconds: 1);

  HttpServer? _http;
  final Set<_Session> _sessions = <_Session>{};
  _Session? _pairing;

  RemoteSnapshot _snapshot = const RemoteSnapshot();
  RemoteSnapshot? _sent;
  DateTime _sentAt = DateTime.fromMillisecondsSinceEpoch(0);

  int? get port => _http?.port;

  Future<int> start() async {
    HttpServer http;
    try {
      http = await HttpServer.bind(
        InternetAddress.anyIPv4,
        RemoteProtocol.preferredPort,
      );
    } on SocketException {
      // Taken — by a second copy of the app on this machine, or by anything
      // else. The beacon carries whichever port this ends up on.
      http = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    }
    _http = http;
    http.listen(_onRequest, onError: (Object e) => debugPrint('Remote: $e'));
    return http.port;
  }

  Future<void> stop() async {
    for (final _Session s in _sessions.toList()) {
      await s.close();
    }
    _sessions.clear();
    _setPairing(null);
    await _http?.close(force: true);
    _http = null;
  }

  /// Hands the current state to every trusted phone.
  ///
  /// At once when anything but the position changed; the position on its own
  /// at most every [_positionInterval], or a playing film would be ten
  /// messages a second across the room for a slider nobody is dragging.
  void publish(RemoteSnapshot snapshot) {
    _snapshot = snapshot;
    final sent = _sent;
    final now = DateTime.now();
    if (sent != null &&
        sent.sameApartFromPosition(snapshot) &&
        (sent.position == snapshot.position ||
            now.difference(_sentAt) < _positionInterval)) {
      return;
    }
    _sent = snapshot;
    _sentAt = now;
    final message = RemoteProtocol.encode(snapshot.toJson());
    for (final _Session s in _sessions) {
      if (s.trusted) s.send(message);
    }
  }

  Future<void> _onRequest(HttpRequest request) async {
    if (request.uri.path != RemoteProtocol.path ||
        !WebSocketTransformer.isUpgradeRequest(request) ||
        _sessions.length >= _maxSessions) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }
    try {
      final socket = await WebSocketTransformer.upgrade(request);
      socket.pingInterval = _pingInterval;
      final session = _Session(this, socket);
      _sessions.add(session);
      session.begin();
    } catch (e) {
      debugPrint('Remote: upgrade refused: $e');
    }
  }

  void _setPairing(_Session? session) {
    _pairing = session;
    delegate.showPairing(
      session == null
          ? null
          : RemotePairing(phoneName: session.phoneName, pin: session.pin!),
    );
  }

  void _closed(_Session session) {
    _sessions.remove(session);
    if (identical(_pairing, session)) _setPairing(null);
    _controllersChanged();
  }

  void _controllersChanged() {
    delegate.controllersChanged(<String>[
      for (final _Session s in _sessions)
        if (s.trusted) s.phoneName,
    ]);
  }
}

class _Session {
  _Session(this.server, this.socket);

  final RemoteServer server;
  final WebSocket socket;

  final List<int> nonce = RemoteProtocol.newNonce();
  List<int>? phoneNonce;
  String phoneId = '';
  String phoneName = '';
  bool trusted = false;
  bool _closed = false;

  String? pin;
  int triesLeft = RemoteProtocol.pinTries;
  Timer? _handshakeTimer;

  void begin() {
    socket.listen(
      _onMessage,
      onDone: _onDone,
      onError: (Object e) => debugPrint('Remote: session: $e'),
      cancelOnError: true,
    );
    _handshakeTimer = Timer(RemoteServer._handshakeTimeout, () {
      if (!trusted) unawaited(close());
    });
    send(RemoteProtocol.encode(<String, Object?>{
      't': RemoteProtocol.hello,
      'v': RemoteProtocol.version,
      'id': server.id,
      'name': server.name,
      'nonce': base64Encode(nonce),
    }));
  }

  void send(String message) {
    if (_closed) return;
    try {
      socket.add(message);
    } catch (e) {
      debugPrint('Remote: send failed: $e');
    }
  }

  void _sendType(String type, [Map<String, Object?> extra = const <String, Object?>{}]) =>
      send(RemoteProtocol.encode(<String, Object?>{'t': type, ...extra}));

  Future<void> _onMessage(Object? raw) async {
    final message = RemoteProtocol.decode(raw);
    if (message == null) return;
    final type = message['t'];

    if (trusted) {
      if (type != RemoteProtocol.command) return;
      final command = RemoteCommand.fromJson(message);
      if (command == null) return;
      final failure = await server.delegate.handle(command);
      if (failure != null) {
        _sendType(RemoteProtocol.error, <String, Object?>{
          'code': failure.$1.name,
          'message': failure.$2,
        });
      }
      return;
    }

    if (type == RemoteProtocol.auth) {
      await _onAuth(message);
    } else if (type == RemoteProtocol.pair) {
      await _onPair(message);
    }
  }

  Future<void> _onAuth(Map<String, Object?> message) async {
    if (phoneNonce != null) return; // Once per connection.
    final version = message['v'];
    final id = message['id'];
    final rawNonce = message['nonce'];
    if (id is! String || id.isEmpty || rawNonce is! String) {
      await close();
      return;
    }
    if (version != RemoteProtocol.version) {
      _sendType(RemoteProtocol.error, <String, Object?>{
        'code': RemoteErrorCode.version.name,
      });
      await close();
      return;
    }
    try {
      phoneNonce = base64Decode(rawNonce);
    } on FormatException {
      await close();
      return;
    }
    phoneId = id;
    final name = message['name'];
    phoneName = name is String && name.isNotEmpty ? name : id;

    String expected(List<int> key, String purpose) => RemoteAuth.proof(
          key: key,
          purpose: purpose,
          receiverNonce: nonce,
          phoneNonce: phoneNonce!,
          receiverId: server.id,
          phoneId: phoneId,
        );

    // A phone paired before.
    final paired = message['paired'];
    if (paired is String) {
      final peer = (await server.trust.phones())[phoneId];
      if (peer != null && RemoteAuth.same(expected(peer.secret, 'paired'), paired)) {
        _trust();
        return;
      }
    }

    // A phone signed in to the same Jellyfin user.
    final accounts = message['account'];
    if (accounts is List<Object?>) {
      for (final List<int> key in server.delegate.accountKeys()) {
        final want = expected(key, 'account');
        if (accounts.any((a) => a is String && RemoteAuth.same(want, a))) {
          _trust();
          return;
        }
      }
    }

    // Anyone else meets the PIN. One at a time: two codes on a television
    // at once would leave the viewer guessing which to read out.
    if (server._pairing != null) {
      await close();
      return;
    }
    pin = RemoteProtocol.newPin();
    server._setPairing(this);
    _sendType(RemoteProtocol.pairRequired);
  }

  Future<void> _onPair(Map<String, Object?> message) async {
    final code = pin;
    final theirs = message['mac'];
    if (code == null || phoneNonce == null || theirs is! String) return;

    final want = RemoteAuth.proof(
      key: RemoteAuth.pinKey(code),
      purpose: 'pair',
      receiverNonce: nonce,
      phoneNonce: phoneNonce!,
      receiverId: server.id,
      phoneId: phoneId,
    );
    if (!RemoteAuth.same(want, theirs)) {
      triesLeft--;
      _sendType(RemoteProtocol.pairFailed, <String, Object?>{'triesLeft': triesLeft});
      if (triesLeft <= 0) await close();
      return;
    }

    await server.trust.addPhone(
      RemotePeer(
        id: phoneId,
        name: phoneName,
        secret: RemoteAuth.pairedSecret(code, nonce, phoneNonce!),
      ),
    );
    pin = null;
    server._setPairing(null);
    _sendType(RemoteProtocol.paired);
    _trust();
  }

  void _trust() {
    trusted = true;
    _handshakeTimer?.cancel();
    _sendType(RemoteProtocol.welcome, <String, Object?>{'name': server.name});
    send(RemoteProtocol.encode(server._snapshot.toJson()));
    server._controllersChanged();
  }

  void _onDone() {
    _handshakeTimer?.cancel();
    if (_closed) return; // [close] has already told the server.
    _closed = true;
    server._closed(this);
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _handshakeTimer?.cancel();
    // Before the close handshake, not after it: the PIN has to leave the
    // screen the moment the pairing is over, not once the phone has
    // acknowledged — which a phone that walked away never does.
    server._closed(this);
    try {
      await socket.close();
    } catch (_) {
      // Already gone.
    }
  }
}
