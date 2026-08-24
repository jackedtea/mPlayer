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
import '../../l10n/app_localizations.dart';
import '../../cast/cast_device.dart';
import '../../sources/media_source.dart';
import '../cast/cast_controller.dart';
import '../cast/cast_sheet.dart';
import '../cast/casting_overlay.dart';
import 'controls_overlay.dart';
import 'gesture_layer.dart';
import 'more_menu.dart';
import 'now_playing.dart';
import 'pip_controller.dart';
import 'playback_controller.dart';
import 'playback_state.dart';
import 'player_ui_state.dart';
import '../settings/player_settings.dart';
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

  /// Captured in [initState] rather than read in [dispose].
  ///
  /// Touching `ref` while the element is being torn down is not guaranteed to
  /// work, and if it throws, teardown never runs and the decoder keeps
  /// playing behind the popped route.
  late final PlaybackController _playback;
  late final PlayerUiController _playerUi;

  /// While the user drags, the scrubber follows the finger rather than the
  /// position stream, which would fight it.
  double? _dragProgress;

  StreamSubscription<PipControl>? _pipControls;
  StreamSubscription<NowPlayingEvent>? _notificationCommands;
  AppLifecycleListener? _lifecycle;

  /// Deferred so picture in picture has a chance to report itself first.
  /// Entering the window pauses the activity too, and pausing playback for
  /// that would stop the video the user just floated onto their home screen.
  Timer? _leftForegroundTimer;

  @override
  void initState() {
    super.initState();
    _playback = ref.read(playbackControllerProvider.notifier);
    _playerUi = ref.read(playerUiProvider.notifier);

    // The notifier outlives this page, so opening happens after the first
    // frame — mutating a provider during build is not allowed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Play what the caller resolved, then fill in the rest of its folder so
      // prev/next work — without making the first frame wait on a directory
      // listing that may cross the network.
      _playback.openResolved(widget.media);
      _playback.loadSiblingQueue(widget.media.ref);
    });
    // The picture-in-picture window's own buttons. They run the same methods
    // the on-screen controls do, so the two cannot drift apart.
    _pipControls = ref.read(pipProvider.notifier).controls.listen((control) {
      final settings = ref.read(playerSettingsProvider);
      switch (control) {
        case PipControl.toggle:
          _playback.playOrPause();
        case PipControl.back:
          _playback.skip(-settings.skipBack);
        case PipControl.forward:
          _playback.skip(settings.skipForward);
      }
    });

    // The notification, the lock screen, a headset button, headphones pulled
    // out, a phone call taking audio focus. All of them end up here.
    _notificationCommands =
        ref.read(nowPlayingProvider.notifier).commands.listen((event) {
      switch (event.command) {
        case NowPlayingCommand.play:
          _playback.play();
        case NowPlayingCommand.pause:
          _playback.pause();
        case NowPlayingCommand.next:
          _playback.playNext();
        case NowPlayingCommand.previous:
          _playback.playPrevious();
        case NowPlayingCommand.seek:
          final to = event.position;
          if (to != null) _playback.seek(to);
        case NowPlayingCommand.stop:
          _playback.pause();
          unawaited(ref.read(nowPlayingProvider.notifier).stop());
      }
    });

    _lifecycle = AppLifecycleListener(
      onStateChange: _onLifecycleChanged,
    );

    _restartHideTimer();
  }

  @override
  void dispose() {
    _leftForegroundTimer?.cancel();
    _lifecycle?.dispose();
    unawaited(_notificationCommands?.cancel());
    unawaited(ref.read(nowPlayingProvider.notifier).stop());
    _hideTimer?.cancel();
    _sleepTimer?.cancel();
    unawaited(_pipControls?.cancel());
    // Leaving the screen must not strand a decoder holding the file open, nor
    // a locked orientation on the rest of the app.
    unawaited(_playback.stop());
    _playerUi.reset();
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
    final settings = ref.watch(playerSettingsProvider);
    final controller = ref.read(playbackControllerProvider.notifier);

    // The decoder reports the frame size a moment after opening, which is when
    // "Auto" rotation can finally decide which way up the video wants to be.
    ref.listen(
      playbackControllerProvider.select(
        (s) => (s.stats.width, s.stats.height),
      ),
      (_, size) => _playerUi.followVideoAspect(size.$1, size.$2),
    );

    _syncSleepTimer(ui.sleepTimer);

    // Auto skip intro, opt-in per the design. Driven off the position stream
    // so it fires the moment playback enters the chapter, and only once —
    // seeking back into the intro deliberately should not fight the user.
    ref.listen(
      playbackControllerProvider.select((s) => s.currentIntro?.title),
      (previous, intro) {
        if (intro == null || previous == intro) return;
        if (!ref.read(playerSettingsProvider).autoSkipIntro) return;

        final chapter = ref.read(playbackControllerProvider).currentIntro;
        if (chapter != null) controller.seek(chapter.end);
      },
    );

    final pip = ref.watch(pipProvider);

    // Shape, buttons and — on Android 12+ — whether leaving the app should
    // open the window at all. Sent on every change rather than on the way
    // out, because by then the system has already decided.
    ref.listen(
      playbackControllerProvider.select(
        (s) => (s.playing, s.stats.width, s.stats.height),
      ),
      (_, next) => _syncPip(next.$1, next.$2, next.$3),
    );

    // The notification and the lock screen. Sent on every change; the
    // controller drops the ones that would only move the position along.
    ref.listen(playbackControllerProvider, (_, next) => _syncNowPlaying(next));

    // The television is playing it now; this screen becomes its remote.
    final cast = ref.watch(castControllerProvider);
    if (cast.isCasting) {
      return CastingOverlay(
        device: cast.device!,
        title: state.media?.ref.title ?? widget.media.ref.title,
        status: cast.status,
        onPlayPause: ref.read(castControllerProvider.notifier).playOrPause,
        onSeek: ref.read(castControllerProvider.notifier).seek,
        onStop: () => ref.read(castControllerProvider.notifier).disconnect(),
        onBack: () => context.pop(),
      );
    }

    // A PiP window is a few hundred pixels wide: controls, gestures and
    // overlays would cover the video they are meant to serve.
    if (pip.active) {
      return ColoredBox(
        color: Colors.black,
        child: _VideoSurface(controller: controller, fit: ui.aspect.boxFit),
      );
    }

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
                // Locked ignores everything; the settings switch turns off the
                // brightness and volume drags without locking the screen.
                enabled: !ui.locked,
                gesturesEnabled: settings.swipeGestures,
                state: state,
                onTap: _toggleChrome,
                onSeekBy: controller.skip,
                onSeekTo: controller.seek,
                onVolume: controller.setVolume,
                skipBack: settings.skipBack,
                skipForward: settings.skipForward,
              ),

              if (state.error != null) _ErrorOverlay(message: state.error!),
              // Only where the transport is not already showing one: the
              // controls sit dead centre, and with the chrome up its
              // play/pause slot becomes the spinner instead. Two would
              // overlap, which is what made loading look like a stuck button.
              if (state.buffering &&
                  state.error == null &&
                  (!_chromeVisible || ui.locked))
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
                      onPrevious: () {
                        _restartHideTimer();
                        controller.playPrevious();
                      },
                      onNext: () {
                        _restartHideTimer();
                        controller.playNext();
                      },
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
                      onPip: pip.supported ? _enterPip : null,
                      onCast: _pickCastDevice,
                      // The same amounts the gestures use; the buttons used
                      // to be fixed at 10 and 30 seconds regardless.
                      skipBack: settings.skipBack,
                      skipForward: settings.skipForward,
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
      title: AppLocalizations.of(context).subtitles,
      selectedId: state.activeSubtitle?.id,
      options: <TrackOption>[
        for (final MediaTrack t in state.subtitleTracks)
          TrackOption.fromTrack(t),
      ],
      onSelected: (o) => controller.setSubtitleTrack(o.track),
      action: TrackSheetAction(
        label: AppLocalizations.of(context).openSubtitleFile,
        icon: Icons.subtitles_outlined,
        onTap: () => _openSubtitleFile(controller),
      ),
    );
  }

  /// Picks a subtitle off the device and loads it into the running file.
  ///
  /// Always offered, including for a share or a stream: the file being
  /// played does not have to be the one the subtitle sits beside.
  Future<void> _openSubtitleFile(PlaybackController controller) async {
    _restartHideTimer();

    final file = await ref.read(localSourceProvider).pickSubtitle();
    if (file == null) return;

    await controller.addExternalSubtitle(
      Uri.file(file.path),
      title: file.name,
    );
  }

  Future<void> _pickAudio(
    PlaybackState state,
    PlaybackController controller,
  ) async {
    _restartHideTimer();
    await TrackSheet.show(
      context: context,
      title: AppLocalizations.of(context).audio,
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
      title: AppLocalizations.of(context).playbackSpeed,
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
        SnackBar(content: Text(AppLocalizations.of(context).noChaptersInFile)),
      );
      return;
    }

    await TrackSheet.show(
      context: context,
      title: AppLocalizations.of(context).chapters,
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

  /// Hands the file to a device on the network.
  ///
  /// Local playback is paused rather than stopped: coming back from the
  /// television should carry on where the room left off.
  Future<void> _pickCastDevice() async {
    _restartHideTimer();

    await CastSheet.show(
      context,
      onSelected: (CastDevice device) async {
        final playback = ref.read(playbackControllerProvider);
        final media = playback.media ?? widget.media;
        final from = playback.position;

        await _playback.pause();

        final started = await ref
            .read(castControllerProvider.notifier)
            .castTo(device, media, from: from);

        if (started || !mounted) return;

        final error = ref.read(castControllerProvider).error;
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(error ?? 'Could not cast to that device.')),
        );
      },
    );
  }

  /// Shrinks the app into the picture-in-picture window.
  Future<void> _enterPip() async {
    final state = ref.read(playbackControllerProvider);
    await ref.read(pipProvider.notifier).enter(
          width: state.stats.width,
          height: state.stats.height,
          playing: state.playing,
        );
  }

  /// Keeps the window in step, and arms auto-enter while playing.
  ///
  /// Only while playing: a paused video that shrinks itself when the user
  /// leaves is a window they did not ask for.
  void _syncPip(bool playing, int? width, int? height) {
    unawaited(
      ref.read(pipProvider.notifier).update(
            width: width,
            height: height,
            playing: playing,
            autoEnter: playing && ref.read(playerSettingsProvider).pipOnLeave,
          ),
    );
  }

  /// Publishes what is playing, or takes the notification down when the user
  /// has turned background playback off.
  void _syncNowPlaying(PlaybackState state) {
    final notification = ref.read(nowPlayingProvider.notifier);

    if (!ref.read(playerSettingsProvider).backgroundAudio) {
      if (ref.read(nowPlayingProvider)) unawaited(notification.stop());
      return;
    }

    unawaited(
      notification.update(
        title: state.media?.ref.title ?? widget.media.ref.title,
        subtitle: state.media?.sourceLine ?? widget.media.sourceLine,
        playing: state.playing,
        position: state.position,
        duration: state.duration,
        speed: state.speed,
        hasNext: state.queue.hasNext,
        hasPrevious: state.queue.hasPrevious,
      ),
    );
  }

  /// Pauses when the user leaves, unless they asked for background playback
  /// or the video went into a picture-in-picture window.
  void _onLifecycleChanged(AppLifecycleState lifecycle) {
    _leftForegroundTimer?.cancel();

    if (lifecycle != AppLifecycleState.paused &&
        lifecycle != AppLifecycleState.hidden) {
      return;
    }
    if (ref.read(playerSettingsProvider).backgroundAudio) return;

    // Entering picture in picture reports the same lifecycle change, and
    // which of the two arrives first is not guaranteed — so the decision
    // waits a moment for the window to announce itself.
    _leftForegroundTimer = Timer(const Duration(milliseconds: 400), () {
      if (ref.read(pipProvider).active) return;
      _playback.pause();
    });
  }

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
        controller.skip(-ref.read(playerSettingsProvider).skipBack);
      case LogicalKeyboardKey.arrowRight:
        controller.skip(ref.read(playerSettingsProvider).skipForward);
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
      SnackBar(content: Text(AppLocalizations.of(context).notImplemented(what))),
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
      // libass draws subtitles into the video frame itself, with the styling,
      // positioning and karaoke tags the ASS/SSA file asks for. media_kit's
      // Flutter overlay would paint the same lines again as unstyled text on
      // top, so it has to be off.
      subtitleViewConfiguration: const SubtitleViewConfiguration(
        visible: false,
      ),
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
                        tooltip: AppLocalizations.of(context).locked,
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
