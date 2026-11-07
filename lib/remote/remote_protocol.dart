// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// The wire format of the phone remote, and the proofs its handshake trades.
///
/// Pure: nothing here opens a socket, so the whole protocol — beacons,
/// handshake, commands, state — is tested without a network, the same split
/// `jellyfin_dto.dart` keeps from the client that speaks it.
///
/// Every message is one JSON object with a `t` naming it. The receiver
/// speaks first:
///
/// ```text
/// receiver → hello {id, name, nonce}
/// phone    → auth  {id, name, nonce, account: [mac…], paired: mac?}
/// receiver → welcome                 (trusted: same account, or paired)
///          | pairRequired            (a PIN is now on the receiver's screen)
/// phone    → pair {mac}              (keyed with the PIN typed in)
/// receiver → paired → welcome | pairFailed {triesLeft}
/// …then
/// receiver → state {…}               (whenever what is playing changes)
/// phone    → cmd {c, …}
/// receiver → error {code, message?}  (a command that could not be done)
/// ```
abstract final class RemoteProtocol {
  /// Bumped when a message changes shape. A peer on another version is told
  /// so in words rather than half-working.
  static const version = 1;

  /// UDP: beacons from receivers, and the phone's "who is there?".
  static const discoveryPort = 47830;

  /// TCP: the receiver's WebSocket. Preferred, not required — taken by
  /// something else, the receiver binds any port and its beacon says which.
  static const preferredPort = 47831;

  static const path = '/remote';

  /// Identifies this app's datagrams among whatever else shares the port.
  static const app = 'mplayer-remote';

  // Message types.
  static const hello = 'hello';
  static const auth = 'auth';
  static const welcome = 'welcome';
  static const pairRequired = 'pairRequired';
  static const pair = 'pair';
  static const paired = 'paired';
  static const pairFailed = 'pairFailed';
  static const state = 'state';
  static const command = 'cmd';
  static const error = 'error';
  static const beacon = 'beacon';
  static const query = 'query';

  static const nonceBytes = 16;
  static const pinDigits = 6;

  /// Wrong PINs before the receiver hangs up and the phone has to start over
  /// with a fresh code — six digits are a million guesses, not five.
  static const pinTries = 5;

  /// A message larger than this is not one of ours. State with a few dozen
  /// tracks is a couple of kilobytes.
  static const maxMessageBytes = 64 * 1024;

  static String encode(Map<String, Object?> message) => jsonEncode(message);

  /// Null for anything that is not a JSON object carrying a type.
  static Map<String, Object?>? decode(Object? raw) {
    if (raw is! String || raw.length > maxMessageBytes) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?>) return null;
      return decoded['t'] is String ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  static List<int> newNonce([Random? random]) {
    final r = random ?? Random.secure();
    return List<int>.generate(nonceBytes, (_) => r.nextInt(256));
  }

  /// A PIN of [pinDigits] digits, leading zeros kept.
  static String newPin([Random? random]) {
    final r = random ?? Random.secure();
    return List<String>.generate(pinDigits, (_) => '${r.nextInt(10)}').join();
  }
}

/// Which way a [RemoteDevice] can be controlled from, for its icon.
enum RemoteDeviceKind {
  desktop,
  television;

  static RemoteDeviceKind parse(Object? raw) =>
      raw == 'tv' ? RemoteDeviceKind.television : RemoteDeviceKind.desktop;

  String get wire => this == RemoteDeviceKind.television ? 'tv' : 'desktop';
}

/// A receiver as its beacon describes it.
@immutable
class RemoteDevice {
  const RemoteDevice({
    required this.id,
    required this.name,
    required this.kind,
    required this.host,
    required this.port,
    this.version = RemoteProtocol.version,
  });

  /// Stable per installation; what a pairing is filed under.
  final String id;
  final String name;
  final RemoteDeviceKind kind;

  /// Where the datagram came from — not an address the receiver claimed, so
  /// a beacon cannot point the phone at somebody else's machine.
  final String host;
  final int port;
  final int version;

  Uri get uri => Uri(scheme: 'ws', host: host, port: port, path: RemoteProtocol.path);

