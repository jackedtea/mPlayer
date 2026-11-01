// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The library each server was last browsed in, keyed by profile id.
///
/// Per server rather than one value: a library id means nothing on another
/// server, and someone with two would otherwise land on the first library of
/// whichever they did not use last.
///
/// Async so the Libraries tab can tell "not read yet" from "never opened
/// one" — opening the first library while the stored choice is still on its
/// way would flash it before jumping to the right one.
final lastLibraryProvider =
    AsyncNotifierProvider<LastLibraryController, Map<String, String>>(
  LastLibraryController.new,
);

class LastLibraryController extends AsyncNotifier<Map<String, String>> {
  static const _prefsKey = 'last_library_by_server';

  @override
  Future<Map<String, String>> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return const <String, String>{};

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const <String, String>{};
      return <String, String>{
        for (final MapEntry<dynamic, dynamic> e in decoded.entries)
          if (e.key is String && e.value is String)
            e.key as String: e.value as String,
      };
    } on FormatException catch (e) {
      // A corrupt entry costs the user one jump to their usual library, not
      // a Libraries tab that fails to open.
      debugPrint('Ignoring unreadable last-library map: $e');
      return const <String, String>{};
    }
  }

  /// Notes that [viewId] was opened on the server [profileId].
  Future<void> remember(String profileId, String viewId) async {
    final current = await future;
    if (current[profileId] == viewId) return;

    final next = <String, String>{...current, profileId: viewId};
    state = AsyncValue<Map<String, String>>.data(next);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(next));
  }
}
