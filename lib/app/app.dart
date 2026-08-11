// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import 'locale_controller.dart';
import 'router.dart';
import 'theme.dart';

/// Root widget.
///
/// [router] is injectable so widget tests can drive a single screen without
/// standing up the whole shell.
class MPlayerApp extends ConsumerStatefulWidget {
  const MPlayerApp({super.key, this.router, this.themeMode = ThemeMode.system});

  final GoRouter? router;

  /// Persisted to `shared_preferences` once the Appearance page lands; the
  /// design's default is Light, with System offered alongside it.
  final ThemeMode themeMode;

  @override
  ConsumerState<MPlayerApp> createState() => _MPlayerAppState();
}

class _MPlayerAppState extends ConsumerState<MPlayerApp> {
  late final GoRouter _router = widget.router ?? buildRouter();

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'mPlayer',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: widget.themeMode,
      // Null means follow the device; Flutter then resolves against
      // supportedLocales and falls back to English.
      locale: ref.watch(localeProvider),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: _router,
    );
  }
}
