// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:window_manager/window_manager.dart';

import '../../app/tokens.dart';
import '../../sources/media_source.dart';
import 'controls_overlay.dart';
import 'gesture_layer.dart';
import 'more_menu.dart';
import 'playback_controller.dart';
import 'playback_state.dart';
import 'player_ui_state.dart';
import 'stats_overlay.dart';
import 'track_sheet.dart';

/// Screen 1h — the single player, shared by local files, shares and streams.
///
/// Composes four layers: the video surface, the gesture zones, the chrome, and
/// the overlays (stats, lock). Nothing here talks to `media_kit` except the
/// surface itself.
class PlayerPage extends ConsumerStatefulWidget {
  const PlayerPage({super.key, required this.media});

  /// Already resolved by the caller, so the title and source line are known
  /// before the first frame decodes.
  final PlayableMedia media;

  @override
  ConsumerState<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends ConsumerState<PlayerPage> {
  static const _chromeTimeout = Duration(seconds: 3);
  static const _speeds = <double>[0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  bool _chromeVisible = true;
  bool _fullscreen = false;
  Timer? _hideTimer;
  Timer? _sleepTimer;

  /// While the user drags, the scrubber follows the finger rather than the
  /// position stream, which would fight it.
  double? _dragProgress;

  @override
  void initState() {
    super.initState();
    // The notifier outlives this page, so opening happens after the first
    // frame — mutating a provider during build is not allowed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(playbackControllerProvider.notifier).openResolved(widget.media);
    });
    _restartHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _sleepTimer?.cancel();
    // Leaving the screen must not strand a decoder holding the file open, nor
    // a locked orientation on the rest of the app.
    unawaited(ref.read(playbackControllerProvider.notifier).stop());
    ref.read(playerUiProvider.notifier).reset();
    super.dispose();
  }

