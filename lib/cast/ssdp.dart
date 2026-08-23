// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

/// SSDP — how UPnP devices are found.
///
/// A multicast question goes out and every device that matches answers
/// directly with a set of HTTP-shaped headers. The two that matter are
/// `LOCATION`, which points at the device description, and `USN`, which
/// identifies the device well enough to recognise it in a later search.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

const ssdpAddress = '239.255.255.250';
const ssdpPort = 1900;

/// Media renderers: televisions, AV receivers, and software like Kodi.
const mediaRendererTarget = 'urn:schemas-upnp-org:device:MediaRenderer:1';

@immutable
class SsdpResponse {
  const SsdpResponse({required this.location, required this.usn, this.server});

  /// Where the device description XML lives.
  final Uri location;

  /// Unique Service Name — the device's identity across searches.
  final String usn;

  /// A free-text product string, sometimes the only clue to a make.
  final String? server;
}

/// Parses one datagram, or null if it is not an answer worth keeping.
///
/// SSDP is HTTP-like but not HTTP: header order is arbitrary, case varies by
/// vendor, and plenty of devices send a `NOTIFY` nobody asked for. Only a
/// response carrying both a usable LOCATION and a USN is of any use here.
SsdpResponse? parseSsdpResponse(String datagram) {
  final lines = const LineSplitter().convert(datagram);
  if (lines.isEmpty) return null;

  // A search answer starts with a status line; a NOTIFY advertisement does
  // not, and acting on those would list devices that never answered us.
  if (!lines.first.toUpperCase().startsWith('HTTP/1.1 200')) return null;

  final headers = <String, String>{};
  for (final String line in lines.skip(1)) {
    final colon = line.indexOf(':');
    if (colon <= 0) continue;
    headers[line.substring(0, colon).trim().toUpperCase()] =
        line.substring(colon + 1).trim();
  }

  final location = headers['LOCATION'];
  final usn = headers['USN'];
  if (location == null || usn == null || usn.isEmpty) return null;

  final uri = Uri.tryParse(location);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;

  return SsdpResponse(location: uri, usn: usn, server: headers['SERVER']);
}

/// The M-SEARCH datagram.
///
/// `MX` is the number of seconds a device may wait before answering, which it
/// uses to spread replies out; it has to be smaller than the time spent
/// listening or the slowest devices are missed.
String searchRequest({
  String target = mediaRendererTarget,
  int maxWaitSeconds = 2,
}) {
  // CRLF, and the trailing blank line, are both required — a device that
  // parses strictly drops anything else.
  return 'M-SEARCH * HTTP/1.1\r\n'
      'HOST: $ssdpAddress:$ssdpPort\r\n'
      'MAN: "ssdp:discover"\r\n'
      'MX: $maxWaitSeconds\r\n'
      'ST: $target\r\n'
      '\r\n';
}

/// Asks the network for renderers and collects what answers.
///
/// Every response is returned, including duplicates: a device answers once
/// per interface it hears the question on, and deciding which are the same
/// device belongs with whatever is keeping the list.
Future<List<SsdpResponse>> discover({
  Duration timeout = const Duration(seconds: 3),
  String target = mediaRendererTarget,
}) async {
  final found = <SsdpResponse>[];
  RawDatagramSocket? socket;

  try {
    socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    socket.broadcastEnabled = true;
    // Two hops: far enough to cross a mesh extender, not far enough to leave
    // the house.
    socket.multicastHops = 2;

    final completer = Completer<void>();
    socket.listen((event) {
      if (event != RawSocketEvent.read) return;

      final datagram = socket?.receive();
      if (datagram == null) return;

      // A device with a mangled reply must not take down the search.
      final response = runZonedGuarded(
        () => parseSsdpResponse(utf8.decode(datagram.data, allowMalformed: true)),
        (Object e, StackTrace _) => debugPrint('Unreadable SSDP reply: $e'),
      );
      if (response != null) found.add(response);
    }, onDone: () {
      if (!completer.isCompleted) completer.complete();
    });

    final message = utf8.encode(searchRequest(target: target));
    final destination = InternetAddress(ssdpAddress);

    // Sent more than once on purpose: SSDP is UDP over multicast, where a
    // dropped datagram is normal and silently costs the user a device.
    for (var i = 0; i < 3; i++) {
      socket.send(message, destination, ssdpPort);
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }

    await Future.any(<Future<void>>[
      completer.future,
      Future<void>.delayed(timeout),
    ]);
  } on SocketException catch (e) {
    // No network, or a platform that refuses multicast. An empty list reads
    // in the UI as "nothing found", which is the truth from here.
    debugPrint('SSDP search failed: $e');
  } finally {
    socket?.close();
  }

  return found;
}
