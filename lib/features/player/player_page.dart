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

import '../../app/desktop_window.dart';
import '../../app/system_ui.dart';
import '../../app/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../servers/stream_preferences.dart';
import '../../cast/cast_device.dart';
import '../../sources/media_source.dart';
import '../cast/cast_controller.dart';
import '../cast/cast_sheet.dart';
import '../cast/casting_overlay.dart';
import 'controls_overlay.dart';
import 'gesture_layer.dart';
import 'more_menu.dart';
import 'now_playing.dart';
import 'stable_insets.dart';
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
  const PlayerPage({super.key, required this.media, this.queue});

  /// Already resolved by the caller, so the title and source line are known
  /// before the first frame decodes.
  final PlayableMedia media;

  /// What to play after this, when the caller assembled a list of its own —
  /// a shuffled series, a playlist. Null lets the player work its own queue
  /// out from the folder [media] came from.
  final PlaybackQueue? queue;

  @override
  ConsumerState<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends ConsumerState<PlayerPage> {
  static const _chromeTimeout = Duration(seconds: 3);
  static const _speeds = <double>[0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  bool _chromeVisible = true;
  bool _fullscreen = false;

  /// What was last handed to the platform, so a rebuild does not repeat a
  /// channel call that changes nothing.
  bool _immersiveApplied = false;
  Timer? _hideTimer;
  Timer? _sleepTimer;

  /// Captured in [initState] rather than read in [dispose].
  ///
  /// Touching `ref` while the element is being torn down is not guaranteed to
  /// work, and if it throws, teardown never runs and the decoder keeps
  /// playing behind the popped route.
  late final PlaybackController _playback;
  late final PlayerUiController _playerUi;
  late final NowPlayingController _nowPlaying;

  /// Held for the life of the screen; released on the way out, which hands
  /// the window back to whatever claimed it before.
  late final WindowEdgesClaim _edges;

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
    // Video gets the whole window; every other screen is inset away from
    // the system bars by the wrapper in `app.dart`.
    _edges = claimWindowEdges(WindowEdges.none);

    _playback = ref.read(playbackControllerProvider.notifier);
    _playerUi = ref.read(playerUiProvider.notifier);
    _nowPlaying = ref.read(nowPlayingProvider.notifier);

    // The notifier outlives this page, so opening happens after the first
    // frame — mutating a provider during build is not allowed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Play what the caller resolved, then fill in the rest of its folder so
      // prev/next work — without making the first frame wait on a directory
      // listing that may cross the network.
      final queue = widget.queue;
      _playback.openResolved(widget.media, queue: queue);
      // Only when the caller had no list of its own. Filling in siblings over
      // a queue somebody deliberately assembled would replace it.
      if (queue == null) _playback.loadSiblingQueue(widget.media.ref);
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
    _notificationCommands = _nowPlaying.commands.listen((event) {
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
          unawaited(_nowPlaying.stop());
      }
    });

    _lifecycle = AppLifecycleListener(onStateChange: _onLifecycleChanged);

    _restartHideTimer();
  }

  @override
  void dispose() {
    // Ordered, and each step guarded, because this method used to be a chain:
    // one `ref.read` in the middle of it threw while the element was being
    // torn down, and everything after that line — stopping the decoder,
    // releasing the rotation lock — silently never ran. That is one bug
    // wearing two faces, and it survived being fixed twice at the far end
    // because the far end was never reached. Nothing here may depend on
    // anything above it succeeding.
    //
    // `ref` is not touched at all: every notifier this needs was captured in
    // [initState] for exactly this reason.
    _guard(() => _leftForegroundTimer?.cancel());
    _guard(() => _hideTimer?.cancel());
    _guard(() => _sleepTimer?.cancel());
    _guard(() => _lifecycle?.dispose());
    _guard(() => unawaited(_pipControls?.cancel()));
    _guard(() => unawaited(_notificationCommands?.cancel()));

    // The two that matter most to the user, and so the two that go first
    // among the ones that can fail: a decoder still holding the file is
    // audible, and a stranded orientation lock leaves the whole app sideways.
    _guard(() => unawaited(_playback.stop()));
    _guard(_playerUi.reset);
    _guard(() => unawaited(_nowPlaying.stop()));

    // The rest of the app is not a video player: leaving the bars hidden
    // would strand every screen after this one without a status bar.
    _guard(_edges.release);
    _guard(() => unawaited(restoreAppSystemUi()));

    super.dispose();
  }

  /// Runs one teardown step, reporting a failure rather than letting it stop
  /// the steps that follow.
  void _guard(void Function() step) {
    try {
      step();
    } catch (e) {
      debugPrint('Player teardown step failed: $e');
    }
  }

  void _restartHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(_chromeTimeout, () {
      if (!mounted) return;
      setState(() => _chromeVisible = false);
      _applySystemUi();
    });
  }

  void _toggleChrome() {
    setState(() => _chromeVisible = !_chromeVisible);
    if (_chromeVisible) _restartHideTimer();
    _applySystemUi();
  }

  /// Hides the status and navigation bars along with the chrome.
  ///
  /// One owner for the system bars, so the auto-hide timer and the fullscreen
  /// button cannot disagree about whose turn it is: the bars are away
  /// whenever the chrome is, and stay away while fullscreen is held.
  ///
  /// `immersiveSticky` rather than `immersive`: a swipe brings the bars back
  /// for a moment and they leave again on their own, which is what a video
  /// player wants — `immersive` hands them back permanently on the first
  /// accidental edge swipe.
  void _applySystemUi() {
    if (isDesktop) return;

    final immersive = _fullscreen || !_chromeVisible;
    if (immersive == _immersiveApplied) return;
    _immersiveApplied = immersive;

    // Both sides live in `app/system_ui.dart` now. Coming back is not the
    // mirror image of going away — restoring takes a different platform call
    // from the one that hid the bars — and that asymmetry is exactly what
    // this used to get wrong.
    unawaited(immersive ? enterImmersiveUi() : restoreAppSystemUi());
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
      playbackControllerProvider.select((s) => (s.stats.width, s.stats.height)),
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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // The player is black whatever the app theme is, so the bars drawn over
      // it need light icons. Nothing else on this screen says so: every other
      // screen takes its overlay style from its `AppBar`, and the player has
      // none — so it inherited whatever the previous screen asked for, which
      // under the light theme is dark icons on a black film.
      //
      // `statusBarBrightness` is the iOS spelling and takes the *background's*
      // brightness, which is why the two read as opposites.
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: PopScope(
        // A second net under the teardown, not a replacement for it.
        //
        // This fires while the widget is unambiguously alive, before any of the
        // dispose ordering matters, and pausing is instant and idempotent — so
        // however the route goes away, the audio stops with it. `dispose` still
        // does the real work: releasing the decoder, the session and the
        // rotation lock.
        canPop: true,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) return;
          _playback.pause();
          _edges.release();
          // Here as well as in dispose, for the same reason the pause is: this
          // runs while the widget is unambiguously alive.
          unawaited(restoreAppSystemUi());
        },
        child: Theme(
          // The player is always dark, whatever the app theme is.
          data: ThemeData.dark(useMaterial3: true).copyWith(
            colorScheme: ThemeData.dark(useMaterial3: true).colorScheme
                .copyWith(
                  primaryContainer: const Color(0xFF004C6D),
                  onPrimaryContainer: const Color(0xFFC7E7FF),
                ),
            extensions: Theme.of(context).extensions.values,
          ),
          // Every overlay on this screen, not just the controls.
          //
          // Sticky immersion makes the navigation bar come and go on its own,
          // and Android reports the inset going to full height and back each
          // time. Anything laid out against it moves with it — the control row,
          // the Skip intro pill above that, the locked overlay, the stats
          // panel. Holding the inset still here means none of them can.
          child: StableInsets(
            child: Scaffold(
              backgroundColor: Colors.black,
              body: Focus(
                autofocus: true,
                onKeyEvent: (_, event) => _handleKey(event, controller, ui),
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    _VideoSurface(
                      controller: controller,
                      fit: ui.aspect.boxFit,
                    ),

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

                    if (state.error != null)
                      _ErrorOverlay(message: state.error!),
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
                          // Sticky immersion makes the navigation bar come and go
                          // on its own, and the controls must not move each time
                          // it does.
                          child: StableInsets(
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
                              onScrubStart: (v) =>
                                  setState(() => _dragProgress = v),
                              onScrubUpdate: (v) =>
                                  setState(() => _dragProgress = v),
                              onScrubEnd: (v) {
                                setState(() => _dragProgress = null);
                                controller.seek(state.duration * v);
                              },
                              onSubtitles: () =>
                                  _pickSubtitle(state, controller),
                              onAudio: () => _pickAudio(state, controller),
                              onQuality: () => _pickQuality(state, controller),
                              qualityLabel: () {
                                final q = ref.watch(streamQualityProvider);
                                return q.isOriginal
                                    ? AppLocalizations.of(
                                        context,
                                      ).qualityOriginal
                                    : q.label;
                              }(),
                              onSpeed: () => _pickSpeed(state, controller),
                              onLock: () {
                                ref
                                    .read(playerUiProvider.notifier)
                                    .toggleLock();
                                setState(() => _chromeVisible = false);
                                _applySystemUi();
                              },
                              onRotate: ref
                                  .read(playerUiProvider.notifier)
                                  .cycleRotation,
                              onChapters: () =>
                                  _showChapters(state, controller),
                              onFullscreen: _toggleFullscreen,
                              onMore: () => MoreMenu.show(context),
                              onPip: pip.supported ? _enterPip : null,
                              onCast: _pickCastDevice,
                              // The same amounts the gestures use; the buttons used
                              // to be fixed at 10 and 30 seconds regardless.
                              skipBack: settings.skipBack,
                              skipForward: settings.skipForward,
                              onSkipIntro: (chapter) =>
                                  controller.seek(chapter.end),
                              notImplemented: _notImplemented,
                            ),
                          ),
                        ),
                      ),

                    if (ui.locked) _LockedOverlay(state: state),
                  ],
                ),
              ),
            ),
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

    await controller.addExternalSubtitle(Uri.file(file.path), title: file.name);
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

  Future<void> _pickQuality(
    PlaybackState state,
    PlaybackController controller,
  ) async {
    _restartHideTimer();

    final l10n = AppLocalizations.of(context);
    final current = ref.read(streamQualityProvider);

    await TrackSheet.show(
      context: context,
      title: l10n.playbackQuality,
      selectedId: current.id,
      options: <TrackOption>[
        for (final StreamQuality q in streamQualities)
          TrackOption(
            id: q.id,
            label: q.isOriginal ? l10n.qualityOriginal : q.label,
            detail: q.isOriginal ? l10n.qualityOriginalDetail : null,
          ),
      ],
      onSelected: (option) async {
        // `TrackOption.value` is a double, for the speed sheet it was written
        // for; the id is what carries a quality.
        final chosen = qualityById(option.id);
        if (chosen.id == current.id) return;

        // Read before the await: the film keeps running while the sheet is
        // open, and reopening at a position from ten seconds ago is a visible
        // jump backwards.
        final resume = ref.read(playbackControllerProvider).position;

        await ref.read(streamQualityProvider.notifier).set(chosen);
        // The URL already playing encodes the decision the server made under
        // the old cap, so the new one only takes effect on a fresh resolve.
        await controller.reopenCurrent(at: resume);
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
    await ref
        .read(pipProvider.notifier)
        .enter(
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
      ref
          .read(pipProvider.notifier)
          .update(
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
      // Android and iOS have no OS window to resize; there the button means
      // "keep the bars away", which `_applySystemUi` applies below.
    }

    if (!mounted) return;
    setState(() => _fullscreen = next);
    _applySystemUi();
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
    if (!_chromeVisible) {
      setState(() => _chromeVisible = true);
      _applySystemUi();
    }

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
      SnackBar(
        content: Text(AppLocalizations.of(context).notImplemented(what)),
      ),
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
                      onDoubleTap: ref.read(playerUiProvider.notifier).unlock,
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
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.white,
              size: 44,
            ),
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
