// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:async';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;

import '../features/player/incoming_media.dart';
import '../features/player/playback_controller.dart';
import '../l10n/app_localizations.dart';
import '../sources/local_source.dart';
import '../sources/media_source.dart';
import 'appearance_settings.dart';
import 'desktop_window.dart';
import 'locale_controller.dart';
import 'router.dart';
import 'theme.dart';

/// Root widget.
///
/// [router] is injectable so widget tests can drive a single screen without
/// standing up the whole shell.
class MPlayerApp extends ConsumerStatefulWidget {
  const MPlayerApp({super.key, this.router, this.themeMode});

  final GoRouter? router;

  /// Forces a theme mode, for tests that need one. Null — the normal case —
  /// follows the persisted choice from the Appearance page.
  final ThemeMode? themeMode;

  @override
  ConsumerState<MPlayerApp> createState() => _MPlayerAppState();
}

class _MPlayerAppState extends ConsumerState<MPlayerApp> {
  late final GoRouter _router = widget.router ?? buildRouter();

  StreamSubscription<String>? _handoffs;

  @override
  void initState() {
    super.initState();
    // A second launch on desktop hands its file here rather than opening a
    // window of its own.
    _handoffs = handedOverFiles.listen(_openPath);
  }

  @override
  void dispose() {
    unawaited(_handoffs?.cancel());
    super.dispose();
  }

  /// A path from outside the app: a second launch, or a file dropped on the
  /// window. Both are local paths, which is what the device source reads.
  void _openPath(String path) {
    if (path.isEmpty) return;
    unawaited(
      _openIncoming(
        MediaRef(
          sourceId: LocalSource.sourceId,
          itemId: path,
          title: p.basename(path),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // A file opened from a file manager or the share sheet. Routed from here
    // rather than from a screen, because it can arrive whichever screen is
    // showing — including before the first one has been built.
    ref.listen<MediaRef?>(incomingMediaProvider, (_, mediaRef) {
      if (mediaRef != null) unawaited(_openIncoming(mediaRef));
    });

    final appearance = ref.watch(appearanceSettingsProvider);

    // Only the wallpaper palette needs the platform round-trip, so the
    // builder is skipped entirely unless the user asked for it — every other
    // configuration paints on the first frame.
    if (!appearance.dynamicColour) return _app(appearance);

    return DynamicColorBuilder(
      builder: (ColorScheme? light, ColorScheme? dark) =>
          _app(appearance, dynamicLight: light, dynamicDark: dark),
    );
  }

  /// [dynamicLight] / [dynamicDark] are null on every platform but Android
  /// 12+, and on Android before the palette has been read; the accent
  /// preset stands in until then.
  Widget _app(
    AppearanceSettings appearance, {
    ColorScheme? dynamicLight,
    ColorScheme? dynamicDark,
  }) {
    return MaterialApp.router(
      title: 'mPlayer',
      debugShowCheckedModeBanner: false,
      // Lets a failure from an incoming file report without a BuildContext
      // from inside the navigator.
      scaffoldMessengerKey: _messengerKey,
      theme: buildTheme(
        Brightness.light,
        accent: appearance.accent,
        dynamicScheme: dynamicLight,
      ),
      darkTheme: buildTheme(
        Brightness.dark,
        accent: appearance.accent,
        dynamicScheme: dynamicDark,
        pureBlack: appearance.pureBlack,
      ),
      themeMode: widget.themeMode ?? appearance.mode,
      // Null means follow the device; Flutter then resolves against
      // supportedLocales and falls back to English.
      locale: ref.watch(localeProvider),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: _router,
      // Wrapping the navigator rather than a screen: a file dropped anywhere
      // in the window should play, not only on the Files tab.
      builder: (context, child) => isDesktop
          ? DropTarget(
              onDragDone: (details) {
                final file = details.files.firstOrNull;
                if (file != null) _openPath(file.path);
              },
              child: child ?? const SizedBox.shrink(),
            )
          : child ?? const SizedBox.shrink(),
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
