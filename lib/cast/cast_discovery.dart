// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'cast_device.dart';
import 'ssdp.dart';
import 'upnp.dart';

/// Turns SSDP replies into devices worth showing.
///
/// Two steps, because SSDP only says *where* a device describes itself: the
/// search collects locations, and each one is then fetched and read for a
/// name and an AVTransport control URL. Anything that fails either step is
/// dropped — a device this app cannot drive is worse than absent in a list
/// the user is choosing a television from.
Future<List<CastDevice>> discoverDlnaDevices({
  Dio? client,
  Duration timeout = const Duration(seconds: 3),
}) async {
  final responses = await discover(timeout: timeout);
  if (responses.isEmpty) return const <CastDevice>[];

  final dio = client ??
      Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 3),
          receiveTimeout: const Duration(seconds: 5),
          responseType: ResponseType.plain,
        ),
      );

  // A device answers once per interface it heard the question on, so the same
  // USN routinely arrives several times.
  final seen = <String>{};
  final unique = <SsdpResponse>[];
  for (final SsdpResponse response in responses) {
    if (seen.add(response.usn)) unique.add(response);
  }

  // In parallel: one sleeping device must not hold up the rest of the list,
  // and the timeouts above bound the whole thing either way.
  final devices = await Future.wait(
    unique.map((r) => _describe(dio, r)),
  );

  return devices.whereType<CastDevice>().toList();
}

Future<CastDevice?> _describe(Dio dio, SsdpResponse response) async {
  try {
    final document = await dio.getUri<String>(response.location);
    final body = document.data;
    if (body == null || body.isEmpty) return null;

    final device = parseDeviceDescription(body, response.location);
    if (device == null) return null;

    return CastDevice(
      id: response.usn,
      name: device.friendlyName,
      kind: CastKind.dlna,
      // The manufacturer alone is what most televisions put in modelName, so
      // the two are joined only when they say different things.
      model: _model(device.manufacturer, device.modelName),
      controlUrl: device.controlUrl,
      address: response.location.host,
    );
  } catch (e) {
    debugPrint('Could not read a device description: $e');
    return null;
  }
}

String? _model(String? manufacturer, String? modelName) {
  final parts = <String>[
    if (manufacturer != null && manufacturer.isNotEmpty) manufacturer,
    if (modelName != null &&
        modelName.isNotEmpty &&
        modelName.toLowerCase() != manufacturer?.toLowerCase())
      modelName,
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}