  void _restartHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(_chromeTimeout, () {
      if (mounted) setState(() => _chromeVisible = false);
    });
  }

  void _toggleChrome() {
    setState(() => _chromeVisible = !_chromeVisible);
    if (_chromeVisible) _restartHideTimer();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playbackControllerProvider);
    final ui = ref.watch(playerUiProvider);
    final controller = ref.read(playbackControllerProvider.notifier);

    _syncSleepTimer(ui.sleepTimer);

    return Theme(
      // The player is always dark, whatever the app theme is.
      data: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ThemeData.dark(useMaterial3: true).colorScheme.copyWith(
              primaryContainer: const Color(0xFF004C6D),
              onPrimaryContainer: const Color(0xFFC7E7FF),
            ),
        extensions: Theme.of(context).extensions.values,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Focus(
          autofocus: true,
          onKeyEvent: (_, event) => _handleKey(event, controller, ui),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              _VideoSurface(controller: controller, fit: ui.aspect.boxFit),

              // Gestures sit above the video and below the chrome, and go
              // inert entirely while locked.
              GestureLayer(
                enabled: !ui.locked,
                state: state,
                onTap: _toggleChrome,
                onSeekBy: controller.skip,
                onSeekTo: controller.seek,
                onVolume: controller.setVolume,
              ),

              if (state.error != null) _ErrorOverlay(message: state.error!),
              if (state.buffering && state.error == null)
                const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),

              if (ui.statsVisible) StatsOverlay(state: state),

              if (!ui.locked)
                AnimatedOpacity(
                  opacity: _chromeVisible ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: IgnorePointer(
                    ignoring: !_chromeVisible,
                    child: ControlsOverlay(
                      media: widget.media,
                      state: state,
                      ui: ui,
                      dragProgress: _dragProgress,
                      onInteraction: _restartHideTimer,
                      onPlayPause: () {
                        _restartHideTimer();
                        controller.playOrPause();
                      },
                      onSkip: controller.skip,
                      onScrubStart: (v) => setState(() => _dragProgress = v),
                      onScrubUpdate: (v) => setState(() => _dragProgress = v),
                      onScrubEnd: (v) {
                        setState(() => _dragProgress = null);
                        controller.seek(state.duration * v);
                      },
                      onSubtitles: () => _pickSubtitle(state, controller),
                      onAudio: () => _pickAudio(state, controller),
                      onQuality: () => _notImplemented('Quality selection'),
                      onSpeed: () => _pickSpeed(state, controller),
                      onLock: () {
                        ref.read(playerUiProvider.notifier).toggleLock();
                        setState(() => _chromeVisible = false);
                      },
                      onRotate: ref.read(playerUiProvider.notifier).cycleRotation,
                      onChapters: () => _showChapters(state, controller),
                      onFullscreen: _toggleFullscreen,
                      onMore: () => MoreMenu.show(context),
                      onSkipIntro: (chapter) => controller.seek(chapter.end),
                      notImplemented: _notImplemented,
                    ),
                  ),
                ),

              if (ui.locked) _LockedOverlay(state: state),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- sheets

  Future<void> _pickSubtitle(
    PlaybackState state,
    PlaybackController controller,
  ) async {
    _restartHideTimer();
    await TrackSheet.show(
      context: context,
      title: 'Subtitles',
      selectedId: state.activeSubtitle?.id,
      options: <TrackOption>[
        for (final MediaTrack t in state.subtitleTracks)
          TrackOption.fromTrack(t),
      ],
      onSelected: (o) => controller.setSubtitleTrack(o.track),
    );
  }

  Future<void> _pickAudio(
    PlaybackState state,
    PlaybackController controller,
  ) async {
    _restartHideTimer();
    await TrackSheet.show(
      context: context,
      title: 'Audio',
      selectedId: state.activeAudio?.id,
      options: <TrackOption>[
        for (final MediaTrack t in state.audioTracks) TrackOption.fromTrack(t),
      ],
      onSelected: (o) {
        if (o.track != null) controller.setAudioTrack(o.track!);
      },
    );
  }

  Future<void> _pickSpeed(
    PlaybackState state,
    PlaybackController controller,
  ) async {
    _restartHideTimer();
    await TrackSheet.show(
      context: context,
      title: 'Playback speed',
      selectedId: state.speed.toStringAsFixed(2),
      options: <TrackOption>[
        for (final double s in _speeds)
          TrackOption(
            id: s.toStringAsFixed(2),
            label: '${s.toStringAsFixed(2)}×',
            detail: s == 1.0 ? 'Normal' : null,
            value: s,
          ),
      ],
      onSelected: (o) {
        if (o.value != null) controller.setSpeed(o.value!);
      },
    );
  }

  Future<void> _showChapters(
    PlaybackState state,
    PlaybackController controller,
  ) async {
    _restartHideTimer();

    // Chapters come from the container or the source; plenty of files carry
    // none at all, and saying so beats opening an empty sheet.
    if (state.chapters.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This file has no chapters')),
      );
      return;
    }

    await TrackSheet.show(
      context: context,
      title: 'Chapters',
      selectedId: state.chapterAt(state.position)?.title,
      options: <TrackOption>[
        for (final MediaChapter c in state.chapters)
          TrackOption(
            id: c.title,
            label: c.title,
            detail: formatDuration(c.start),
            value: c.start.inMilliseconds.toDouble(),
          ),
      ],
      onSelected: (o) {
        if (o.value != null) {
          controller.seek(Duration(milliseconds: o.value!.round()));
        }
      },
    );
  }

  // ---------------------------------------------------------------- misc

  /// Desktop toggles the OS window; mobile hides the system bars instead.
  ///
  /// `window_manager` throws on Android and iOS, which is the signal to fall
  /// back rather than an error worth surfacing.
  Future<void> _toggleFullscreen() async {
    _restartHideTimer();
    final next = !_fullscreen;

    try {
      await windowManager.setFullScreen(next);
    } catch (_) {
      await SystemChrome.setEnabledSystemUIMode(
        next ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
      );
    }

    if (mounted) setState(() => _fullscreen = next);
  }

  /// Starts or cancels the countdown whenever the menu changes it.
  void _syncSleepTimer(Duration? d) {
    if (d == null) {
      _sleepTimer?.cancel();
      _sleepTimer = null;
      return;
    }
    if (_sleepTimer?.isActive ?? false) return;

    _sleepTimer = Timer(d, () {
      if (!mounted) return;
      ref.read(playbackControllerProvider.notifier).pause();
      ref.read(playerUiProvider.notifier).setSleepTimer(null);
    });
  }

  KeyEventResult _handleKey(
    KeyEvent event,
    PlaybackController controller,
    PlayerUiState ui,
  ) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    // Locked means locked, including the keyboard.
    if (ui.locked) return KeyEventResult.handled;

    _restartHideTimer();
    if (!_chromeVisible) setState(() => _chromeVisible = true);

    switch (event.logicalKey) {
      case LogicalKeyboardKey.space:
      case LogicalKeyboardKey.keyK:
        controller.playOrPause();
      case LogicalKeyboardKey.arrowLeft:
        controller.skip(const Duration(seconds: -10));
      case LogicalKeyboardKey.arrowRight:
        controller.skip(const Duration(seconds: 30));
      case LogicalKeyboardKey.keyF:
        _toggleFullscreen();
      case LogicalKeyboardKey.escape:
        if (context.canPop()) context.pop();
      default:
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  void _notImplemented(String what) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$what — not implemented yet')),
    );
  }
}

