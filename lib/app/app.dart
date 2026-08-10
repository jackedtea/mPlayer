// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'router.dart';
import 'theme.dart';

/// Root widget.
///
/// [router] is injectable so widget tests can drive a single screen without
/// standing up the whole shell.
class MPlayerApp extends StatefulWidget {
  const MPlayerApp({super.key, this.router, this.themeMode = ThemeMode.system});

  final GoRouter? router;

  /// Persisted to `shared_preferences` once the Appearance page lands; the
  /// design's default is Light, with System offered alongside it.
  final ThemeMode themeMode;

  @override
  State<MPlayerApp> createState() => _MPlayerAppState();
}

class _MPlayerAppState extends State<MPlayerApp> {
  late final GoRouter _router = widget.router ?? buildRouter();

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'mPlayer',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: widget.themeMode,
      routerConfig: _router,
    );
  }
}
