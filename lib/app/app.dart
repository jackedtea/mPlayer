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
import '../features/player/stable_insets.dart';
import 'system_ui.dart';
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
      builder: (context, child) {
        final content = _InsetFromSystemBars(
          child: child ?? const SizedBox.shrink(),
        );

        return isDesktop
            ? DropTarget(
                onDragDone: (details) {
                  final file = details.files.firstOrNull;
                  if (file != null) _openPath(file.path);
                },
                child: content,
              )
            : content;
      },
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

/// Keeps the app between the status bar and the navigation bar.
///
/// The app is edge to edge — Android 15 gives it no choice — so without this
/// the window extends under both bars and they are drawn on top of it. Every
/// screen's own padding already keeps its *text* clear of them, but the
/// surface, the artwork and the app bars still ran underneath, which is what
/// reads as the bars sitting on top of the app.
///
/// One wrapper above the navigator rather than a `SafeArea` per screen: there
/// are twenty-one routes and the next one added would be the one that forgets.
///
/// The inset strips are painted in the app's own surface colour, so the bars
/// sit on the app rather than on whatever happens to be behind the window.
///
/// The player opts out through [fullBleedUi]: letterboxing a film to leave
/// room for a navigation bar throws away the part of the screen the user came
/// for.
class _InsetFromSystemBars extends StatelessWidget {
  const _InsetFromSystemBars({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<WindowEdges>(
      valueListenable: windowEdges,
      builder: (context, edges, _) {
        // Noted here, above this widget's own `SafeArea`, which is the last
        // place in the tree that still sees what the bars measure. The player
        // lays its controls out against the largest reading rather than
        // against whatever the bars happen to be doing at the moment.
        recordSystemInsets(MediaQuery.viewPaddingOf(context));
        recordSystemInsets(MediaQuery.paddingOf(context));

        // **The same widgets in the same places, whatever the answer.**
        //
        // Returning a bare `child` for the player and a wrapped one otherwise
        // changes the shape of the tree above the navigator, and Flutter can
        // only reuse an element when the widget at that position keeps its
        // type. So every claim tore the navigator down and built a new one —
        // taking the route stack with it, which is why opening any video at
        // all landed on "Nothing to play": the `/player` route was rebuilt
        // without the media it had been pushed with.
        //
        // Only the flag changes now.
        return ColoredBox(
          color: Theme.of(context).colorScheme.surface,
          child: SafeArea(
            // An `AppBar` already lays itself out below the status bar, and
            // the screens without one want their backdrop up there, so the
            // top is never inset.
            top: false,
            bottom: edges != WindowEdges.none,
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
