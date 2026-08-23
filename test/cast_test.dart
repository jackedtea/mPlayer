// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter_test/flutter_test.dart';

import 'package:mplayer/cast/ssdp.dart';
import 'package:mplayer/cast/upnp.dart';
import 'package:mplayer/features/cast/cast_controller.dart';

/// A real Samsung reply, reordered and re-cased the way vendors vary.
const _searchReply = 'HTTP/1.1 200 OK\r\n'
    'CACHE-CONTROL: max-age=1800\r\n'
    'Ext: \r\n'
    'location: http://192.168.1.42:9197/dmr\r\n'
    'SERVER: Linux/9.0 UPnP/1.0 Samsung/1.0\r\n'
    'ST: urn:schemas-upnp-org:device:MediaRenderer:1\r\n'
    'USN: uuid:0d1e2f30-1111-2222-3333-444455556666::'
    'urn:schemas-upnp-org:device:MediaRenderer:1\r\n'
    '\r\n';

/// A device announcing itself unprompted. Not an answer to our search.
const _notify = 'NOTIFY * HTTP/1.1\r\n'
    'HOST: 239.255.255.250:1900\r\n'
    'LOCATION: http://192.168.1.9:8060/\r\n'
    'NT: upnp:rootdevice\r\n'
    'USN: uuid:roku::upnp:rootdevice\r\n'
    '\r\n';

const _description = '''
<?xml version="1.0"?>
<root xmlns="urn:schemas-upnp-org:device-1-0">
  <specVersion><major>1</major><minor>0</minor></specVersion>
  <device>
    <deviceType>urn:schemas-upnp-org:device:MediaRenderer:1</deviceType>
    <friendlyName>Living room TV</friendlyName>
    <manufacturer>Samsung Electronics</manufacturer>
    <modelName>UE55</modelName>
    <serviceList>
      <service>
        <serviceType>urn:schemas-upnp-org:service:RenderingControl:1</serviceType>
        <controlURL>/upnp/control/RenderingControl1</controlURL>
      </service>
      <service>
        <serviceType>urn:schemas-upnp-org:service:AVTransport:1</serviceType>
        <controlURL>/upnp/control/AVTransport1</controlURL>
      </service>
    </serviceList>
  </device>
</root>
''';

