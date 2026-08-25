// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How densely the library grid packs its posters.
///
/// Persisted on its own key rather than folded into the appearance settings:
/// this is a per-screen view preference, not part of the theme, and the two
/// have no reason to be written together.
class LibraryColumnsController extends Notifier<int> {
  static const _prefsKey = 'library_columns_v1';

  /// What the design draws on a phone.
  static const defaultColumns = 3;

  /// Below two a "grid" is a list; above six a poster on a phone is a stamp.
  static const minColumns = 2;
  static const maxColumns = 6;

  @override
  int build() {
    // Same reasoning as the appearance settings: the default paints now and
    // the stored choice arrives a frame later, rather than blocking the first
    // frame on a disk read.
    Future<void>.microtask(_restore);
    return defaultColumns;
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getInt(_prefsKey);
      if (stored != null) state = _clamp(stored);
    } catch (e) {
      debugPrint('Unreadable library columns, using the default: $e');
    }
  }

  Future<void> set(int columns) async {
    state = _clamp(columns);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefsKey, state);
  }

  static int _clamp(int v) => v.clamp(minColumns, maxColumns);
}

final libraryColumnsProvider =
    NotifierProvider<LibraryColumnsController, int>(LibraryColumnsController.new);

/// The setting is what a *phone* shows; a wider window earns more columns.
///
/// Scaled rather than obeyed literally, because the setting is really a
/// statement about how big a poster should be. Three columns chosen on a
/// phone and applied unchanged to a desktop window would draw posters the
/// width of a hand.
int columnsForWidth(int setting, double width) {
  final extra = switch (width) {
    >= 1600 => 5,
    >= 1240 => 4,
    >= 900 => 2,
    >= 600 => 1,
    _ => 0,
  };
  return setting + extra;
}