  Map<String, Object?> toBeacon() => <String, Object?>{
        'app': RemoteProtocol.app,
        't': RemoteProtocol.beacon,
        'v': version,
        'id': id,
        'name': name,
        'kind': kind.wire,
        'port': port,
      };

  /// Null for anything that is not a well-formed beacon from this app.
  static RemoteDevice? fromBeacon(List<int> datagram, String host) {
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(datagram));
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, Object?>) return null;
    if (decoded['app'] != RemoteProtocol.app ||
        decoded['t'] != RemoteProtocol.beacon) {
      return null;
    }
    final id = decoded['id'];
    final port = decoded['port'];
    if (id is! String || id.isEmpty || port is! int || port <= 0) return null;
    final name = decoded['name'];
    final version = decoded['v'];
    return RemoteDevice(
      id: id,
      name: name is String && name.isNotEmpty ? name : host,
      kind: RemoteDeviceKind.parse(decoded['kind']),
      host: host,
      port: port,
      version: version is int ? version : 0,
    );
  }

  static List<int> queryDatagram() => utf8.encode(
        jsonEncode(<String, Object?>{
          'app': RemoteProtocol.app,
          't': RemoteProtocol.query,
          'v': RemoteProtocol.version,
        }),
      );

  static bool isQuery(List<int> datagram) {
    try {
      final decoded = jsonDecode(utf8.decode(datagram));
      return decoded is Map<String, Object?> &&
          decoded['app'] == RemoteProtocol.app &&
          decoded['t'] == RemoteProtocol.query;
    } on FormatException {
      return false;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is RemoteDevice &&
      other.id == id &&
      other.name == name &&
      other.kind == kind &&
      other.host == host &&
      other.port == port &&
      other.version == version;

  @override
  int get hashCode => Object.hash(id, name, kind, host, port, version);
}

/// The proofs the handshake trades. Every one is an HMAC over the same
/// transcript — both nonces and both ids — under a different key, so a proof
/// recorded on one connection is worthless on the next.
abstract final class RemoteAuth {
  /// The key two installations signed in to the same Jellyfin user share.
  ///
  /// **This is the weak half of the trust model, and knowingly so.** A
  /// server id and a user id are not secrets: any account on the same server
  /// can read both. What it buys is that two devices one person signed in
  /// themselves need no PIN; anyone who is not that user still meets the PIN.
  /// The same trade `refs/plezy`'s companion remote makes.
  static List<int> accountKey(String serverId, String userId) =>
      sha256.convert(
        utf8.encode(
          'mplayer-remote-account-v1|'
          '${serverId.toLowerCase()}|${userId.toLowerCase()}',
        ),
      ).bytes;

  /// The key a PIN stands for while pairing.
  static List<int> pinKey(String pin) =>
      sha256.convert(utf8.encode('mplayer-remote-pin-v1|$pin')).bytes;

  /// What both sides keep after a successful pairing. Derived on each side
  /// rather than sent, so it never crosses the network.
  static List<int> pairedSecret(
    String pin,
    List<int> receiverNonce,
    List<int> phoneNonce,
  ) =>
      Hmac(sha256, pinKey(pin))
          .convert(<int>[
            ...utf8.encode('mplayer-remote-secret-v1|'),
            ...receiverNonce,
            ...phoneNonce,
          ])
          .bytes;

  static String proof({
    required List<int> key,
    required String purpose,
    required List<int> receiverNonce,
    required List<int> phoneNonce,
    required String receiverId,
    required String phoneId,
  }) {
    final transcript = BytesBuilder(copy: false)
      ..add(utf8.encode('mplayer-remote-$purpose-v1|'))
      ..add(receiverNonce)
      ..add(phoneNonce);
    // Length-prefixed, so "ab"+"c" and "a"+"bc" cannot sign the same bytes.
    for (final String field in <String>[receiverId, phoneId]) {
      final bytes = utf8.encode(field);
      transcript
        ..add(<int>[
          (bytes.length >> 24) & 0xff,
          (bytes.length >> 16) & 0xff,
          (bytes.length >> 8) & 0xff,
          bytes.length & 0xff,
        ])
        ..add(bytes);
    }
    return base64Encode(Hmac(sha256, key).convert(transcript.takeBytes()).bytes);
  }

  /// Constant-time, so a wrong proof costs the same however close it was.
  static bool same(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}

/// One audio or subtitle stream, as the phone's picker lists it.
@immutable
class RemoteTrack {
  const RemoteTrack({required this.id, required this.label});

  final String id;
  final String label;

  bool get isOff => id == 'no';
  bool get isAuto => id == 'auto';

  Map<String, Object?> toJson() => <String, Object?>{'id': id, 'label': label};

  static RemoteTrack? fromJson(Object? raw) {
    if (raw is! Map<String, Object?>) return null;
    final id = raw['id'];
    final label = raw['label'];
    if (id is! String) return null;
    return RemoteTrack(id: id, label: label is String ? label : id);
  }

  @override
  bool operator ==(Object other) =>
      other is RemoteTrack && other.id == id && other.label == label;

  @override
  int get hashCode => Object.hash(id, label);
}

/// What a receiver is playing, as much of it as a remote needs.
///
/// Deliberately not `PlaybackState`: that type carries the decoder's log, its
/// stats and a resolved stream URL with a token in it, none of which is any
/// business of a phone across the room.
@immutable
class RemoteSnapshot {
  const RemoteSnapshot({
    this.title,
    this.subtitle,
    this.itemId,
    this.serverId,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.playing = false,
    this.buffering = false,
    this.volume = 100,
    this.hasPrevious = false,
    this.hasNext = false,
    this.audioTracks = const <RemoteTrack>[],
    this.subtitleTracks = const <RemoteTrack>[],
    this.activeAudio,
    this.activeSubtitle,
    this.skipBack = const Duration(seconds: 10),
    this.skipForward = const Duration(seconds: 10),
    this.error,
    this.artist,
    this.album,
    this.queueIndex = 0,
    this.queueLength = 0,
  });

  /// Null while nothing is open on the receiver.
  final String? title;
  final String? subtitle;

  /// The item and the server it came from, so a phone signed in to the same
  /// server can draw its artwork with its own token.
  final String? itemId;
  final String? serverId;

  final Duration position;
  final Duration duration;
  final bool playing;
  final bool buffering;

  /// 0–100.
  final double volume;
  final bool hasPrevious;
  final bool hasNext;
  final List<RemoteTrack> audioTracks;
  final List<RemoteTrack> subtitleTracks;
  final String? activeAudio;
  final String? activeSubtitle;

  /// The receiver's own skip steps, so the phone's ⟲/⟳ buttons say what the
  /// receiver will actually do.
  final Duration skipBack;
  final Duration skipForward;

  /// The player's own error line, if playback failed.
  final String? error;

  /// For a song; null for a video, whose [subtitle] says how it is playing.
  final String? artist;
  final String? album;

  /// Where in its queue this is. A length of 0 or 1 is no queue worth saying.
  final int queueIndex;
  final int queueLength;

  bool get hasMedia => title != null;

  Map<String, Object?> toJson() => <String, Object?>{
        't': RemoteProtocol.state,
        'title': title,
        'subtitle': subtitle,
        'itemId': itemId,
        'serverId': serverId,
        'position': position.inMilliseconds,
        'duration': duration.inMilliseconds,
        'playing': playing,
        'buffering': buffering,
        'volume': volume,
        'hasPrevious': hasPrevious,
        'hasNext': hasNext,
        'artist': artist,
        'album': album,
        'queueIndex': queueIndex,
        'queueLength': queueLength,
        'audio': <Object?>[for (final t in audioTracks) t.toJson()],
        'subtitles': <Object?>[for (final t in subtitleTracks) t.toJson()],
        'activeAudio': activeAudio,
        'activeSubtitle': activeSubtitle,
        'skipBack': skipBack.inMilliseconds,
        'skipForward': skipForward.inMilliseconds,
        'error': error,
      };

  factory RemoteSnapshot.fromJson(Map<String, Object?> json) {
    String? text(String key) => switch (json[key]) {
          final String s when s.isNotEmpty => s,
          _ => null,
        };
    Duration millis(String key, [Duration fallback = Duration.zero]) =>
        switch (json[key]) {
          final num n => Duration(milliseconds: n.round()),
          _ => fallback,
        };
    List<RemoteTrack> tracks(String key) => <RemoteTrack>[
          if (json[key] case final List<Object?> list)
            for (final Object? raw in list)
              if (RemoteTrack.fromJson(raw) case final RemoteTrack t) t,
        ];

    return RemoteSnapshot(
      title: text('title'),
      subtitle: text('subtitle'),
      itemId: text('itemId'),
      serverId: text('serverId'),
      position: millis('position'),
      duration: millis('duration'),
      playing: json['playing'] == true,
      buffering: json['buffering'] == true,
      volume: switch (json['volume']) {
        final num n => n.toDouble().clamp(0, 100).toDouble(),
        _ => 100,
      },
      hasPrevious: json['hasPrevious'] == true,
      hasNext: json['hasNext'] == true,
      artist: text('artist'),
      album: text('album'),
      queueIndex: switch (json['queueIndex']) {
        final int n => n,
        _ => 0,
      },
      queueLength: switch (json['queueLength']) {
        final int n => n,
        _ => 0,
      },
      audioTracks: tracks('audio'),
      subtitleTracks: tracks('subtitles'),
      activeAudio: text('activeAudio'),
      activeSubtitle: text('activeSubtitle'),
      skipBack: millis('skipBack', const Duration(seconds: 10)),
      skipForward: millis('skipForward', const Duration(seconds: 10)),
      error: text('error'),
    );
  }

  /// Equal apart from the position — what decides whether a change is worth
  /// sending at once or can wait for the next position tick.
  bool sameApartFromPosition(RemoteSnapshot other) {
    return title == other.title &&
        subtitle == other.subtitle &&
        itemId == other.itemId &&
        serverId == other.serverId &&
        duration == other.duration &&
        playing == other.playing &&
        buffering == other.buffering &&
        volume == other.volume &&
        hasPrevious == other.hasPrevious &&
        hasNext == other.hasNext &&
        artist == other.artist &&
        album == other.album &&
        queueIndex == other.queueIndex &&
        queueLength == other.queueLength &&
        listEquals(audioTracks, other.audioTracks) &&
        listEquals(subtitleTracks, other.subtitleTracks) &&
        activeAudio == other.activeAudio &&
        activeSubtitle == other.activeSubtitle &&
        skipBack == other.skipBack &&
        skipForward == other.skipForward &&
        error == other.error;
  }
}

/// What a phone can ask a receiver to do.
enum RemoteCommandKind {
  playPause,
  play,
  pause,
  seek,
  skip,
  next,
  previous,
  volume,
  audio,
  subtitle,
  stop,
  playItem;

  static RemoteCommandKind? parse(Object? raw) {
    for (final RemoteCommandKind k in values) {
      if (k.name == raw) return k;
    }
    return null;
  }
}

/// One command, with whichever arguments its kind takes.
@immutable
class RemoteCommand {
  const RemoteCommand(
    this.kind, {
    this.at,
    this.volume,
    this.trackId,
    this.serverId,
    this.itemId,
    this.fromStart = false,
    this.queueIds = const <String>[],
    this.queueTitles = const <String>[],
    this.queueIndex = 0,
  });

  /// "Play this list", from the item at [index].
  ///
  /// [items] are (id, title). Long queues are cut to a window around [index]:
  /// a message has a size limit, and what is near the current song is what
  /// anyone gets to before queuing something else. Titles go too, or the
  /// receiver's queue would be a list of blanks until each song was reached.
  factory RemoteCommand.playQueue({
    required String serverId,
    required List<(String, String)> items,
    required int index,
  }) {
    final first = (index - 50).clamp(0, items.length);
    final window = items.skip(first).take(maxQueueItems).toList();
    return RemoteCommand(
      RemoteCommandKind.playItem,
      serverId: serverId,
      itemId: items[index].$1,
      queueIds: <String>[for (final (String id, String _) in window) id],
      queueTitles: <String>[
        for (final (String _, String title) in window)
          title.length > 80 ? title.substring(0, 80) : title,
      ],
      queueIndex: index - first,
    );
  }

  /// Fits [RemoteProtocol.maxMessageBytes] with room to spare, at 32 characters
  /// an id and 80 a title.
  static const maxQueueItems = 300;

  final RemoteCommandKind kind;

  /// [RemoteCommandKind.playItem]: what follows, with [itemId] at [queueIndex].
  /// Empty plays the item alone. A receiver that predates these reads [itemId]
  /// and plays that, which is still the song that was asked for.
  final List<String> queueIds;
  final List<String> queueTitles;
  final int queueIndex;

  /// [RemoteCommandKind.seek]'s target, or [RemoteCommandKind.skip]'s delta.
  final Duration? at;
  final double? volume;

  /// A track id; null with [RemoteCommandKind.subtitle] turns subtitles off.
  final String? trackId;

  /// [RemoteCommandKind.playItem]: which server's item. The receiver resolves
  /// it itself, signed in as itself — nothing with a token in it travels.
  final String? serverId;
  final String? itemId;
  final bool fromStart;

  Map<String, Object?> toJson() => <String, Object?>{
        't': RemoteProtocol.command,
        'c': kind.name,
        if (at != null) 'ms': at!.inMilliseconds,
        if (volume != null) 'volume': volume,
        if (trackId != null) 'track': trackId,
        if (serverId != null) 'serverId': serverId,
        if (itemId != null) 'itemId': itemId,
        if (fromStart) 'fromStart': true,
        if (queueIds.isNotEmpty) ...<String, Object?>{
          'queueIds': queueIds,
          'queueTitles': queueTitles,
          'queueIndex': queueIndex,
        },
      };

  /// Null for an unknown command, or one missing what its kind needs.
  static RemoteCommand? fromJson(Map<String, Object?> json) {
    final kind = RemoteCommandKind.parse(json['c']);
    if (kind == null) return null;
    final ms = json['ms'];
    final at = ms is num ? Duration(milliseconds: ms.round()) : null;
    final volume = json['volume'];
    final track = json['track'];
    final serverId = json['serverId'];
    final itemId = json['itemId'];
    final queueIds = _strings(json['queueIds']);
    final queueTitles = _strings(json['queueTitles']);
    final queueIndex = json['queueIndex'];
    // A queue that does not line up is dropped, and the one item plays.
    final queueFits =
        queueTitles.length == queueIds.length &&
        queueIndex is int &&
        queueIndex >= 0 &&
        queueIndex < queueIds.length &&
        queueIds[queueIndex] == itemId;

    final command = RemoteCommand(
      kind,
      at: at,
      volume: volume is num ? volume.toDouble() : null,
      trackId: track is String ? track : null,
      serverId: serverId is String ? serverId : null,
      itemId: itemId is String ? itemId : null,
      fromStart: json['fromStart'] == true,
      queueIds: queueFits ? queueIds : const <String>[],
      queueTitles: queueFits ? queueTitles : const <String>[],
      queueIndex: queueFits ? queueIndex : 0,
    );

    final complete = switch (kind) {
      RemoteCommandKind.seek || RemoteCommandKind.skip => at != null,
      RemoteCommandKind.volume => command.volume != null,
      RemoteCommandKind.audio => command.trackId != null,
      RemoteCommandKind.playItem =>
        command.serverId != null && command.itemId != null,
      _ => true,
    };
    return complete ? command : null;
  }

  static List<String> _strings(Object? raw) =>
      raw is List ? raw.whereType<String>().toList() : const <String>[];
}

/// Why a receiver could not do what it was asked. The phone turns each into
/// a sentence in its own language.
enum RemoteErrorCode {
  /// The receiver is not signed in to the server the item came from.
  wrongServer,

  /// The receiver's server is behind a PIN nobody has entered there yet.
  locked,

  /// The server refused to resolve the item; `message` carries its sentence.
  playFailed,

  /// The phone speaks another protocol version.
  version;

  static RemoteErrorCode? parse(Object? raw) {
    for (final RemoteErrorCode c in values) {
      if (c.name == raw) return c;
    }
    return null;
  }
}