void main() {
  group('SSDP', () {
    test('reads a search reply whatever case the headers are in', () {
      final response = parseSsdpResponse(_searchReply);

      expect(response, isNotNull);
      expect(response!.location, Uri.parse('http://192.168.1.42:9197/dmr'));
      expect(response.usn, startsWith('uuid:0d1e2f30'));
      expect(response.server, contains('Samsung'));
    });

    test('an unprompted NOTIFY is not an answer', () {
      // Acting on these would list devices that never replied to us, and
      // every network has them chattering constantly.
      expect(parseSsdpResponse(_notify), isNull);
    });

    test('a reply without a location or a USN is dropped', () {
      expect(
        parseSsdpResponse('HTTP/1.1 200 OK\r\nUSN: uuid:x\r\n\r\n'),
        isNull,
      );
      expect(
        parseSsdpResponse('HTTP/1.1 200 OK\r\nLOCATION: http://a/\r\n\r\n'),
        isNull,
      );
      expect(parseSsdpResponse(''), isNull);
    });

    test('the M-SEARCH datagram is shaped the way devices demand', () {
      final request = searchRequest();

      expect(request, startsWith('M-SEARCH * HTTP/1.1\r\n'));
      // The quotes around ssdp:discover are part of the value, and strict
      // devices drop the datagram without them.
      expect(request, contains('MAN: "ssdp:discover"\r\n'));
      expect(request, contains('ST: $mediaRendererTarget\r\n'));
      expect(request, endsWith('\r\n\r\n'));
    });
  });

  group('device description', () {
    test('finds AVTransport and resolves its URL against the location', () {
      final device = parseDeviceDescription(
        _description,
        Uri.parse('http://192.168.1.42:9197/dmr'),
      );

      expect(device, isNotNull);
      expect(device!.friendlyName, 'Living room TV');
      expect(device.modelName, 'UE55');
      // Not RenderingControl, which is listed first.
      expect(
        device.controlUrl,
        Uri.parse('http://192.168.1.42:9197/upnp/control/AVTransport1'),
      );
    });

    test('URLBase wins over the location it was fetched from', () {
      final device = parseDeviceDescription(
        _description.replaceFirst(
          '<device>',
          '<URLBase>http://192.168.1.42:52235/</URLBase><device>',
        ),
        Uri.parse('http://192.168.1.42:9197/dmr'),
      );

      expect(device!.controlUrl.port, 52235);
    });

    test('a device with no AVTransport is not castable', () {
      final device = parseDeviceDescription(
        _description.replaceAll('AVTransport:1', 'ConnectionManager:1'),
        Uri.parse('http://192.168.1.42:9197/dmr'),
      );

      expect(device, isNull);
    });

    test('unparseable XML is dropped rather than thrown', () {
      expect(parseDeviceDescription('<root', Uri.parse('http://a/')), isNull);
    });
  });

  group('SOAP', () {
    test('an envelope keeps its arguments in the order given', () {
      final envelope = soapEnvelope(avTransport, 'Seek', <(String, String)>[
        ('InstanceID', '0'),
        ('Unit', 'REL_TIME'),
        ('Target', '0:01:30'),
      ]);

      // UPnP actions are positional despite the named look.
      expect(
        envelope.indexOf('<Unit>'),
        lessThan(envelope.indexOf('<Target>')),
      );
      expect(envelope, contains('<u:Seek xmlns:u="$avTransport">'));
    });

    test('argument values are escaped', () {
      final envelope = soapEnvelope(avTransport, 'X', <(String, String)>[
        ('Title', 'Fish & Chips <2024>'),
      ]);

      expect(envelope, contains('Fish &amp; Chips &lt;2024&gt;'));
      expect(envelope, isNot(contains('<2024>')));
    });

    test('reads a value out of a reply whatever prefix it carries', () {
      const reply = '<?xml version="1.0"?>'
          '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">'
          '<s:Body><u:GetTransportInfoResponse>'
          '<CurrentTransportState>PLAYING</CurrentTransportState>'
          '</u:GetTransportInfoResponse></s:Body></s:Envelope>';

      expect(soapValue(reply, 'CurrentTransportState'), 'PLAYING');
      expect(soapValue(reply, 'Nonexistent'), isNull);
    });

    test('a fault is reported in words, not a code', () {
      const fault = '<?xml version="1.0"?>'
          '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">'
          '<s:Body><s:Fault><faultstring>UPnPError</faultstring>'
          '<detail><UPnPError><errorCode>701</errorCode>'
          '<errorDescription>Transition not available</errorDescription>'
          '</UPnPError></detail></s:Fault></s:Body></s:Envelope>';

      expect(soapFault(fault), 'Transition not available');
    });
  });

  group('UPnP time', () {
    test('formats as H:MM:SS', () {
      expect(formatUpnpTime(Duration.zero), '0:00:00');
      expect(formatUpnpTime(const Duration(seconds: 90)), '0:01:30');
      expect(
        formatUpnpTime(const Duration(hours: 2, minutes: 5, seconds: 9)),
        '2:05:09',
      );
      // A negative offset is not a time a device can seek to.
      expect(formatUpnpTime(const Duration(seconds: -5)), '0:00:00');
    });

    test('parses what devices actually send back', () {
      expect(parseUpnpTime('0:01:30'), const Duration(seconds: 90));
      expect(parseUpnpTime('01:00:00'), const Duration(hours: 1));
      // Fractional seconds are legal; dropping them must not yield null.
      expect(parseUpnpTime('0:00:10.500'), const Duration(seconds: 10));
    });

    test('NOT_IMPLEMENTED means the device has no answer', () {
      expect(parseUpnpTime('NOT_IMPLEMENTED'), isNull);
      expect(parseUpnpTime(''), isNull);
      expect(parseUpnpTime(null), isNull);
      expect(parseUpnpTime('rubbish'), isNull);
    });
  });

  group('DIDL metadata', () {
    test('carries the title, the URL and a seekable protocolInfo', () {
      final didl = didlMetadata(
        title: 'Dune',
        url: Uri.parse('http://192.168.1.5:8080/media/1'),
        contentType: 'video/x-matroska',
      );

      expect(didl, contains('<dc:title>Dune</dc:title>'));
      expect(didl, contains('object.item.videoItem'));
      // DLNA.ORG_OP=01 is what turns the television's scrubber on.
      expect(didl, contains('http-get:*:video/x-matroska:DLNA.ORG_OP=01'));
      expect(didl, contains('http://192.168.1.5:8080/media/1'));
    });

    test('a title with markup in it cannot break the document', () {
      final didl = didlMetadata(
        title: '<script>&',
        url: Uri.parse('http://a/b'),
      );

      expect(didl, contains('&lt;script&gt;&amp;'));
    });
  });

  group('content type', () {
    test('maps the containers a television cares about', () {
      expect(contentTypeFor('film.mkv'), 'video/x-matroska');
      expect(contentTypeFor('clip.MP4'), 'video/mp4');
      expect(contentTypeFor('show.ts'), 'video/mp2t');
      expect(contentTypeFor('old.avi'), 'video/x-msvideo');
    });

    test('an unknown extension guesses video/mp4', () {
      // Deliberately not octet-stream: many devices refuse that outright,
      // where a wrong-but-plausible type at least makes them try.
      expect(contentTypeFor('mystery.xyz'), 'video/mp4');
      expect(contentTypeFor('no-extension'), 'video/mp4');
    });
  });
}
