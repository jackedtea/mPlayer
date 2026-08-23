// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'cast_device.dart';
import 'cast_renderer.dart';
import 'upnp.dart';

/// Drives a DLNA renderer over SOAP.
///
/// Written by hand rather than taken from a package, for the same reason the
/// WebDAV client is: three actions and two queries are the whole of what a
/// player needs from AVTransport, and every UPnP package on pub carries a
/// discovery stack and a content-directory browser along with them.
class DlnaRenderer implements CastRenderer {
  DlnaRenderer(this.device, {Dio? client})
      : _control = device.controlUrl!,
        _dio = client ??
            Dio(
              BaseOptions(
                // A television that has gone to sleep answers nothing at all,
                // and the picker has to be able to say so rather than hang.
                connectTimeout: const Duration(seconds: 5),
                receiveTimeout: const Duration(seconds: 10),
                responseType: ResponseType.plain,
                // A SOAP fault comes back as 500 with a body worth reading.
                validateStatus: (_) => true,
              ),
            );

  @override
  final CastDevice device;

  final Uri _control;
  final Dio _dio;

  @override
  Future<void> load(
    Uri url, {
    required String title,
    String contentType = 'video/mp4',
    Duration position = Duration.zero,
  }) async {
    // Stop first: a renderer already showing something rejects a new URI
    // often enough that setting it blind loses the cast on the second file.
    await _tryAction('Stop', <(String, String)>[('InstanceID', '0')]);

    await _action('SetAVTransportURI', <(String, String)>[
      ('InstanceID', '0'),
      ('CurrentURI', url.toString()),
      (
        'CurrentURIMetaData',
        didlMetadata(title: title, url: url, contentType: contentType),
      ),
    ]);

    await play();

    // Only after playback starts: a renderer cannot seek a stream it has not
    // opened, and several answer the attempt with a fault that would
    // otherwise read as a failed cast.
    if (position > Duration.zero) await seek(position);
  }

  @override
  Future<void> play() => _action('Play', <(String, String)>[
        ('InstanceID', '0'),
        // "1" is normal speed. The field is a string by specification.
        ('Speed', '1'),
      ]);

  @override
  Future<void> pause() =>
      _action('Pause', <(String, String)>[('InstanceID', '0')]);

  @override
  Future<void> stop() =>
      _action('Stop', <(String, String)>[('InstanceID', '0')]);

  @override
  Future<void> seek(Duration to) => _action('Seek', <(String, String)>[
        ('InstanceID', '0'),
        ('Unit', 'REL_TIME'),
        ('Target', formatUpnpTime(to)),
      ]);

  @override
  Future<CastStatus> status() async {
    final transport = await _request(
      'GetTransportInfo',
      <(String, String)>[('InstanceID', '0')],
    );
    final positionInfo = await _request(
      'GetPositionInfo',
      <(String, String)>[('InstanceID', '0')],
    );

    return CastStatus(
      playback: _playbackFrom(soapValue(transport, 'CurrentTransportState')),
      position: parseUpnpTime(soapValue(positionInfo, 'RelTime')) ??
          Duration.zero,
      duration: parseUpnpTime(soapValue(positionInfo, 'TrackDuration')) ??
          Duration.zero,
    );
  }

  @override
  Future<void> dispose() async {
    _dio.close(force: true);
  }

  static CastPlayback _playbackFrom(String? state) {
    return switch (state?.trim().toUpperCase()) {
      'PLAYING' => CastPlayback.playing,
      'PAUSED_PLAYBACK' || 'PAUSED_RECORDING' => CastPlayback.paused,
      'TRANSITIONING' => CastPlayback.buffering,
      'STOPPED' => CastPlayback.stopped,
      _ => CastPlayback.idle,
    };
  }

  Future<void> _action(String name, List<(String, String)> arguments) async {
    await _request(name, arguments);
  }

  /// Like [_action] but for the commands whose failure is not worth
  /// reporting — the speculative Stop before a load, most of all.
  Future<void> _tryAction(String name, List<(String, String)> args) async {
    try {
      await _request(name, args);
    } on CastException catch (e) {
      debugPrint('Ignoring a failed $name: ${e.message}');
    }
  }

  Future<String> _request(
    String action,
    List<(String, String)> arguments,
  ) async {
    final Response<String> response;
    try {
      response = await _dio.postUri<String>(
        _control,
        data: soapEnvelope(avTransport, action, arguments),
        options: Options(
          headers: <String, String>{
            'Content-Type': 'text/xml; charset="utf-8"',
            // The quotes are part of the header value, not Dart syntax: a
            // device that parses strictly rejects the call without them.
            'SOAPACTION': '"$avTransport#$action"',
          },
        ),
      );
    } on DioException catch (e) {
      throw CastException(
        e.type == DioExceptionType.connectionTimeout ||
                e.type == DioExceptionType.connectionError
            ? '${device.name} did not answer. It may be asleep or on another '
                'network.'
            : 'Could not reach ${device.name}.',
      );
    }

    final body = response.data ?? '';
    final status = response.statusCode ?? 0;

    if (status < 200 || status >= 300) {
      final fault = soapFault(body);
      throw CastException(
        fault == null
            ? '${device.name} refused the request ($status).'
            : '${device.name} refused the request: $fault',
      );
    }

    return body;
  }
}
