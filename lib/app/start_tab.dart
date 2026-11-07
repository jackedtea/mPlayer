// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart' show debugPrint, immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'adaptive_scaffold.dart' show AppBranch;

/// Which destination a launch opens on.
@immutable
class StartTab {
  const StartTab({
    this.tab = AppBranch.home,
    this.rememberLast = false,
    this.last,
  });

  /// The destination chosen in Settings.
  final AppBranch tab;

  /// Whether the destination left last time wins over [tab].
  final bool rememberLast;

  /// The destination on screen when the app last ran. Null before any move.
  final AppBranch? last;

  AppBranch get target => rememberLast ? last ?? tab : tab;

  StartTab copyWith({AppBranch? tab, bool? rememberLast, AppBranch? last}) {
    return StartTab(
      tab: tab ?? this.tab,
      rememberLast: rememberLast ?? this.rememberLast,
      last: last ?? this.last,
    );
  }
}

/// Kept on this device rather than on the server: it is needed before anything
/// is signed in, and a television and a phone have no reason to agree on it.
final startTabProvider = AsyncNotifierProvider<StartTabController, StartTab>(
  StartTabController.new,
);

class StartTabController extends AsyncNotifier<StartTab> {
  static const _tabKey = 'start_tab';
  static const _rememberKey = 'start_tab_remember_last';
  static const _lastKey = 'start_tab_last';

  static AppBranch? _branch(String? name) {
    for (final AppBranch branch in AppBranch.values) {
      if (branch.name == name) return branch;
    }
    return null;
  }

  @override
  Future<StartTab> build() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return StartTab(
        tab: _branch(prefs.getString(_tabKey)) ?? AppBranch.home,
        rememberLast: prefs.getBool(_rememberKey) ?? false,
        last: _branch(prefs.getString(_lastKey)),
      );
    } catch (e) {
      debugPrint('Unreadable start tab, opening on Home: $e');
      return const StartTab();
    }
  }

  Future<void> setTab(AppBranch tab) async {
    final current = await future;
    state = AsyncValue<StartTab>.data(current.copyWith(tab: tab));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tabKey, tab.name);
  }

  Future<void> setRememberLast(bool remember) async {
    final current = await future;
    state = AsyncValue<StartTab>.data(
      current.copyWith(rememberLast: remember),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberKey, remember);
  }

  /// Notes the destination now on screen.
  ///
  /// As it changes rather than on the way out: Android gives an app swiped
  /// away no last word, so anything left for closing time would be lost.
  /// Whether or not the switch is on, so turning it on is right from then on.
  void noteTab(AppBranch tab) => unawaited(_noteTab(tab));

  Future<void> _noteTab(AppBranch tab) async {
    try {
      final current = await future;
      state = AsyncValue<StartTab>.data(current.copyWith(last: tab));
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastKey, tab.name);
    } catch (e) {
      // The next launch opens somewhere else; nothing here is worth more.
      debugPrint('Could not note the tab: $e');
    }
  }
}