class _VideoSurface extends StatelessWidget {
  const _VideoSurface({required this.controller, required this.fit});

  final PlaybackController controller;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final videoController = controller.videoController;
    if (videoController == null) {
      return const ColoredBox(color: Colors.black);
    }
    return Video(
      controller: videoController,
      controls: NoVideoControls,
      fit: fit,
      fill: Colors.black,
    );
  }
}

/// Locked state: everything dims, only the unlock affordance and the progress
/// bar remain. Double-tapping the lock exits, so a pocket touch cannot.
class _LockedOverlay extends ConsumerStatefulWidget {
  const _LockedOverlay({required this.state});

  final PlaybackState state;

  @override
  ConsumerState<_LockedOverlay> createState() => _LockedOverlayState();
}

class _LockedOverlayState extends ConsumerState<_LockedOverlay> {
  bool _hintVisible = true;
  Timer? _hintTimer;

  @override
  void initState() {
    super.initState();
    _restartHint();
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    super.dispose();
  }

  void _restartHint() {
    setState(() => _hintVisible = true);
    _hintTimer?.cancel();
    _hintTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _hintVisible = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    return GestureDetector(
      // A single tap only re-reveals the hint; it never unlocks.
      onTap: _restartHint,
      behavior: HitTestBehavior.opaque,
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.45),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            AnimatedOpacity(
              opacity: _hintVisible ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    GestureDetector(
                      onDoubleTap:
                          ref.read(playerUiProvider.notifier).unlock,
                      child: CircleButton(
                        icon: Icons.lock_rounded,
                        size: 56,
                        iconSize: 26,
                        background: Colors.white.withValues(alpha: 0.12),
                        foreground: Colors.white,
                        tooltip: 'Locked',
                        // Handled by the double-tap wrapper; a single tap
                        // must not unlock.
                        onPressed: _restartHint,
                      ),
                    ),
                    SizedBox(height: spacing.lg),
                    const Text(
                      'Screen locked',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: spacing.xs),
                    Text(
                      'Tap the lock twice to unlock',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // The progress bar stays visible at the very bottom, so a locked
            // screen still says how far in you are.
            Align(
              alignment: Alignment.bottomCenter,
              child: LinearProgressIndicator(
                value: widget.state.progress,
                minHeight: 3,
                backgroundColor: Colors.white.withValues(alpha: 0.25),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorOverlay extends StatelessWidget {
  const _ErrorOverlay({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 44),
            SizedBox(height: spacing.lg),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
