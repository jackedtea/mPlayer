// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mplayer/remote/remote_client.dart';
import 'package:mplayer/remote/remote_protocol.dart';
import 'package:mplayer/remote/remote_server.dart';
import 'package:mplayer/remote/remote_trust.dart';

import 'fake_keychain.dart';

class _Receiver implements RemoteReceiverDelegate {
  _Receiver({this.keys = const <List<int>>[]});

  final List<List<int>> keys;
  final List<RemoteCommand> commands = <RemoteCommand>[];
  RemotePairing? pairing;
  List<String> controllers = const <String>[];

  @override
  List<List<int>> accountKeys() => keys;

  @override
  Future<(RemoteErrorCode, String?)?> handle(RemoteCommand command) async {
    commands.add(command);
    if (command.kind == RemoteCommandKind.playItem) {
      return (RemoteErrorCode.wrongServer, null);
    }
    return null;
  }

  @override
  void showPairing(RemotePairing? pairing) => this.pairing = pairing;

  @override
  void controllersChanged(List<String> names) => controllers = names;
}

/// Waits for the first event of type [T], failing after a few seconds rather
/// than hanging the suite.
Future<T> _next<T extends RemoteEvent>(Stream<RemoteEvent> events) async =>
    await events.firstWhere((e) => e is T).timeout(const Duration(seconds: 5))
        as T;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('protocol', () {
    test('a beacon survives the round trip, addressed from the datagram', () {
      const device = RemoteDevice(
        id: 'abc',
        name: 'Living room',
        kind: RemoteDeviceKind.television,
        host: 'ignored',
        port: 47831,
      );
      final bytes = utf8.encode(jsonEncode(device.toBeacon()));
      final parsed = RemoteDevice.fromBeacon(bytes, '192.168.1.9');

      expect(parsed, isNotNull);
      expect(parsed!.id, 'abc');
      expect(parsed.kind, RemoteDeviceKind.television);
      expect(parsed.host, '192.168.1.9');
      expect(parsed.uri.toString(), 'ws://192.168.1.9:47831/remote');
    });

    test('junk and other apps are not beacons', () {
      expect(RemoteDevice.fromBeacon(utf8.encode('not json'), 'h'), isNull);
      expect(
        RemoteDevice.fromBeacon(
          utf8.encode(jsonEncode(<String, Object?>{'app': 'plezy', 'id': 'x', 'port': 1})),
          'h',
        ),
        isNull,
      );
      expect(RemoteDevice.isQuery(RemoteDevice.queryDatagram()), isTrue);
      expect(RemoteDevice.isQuery(utf8.encode('{}')), isFalse);
    });

    test('a snapshot survives the round trip', () {
      const snapshot = RemoteSnapshot(
        title: 'Dune',
        subtitle: 'S1 · E2',
        itemId: 'i',
        serverId: 's',
        position: Duration(seconds: 61),
        duration: Duration(minutes: 90),
        playing: true,
        volume: 42,
        hasNext: true,
        audioTracks: <RemoteTrack>[RemoteTrack(id: '1', label: 'English')],
        subtitleTracks: <RemoteTrack>[RemoteTrack(id: '3', label: 'Tiếng Việt')],
        activeAudio: '1',
        activeSubtitle: 'no',
        skipForward: Duration(seconds: 30),
      );
      final back = RemoteSnapshot.fromJson(
        RemoteProtocol.decode(RemoteProtocol.encode(snapshot.toJson()))!,
      );

      expect(back.sameApartFromPosition(snapshot), isTrue);
      expect(back.position, snapshot.position);
      expect(back.hasMedia, isTrue);
      expect(const RemoteSnapshot().hasMedia, isFalse);
    });

    test('a position tick alone is not a change worth sending at once', () {
      const a = RemoteSnapshot(title: 'x', position: Duration(seconds: 1));
      const b = RemoteSnapshot(title: 'x', position: Duration(seconds: 2));
      const c = RemoteSnapshot(title: 'x', playing: true);
      expect(a.sameApartFromPosition(b), isTrue);
      expect(a.sameApartFromPosition(c), isFalse);
    });

    test('a command missing what its kind needs is refused', () {
      RemoteCommand? parse(Map<String, Object?> m) =>
          RemoteCommand.fromJson(<String, Object?>{'t': 'cmd', ...m});

      expect(parse(<String, Object?>{'c': 'seek'}), isNull);
      expect(parse(<String, Object?>{'c': 'seek', 'ms': 5000})!.at,
          const Duration(seconds: 5));
      expect(parse(<String, Object?>{'c': 'playItem', 'itemId': 'i'}), isNull);
      expect(parse(<String, Object?>{'c': 'rm -rf'}), isNull);
      // Subtitles off is a subtitle command with no track, and complete.
      expect(parse(<String, Object?>{'c': 'subtitle'})!.trackId, isNull);
    });

    test('a proof is bound to its purpose, its nonces and both ids', () {
      final key = RemoteAuth.accountKey('Server', 'User');
      String proof({
        String purpose = 'account',
        List<int> r = const <int>[1],
        String phone = 'p',
      }) =>
          RemoteAuth.proof(
            key: key,
            purpose: purpose,
            receiverNonce: r,
            phoneNonce: const <int>[2],
            receiverId: 'r',
            phoneId: phone,
          );

      expect(proof(), proof());
      expect(proof(), isNot(proof(purpose: 'paired')));
      expect(proof(), isNot(proof(r: const <int>[9])));
      expect(proof(), isNot(proof(phone: 'q')));
      // Ids are compared case-insensitively — a server reports them in
      // whichever case it likes.
      expect(RemoteAuth.accountKey('server', 'user'), key);
    });

    test('a PIN is six digits, leading zeros included', () {
      for (var i = 0; i < 50; i++) {
        expect(RemoteProtocol.newPin(), matches(RegExp(r'^\d{6}$')));
      }
    });
  });

  group('server and client over loopback', () {
    late RemoteServer server;
    late _Receiver receiver;
    late RemoteTrustStore trust;
    final clients = <RemoteClient>[];

    setUpAll(() {
      // The test binding answers every HTTP request with a 400, the
      // WebSocket upgrade included; these tests want the real thing.
      HttpOverrides.global = null;
    });

    Future<void> start(_Receiver r) async {
      installFakeKeychain();
      trust = RemoteTrustStore();
      receiver = r;
      server = RemoteServer(
        id: 'receiver-1',
        name: 'Desk',
        delegate: receiver,
        trust: trust,
      );
      await server.start();
    }

    RemoteClient client({List<List<int>> keys = const <List<int>>[]}) {
      final c = RemoteClient(
        device: RemoteDevice(
          id: 'receiver-1',
          name: 'Desk',
          kind: RemoteDeviceKind.desktop,
          host: InternetAddress.loopbackIPv4.address,
          port: server.port!,
        ),
        phoneId: 'phone-1',
        phoneName: 'Pixel',
        accountKeys: keys,
        trust: trust,
      );
      clients.add(c);
      return c;
    }

    tearDown(() async {
      for (final RemoteClient c in clients) {
        await c.close();
      }
      clients.clear();
      await server.stop();
    });

    test('the same Jellyfin user is let in without a PIN', () async {
      final key = RemoteAuth.accountKey('srv', 'usr');
      await start(_Receiver(keys: <List<int>>[key]));
      server.publish(const RemoteSnapshot(title: 'Dune', playing: true));

      final phone = client(keys: <List<int>>[key]);
      final welcomed = _next<RemoteWelcomed>(phone.events);
      final state = _next<RemoteStateChanged>(phone.events);
      await phone.connect();
      await welcomed;
      expect((await state).snapshot.title, 'Dune');
      expect(receiver.pairing, isNull);

      final failed = _next<RemoteFailed>(phone.events);
      phone
        ..send(const RemoteCommand(RemoteCommandKind.seek, at: Duration(seconds: 7)))
        ..send(const RemoteCommand(
          RemoteCommandKind.playItem,
          serverId: 'other',
          itemId: 'i',
        ));
      expect((await failed).code, RemoteErrorCode.wrongServer);
      expect(receiver.commands.first.at, const Duration(seconds: 7));
      expect(receiver.controllers, <String>['Pixel']);
    });

    test('anyone else pairs with the PIN, once', () async {
      await start(_Receiver(keys: <List<int>>[RemoteAuth.accountKey('a', 'b')]));

      // A different account: its proof matches nothing on the receiver.
      final phone = client(keys: <List<int>>[RemoteAuth.accountKey('a', 'c')]);
      final asked = _next<RemotePinRequested>(phone.events);
      await phone.connect();
      expect((await asked).triesLeft, isNull);
      final pin = receiver.pairing!.pin;
      expect(receiver.pairing!.phoneName, 'Pixel');

      // Commands before trust are ignored, not obeyed.
      phone.send(const RemoteCommand(RemoteCommandKind.stop));

      final retry = _next<RemotePinRequested>(phone.events);
      phone.sendPin(pin == '000000' ? '111111' : '000000');
      expect((await retry).triesLeft, RemoteProtocol.pinTries - 1);

      final welcomed = _next<RemoteWelcomed>(phone.events);
      phone.sendPin(pin);
      await welcomed;
      expect(receiver.pairing, isNull);
      expect(receiver.commands, isEmpty);
      expect((await trust.phones()).keys, <String>['phone-1']);

      await phone.close();
      // The pairing is stored on both ends, so the next connection needs no
      // code at all.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect((await trust.receivers()).keys, <String>['receiver-1']);
      final again = client();
      final back = _next<RemoteWelcomed>(again.events);
      await again.connect();
      await back;
      expect(receiver.pairing, isNull);
    });

    test('too many wrong PINs hang up', () async {
      await start(_Receiver());
      final phone = client();
      final asked = _next<RemotePinRequested>(phone.events);
      await phone.connect();
      await asked;
      final pin = receiver.pairing!.pin;
      final wrong = pin == '000000' ? '111111' : '000000';

      final closed = _next<RemoteClosed>(phone.events);
      for (var i = 0; i < RemoteProtocol.pinTries; i++) {
        phone.sendPin(wrong);
      }
      await closed;
      expect(receiver.pairing, isNull);
      expect(await trust.phones(), isEmpty);
    });
  });
}
