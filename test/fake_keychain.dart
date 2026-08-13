// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

/// Stands in for the platform keychain so credential handling can be driven
/// without a device.
///
/// Returns the backing map, so a test can assert on what was actually stored
/// rather than only on what the app claims. Uninstalls itself after the test.
Map<String, String> installFakeKeychain([Map<String, String>? initial]) {
  final store = <String, String>{...?initial};
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  messenger.setMockMethodCallHandler(_channel, (call) async {
    final args = (call.arguments as Map?) ?? const <dynamic, dynamic>{};
    final key = args['key'] as String?;
    return switch (call.method) {
      'write' => store[key!] = args['value'] as String,
      'read' => store[key!],
      'containsKey' => store.containsKey(key),
      'delete' => store.remove(key),
      'readAll' => store,
      'deleteAll' => store.clear(),
      _ => null,
    };
  });
  addTearDown(() => messenger.setMockMethodCallHandler(_channel, null));

  return store;
}
