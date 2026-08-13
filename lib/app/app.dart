// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/player/incoming_media.dart';
import '../features/player/playback_controller.dart';
import '../l10n/app_localizations.dart';
import '../sources/media_source.dart';
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
    // A file opened from a file manager or the share sheet. Routed from here
    // rather than from a screen, because it can arrive whichever screen is
    // showing — including before the first one has been built.
    ref.listen<MediaRef?>(incomingMediaProvider, (_, mediaRef) {
      if (mediaRef != null) unawaited(_openIncoming(mediaRef));
    });

    return MaterialApp.router(
      title: 'mPlayer',
      debugShowCheckedModeBanner: false,
      // Lets a failure from an incoming file report without a BuildContext
      // from inside the navigator.
      scaffoldMessengerKey: _messengerKey,
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

  /// Resolves the handed-over file and pushes the player onto it.
  ///
  /// Resolution happens here rather than in the player so an unreadable file
  /// reports on whatever screen is showing, instead of opening a black player
  /// that then fails.
  Future<void> _openIncoming(MediaRef mediaRef) async {
    // Clear first: an error must not leave the file pending and reopen it on
    // the next rebuild.
    ref.read(incomingMediaProvider.notifier).consume();

    try {
      final source = ref.read(localSourceProvider);
      final media = await source.resolve(mediaRef);
      _router.push('/player', extra: media);
    } on MediaSourceException catch (e) {
      final messenger = _messengerKey.currentState;
      messenger?.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
}
