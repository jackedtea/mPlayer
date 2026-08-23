// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

/// Reading what a UPnP device says about itself, and speaking SOAP back.
///
/// Element names are matched **locally**, the way `WebDavSource` matches
/// PROPFIND: every vendor namespaces its description differently and some
/// prefix nothing at all, so a prefixed lookup finds a device on one
/// television and nothing on the next.
library;

import 'package:flutter/foundation.dart';
import 'package:xml/xml.dart';

const avTransport = 'urn:schemas-upnp-org:service:AVTransport:1';
const renderingControl = 'urn:schemas-upnp-org:service:RenderingControl:1';

@immutable
class UpnpDevice {
  const UpnpDevice({
    required this.friendlyName,
    required this.controlUrl,
    this.modelName,
    this.manufacturer,
  });

  final String friendlyName;

  /// Absolute AVTransport control URL — the address every transport command
  /// is posted to.
  final Uri controlUrl;

  final String? modelName;
  final String? manufacturer;
}

/// Reads a device description, or returns null when it describes nothing this
/// app can drive.
///
/// [base] is the URL the description was fetched from; control URLs in the
/// document are routinely relative to it, and a few vendors give a `URLBase`
/// element instead, which wins where it exists.
UpnpDevice? parseDeviceDescription(String xml, Uri base) {
  final XmlDocument document;
  try {
    document = XmlDocument.parse(xml);
  } on XmlException catch (e) {
    debugPrint('Unreadable device description: $e');
    return null;
  }

  final root = document.rootElement;
  final urlBase = _text(root, 'URLBase');
  final resolveAgainst = urlBase == null || urlBase.trim().isEmpty
      ? base
      : Uri.tryParse(urlBase.trim()) ?? base;

  // A media renderer is a device with an AVTransport service. Some
  // televisions publish several devices in one description, so the search is
  // over every service in the document rather than the root device's list.
  final service = root.descendantElements
      .where((e) => e.localName == 'service')
      .where((s) => _text(s, 'serviceType')?.trim() == avTransport)
      .firstOrNull;
  if (service == null) return null;

  final controlPath = _text(service, 'controlURL')?.trim();
  if (controlPath == null || controlPath.isEmpty) return null;

  final control = resolveAgainst.resolve(controlPath);

  final name = _text(root, 'friendlyName')?.trim();

  return UpnpDevice(
    // A device with no name is still castable; showing its address beats
    // dropping it from the list.
    friendlyName: name == null || name.isEmpty ? control.host : name,
    controlUrl: control,
    modelName: _text(root, 'modelName')?.trim(),
    manufacturer: _text(root, 'manufacturer')?.trim(),
  );
}

/// First descendant with this local name, whatever its prefix.
String? _text(XmlNode node, String localName) {
  return node.descendantElements
      .where((e) => e.localName == localName)
      .firstOrNull
      ?.innerText;
}

/// Wraps one action in a SOAP envelope.
///
/// Argument order matters: UPnP actions are positional despite looking like
/// named parameters, and a device is free to reject an envelope whose
/// arguments arrive in the wrong order.
String soapEnvelope(
  String service,
  String action,
  List<(String, String)> arguments,
) {
  final body = StringBuffer();
  for (final (String name, String value) in arguments) {
    body.write('<$name>${escapeXml(value)}</$name>');
  }

  return '<?xml version="1.0" encoding="utf-8"?>'
      '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" '
      's:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">'
      '<s:Body>'
      '<u:$action xmlns:u="$service">$body</u:$action>'
      '</s:Body>'
      '</s:Envelope>';
}

/// The value of one element in a SOAP reply, or null.
String? soapValue(String xml, String localName) {
  try {
    return _text(XmlDocument.parse(xml), localName);
  } on XmlException {
    return null;
  }
}

/// The human-readable half of a SOAP fault, if the reply is one.
String? soapFault(String xml) {
  final description = soapValue(xml, 'errorDescription');
  if (description != null && description.isNotEmpty) return description;

  final string = soapValue(xml, 'faultstring');
  if (string != null && string.isNotEmpty) return string;

  return null;
}

/// `H:MM:SS`, which is the only time format UPnP transports agree on.
String formatUpnpTime(Duration time) {
  final total = time.isNegative ? Duration.zero : time;
  final hours = total.inHours;
  final minutes = total.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = total.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$hours:$minutes:$seconds';
}

/// Reads `H:MM:SS`, `HH:MM:SS.mmm` and the `NOT_IMPLEMENTED` a device sends
/// when it has no answer.
Duration? parseUpnpTime(String? raw) {
  final text = raw?.trim();
  if (text == null || text.isEmpty) return null;
  if (text.toUpperCase().contains('NOT_IMPLEMENTED')) return null;

  final parts = text.split(':');
  if (parts.length != 3) return null;

  final hours = int.tryParse(parts[0]);
  final minutes = int.tryParse(parts[1]);
  // Fractional seconds are legal and are dropped: nothing here needs better
  // than a second, and a device that sends "10.500" must not parse as null.
  final seconds = double.tryParse(parts[2]);
  if (hours == null || minutes == null || seconds == null) return null;

  return Duration(
    hours: hours,
    minutes: minutes,
    seconds: seconds.floor(),
  );
}

/// The metadata blob that rides along with the URL.
///
/// Optional by the specification and required in practice: a good number of
/// televisions show "Unknown" or refuse the stream outright without a
/// `DIDL-Lite` item describing it. It is escaped again by [soapEnvelope],
/// since it travels as the *text* of an argument, not as markup.
String didlMetadata({
  required String title,
  required Uri url,
  String contentType = 'video/mp4',
}) {
  return '<DIDL-Lite '
      'xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/" '
      'xmlns:dc="http://purl.org/dc/elements/1.1/" '
      'xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/">'
      '<item id="0" parentID="-1" restricted="1">'
      '<dc:title>${escapeXml(title)}</dc:title>'
      '<upnp:class>object.item.videoItem</upnp:class>'
      // DLNA.ORG_OP=01 says the file may be seeked by byte range, which is
      // what turns the television's scrubber on.
      '<res protocolInfo="http-get:*:$contentType:DLNA.ORG_OP=01">'
      '${escapeXml(url.toString())}'
      '</res>'
      '</item>'
      '</DIDL-Lite>';
}

/// Escapes the five characters XML reserves.
String escapeXml(String raw) => raw
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');
