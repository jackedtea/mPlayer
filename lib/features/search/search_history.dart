// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The last searches run, newest first, kept on this device only.
///
/// They used to live for as long as the screen did, so nothing anyone had
/// searched for was ever written down. Keeping them is what makes the list
/// useful — the same few titles get searched again — so they are kept, capped
/// at [limit], and every one can be removed on its own or all at once.
final searchHistoryProvider =
    AsyncNotifierProvider<SearchHistoryController, List<String>>(
  SearchHistoryController.new,
);

class SearchHistoryController extends AsyncNotifier<List<String>> {
  static const _prefsKey = 'search_history_v1';

  /// How many searches are remembered.
  static const limit = 10;

  @override
  Future<List<String>> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_prefsKey) ?? const <String>[];
  }

  /// Puts [query] at the top, once: running a search already in the list
  /// moves it up rather than adding a second copy.
  Future<void> add(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    final current = await future;
    final key = trimmed.toLowerCase();
    await _save(<String>[
      trimmed,
      for (final String q in current)
        if (q.toLowerCase() != key) q,
    ].take(limit).toList());
  }

  Future<void> remove(String query) async {
    final current = await future;
    await _save(<String>[
      for (final String q in current)
        if (q != query) q,
    ]);
  }

  Future<void> clear() => _save(const <String>[]);

  Future<void> _save(List<String> next) async {
    state = AsyncValue<List<String>>.data(next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, next);
  }
}
