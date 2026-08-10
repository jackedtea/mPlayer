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

import '../../app/tokens.dart';
import '../../sources/media_source.dart';
import 'playback_controller.dart';
import 'playback_state.dart';

/// Screen 1h — the single player, shared by local files, shares and streams.
///
/// Build step 2 scope: the video surface, transport controls and the scrubber,
/// which is what "a device file playing end to end" needs. The rest of the 1h
/// chrome — gestures, lock, rotation, track/quality sheets, chapter ticks,
/// skip-intro and the stats overlay — is build step 3 and is deliberately
/// absent rather than stubbed.
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

  bool _chromeVisible = true;
  Timer? _hideTimer;

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
    // Leaving the screen must not strand a decoder holding the file open.
    unawaited(ref.read(playbackControllerProvider.notifier).stop());
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
    final controller = ref.read(playbackControllerProvider.notifier);

    return Theme(
      // The player is always dark, whatever the app theme is.
      data: ThemeData.dark(useMaterial3: true).copyWith(
        extensions: Theme.of(context).extensions.values,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Focus(
          autofocus: true,
          onKeyEvent: (_, event) => _handleKey(event, controller),
          child: GestureDetector(
            onTap: _toggleChrome,
            behavior: HitTestBehavior.opaque,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                _VideoSurface(controller: controller),
                if (state.error != null) _ErrorOverlay(message: state.error!),
                if (state.buffering && state.error == null)
                  const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                AnimatedOpacity(
                  opacity: _chromeVisible ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: IgnorePointer(
                    ignoring: !_chromeVisible,
                    child: _Chrome(
                      media: widget.media,
                      state: state,
                      controller: controller,
                      dragProgress: _dragProgress,
                      onInteraction: _restartHideTimer,
                      onDragStart: (v) => setState(() => _dragProgress = v),
                      onDragUpdate: (v) => setState(() => _dragProgress = v),
                      onDragEnd: (v) {
                        setState(() => _dragProgress = null);
                        controller.seek(state.duration * v);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Desktop keyboard transport. Space/K toggle, arrows seek, Escape leaves.
  KeyEventResult _handleKey(KeyEvent event, PlaybackController controller) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
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
      case LogicalKeyboardKey.escape:
        if (context.canPop()) context.pop();
      default:
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }
}

class _VideoSurface extends StatelessWidget {
  const _VideoSurface({required this.controller});

  final PlaybackController controller;

  @override
  Widget build(BuildContext context) {
    final videoController = controller.videoController;
    if (videoController == null) {
      return const ColoredBox(color: Colors.black);
    }
    return Video(
      controller: videoController,
      controls: NoVideoControls,
      fill: Colors.black,
    );
  }
}

class _Chrome extends StatelessWidget {
  const _Chrome({
    required this.media,
    required this.state,
    required this.controller,
    required this.dragProgress,
    required this.onInteraction,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  final PlayableMedia media;
  final PlaybackState state;
  final PlaybackController controller;
  final double? dragProgress;
  final VoidCallback onInteraction;
  final ValueChanged<double> onDragStart;
  final ValueChanged<double> onDragUpdate;
  final ValueChanged<double> onDragEnd;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        // Top scrim: rgba(0,0,0,.60) to transparent.
        const _Scrim(alignment: Alignment.topCenter, opacity: 0.60, height: 140),
        const _Scrim(
          alignment: Alignment.bottomCenter,
          opacity: 0.80,
          height: 190,
        ),
        Align(
          alignment: Alignment.topCenter,
          child: _TopBar(media: media, onInteraction: onInteraction),
        ),
        Center(
          child: _TransportRow(
            state: state,
            controller: controller,
            onInteraction: onInteraction,
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: _Scrubber(
            state: state,
            dragProgress: dragProgress,
            onDragStart: onDragStart,
            onDragUpdate: onDragUpdate,
            onDragEnd: onDragEnd,
          ),
        ),
      ],
    );
  }
}

class _Scrim extends StatelessWidget {
  const _Scrim({
    required this.alignment,
    required this.opacity,
    required this.height,
  });

  final Alignment alignment;
  final double opacity;
  final double height;

  @override
  Widget build(BuildContext context) {
    final top = alignment == Alignment.topCenter;
    return Align(
      alignment: alignment,
      child: IgnorePointer(
        child: Container(
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: top ? Alignment.topCenter : Alignment.bottomCenter,
              end: top ? Alignment.bottomCenter : Alignment.topCenter,
              colors: <Color>[
                Colors.black.withValues(alpha: opacity),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.media, required this.onInteraction});

  final PlayableMedia media;
  final VoidCallback onInteraction;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: spacing.sm),
        child: Row(
          children: <Widget>[
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              color: Colors.white,
              tooltip: 'Back',
              onPressed: () {
                onInteraction();
                if (context.canPop()) context.pop();
              },
            ),
            SizedBox(width: spacing.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    media.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Row(
                    children: <Widget>[
                      Icon(
                        media.kind.icon,
                        size: 13,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          media.sourceLine,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransportRow extends StatelessWidget {
  const _TransportRow({
    required this.state,
    required this.controller,
    required this.onInteraction,
  });

  final PlaybackState state;
  final PlaybackController controller;
  final VoidCallback onInteraction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        _CircleButton(
          icon: Icons.replay_10_rounded,
          size: 56,
          iconSize: 28,
          background: Colors.white.withValues(alpha: 0.12),
          foreground: Colors.white,
          tooltip: 'Back 10 seconds',
          onPressed: () {
            onInteraction();
            controller.skip(const Duration(seconds: -10));
          },
        ),
        const SizedBox(width: 28),
        _CircleButton(
          // Fill is reserved for play/pause and the selected nav destination.
          icon: state.playing
              ? Icons.pause_rounded
              : Icons.play_arrow_rounded,
          size: 80,
          iconSize: 42,
          background: scheme.primaryContainer,
          foreground: scheme.onPrimaryContainer,
          tooltip: state.playing ? 'Pause' : 'Play',
          onPressed: () {
            onInteraction();
            controller.playOrPause();
          },
        ),
        const SizedBox(width: 28),
        _CircleButton(
          icon: Icons.forward_30_rounded,
          size: 56,
          iconSize: 28,
          background: Colors.white.withValues(alpha: 0.12),
          foreground: Colors.white,
          tooltip: 'Forward 30 seconds',
          onPressed: () {
            onInteraction();
            controller.skip(const Duration(seconds: 30));
          },
        ),
      ],
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.size,
    required this.iconSize,
    required this.background,
    required this.foreground,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final double size;
  final double iconSize;
  final Color background;
  final Color foreground;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: background,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, size: iconSize, color: foreground),
          ),
        ),
      ),
    );
  }
}

class _Scrubber extends StatelessWidget {
  const _Scrubber({
    required this.state,
    required this.dragProgress,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  final PlaybackState state;
  final double? dragProgress;
  final ValueChanged<double> onDragStart;
  final ValueChanged<double> onDragUpdate;
  final ValueChanged<double> onDragEnd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final spacing = context.spacing;
    final value = dragProgress ?? state.progress;

    // While dragging, the times track the finger so the user can see where
    // they are about to land.
    final shown = state.duration * value;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          spacing.lg,
          0,
          spacing.lg,
          spacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                activeTrackColor: scheme.primaryContainer,
                inactiveTrackColor: Colors.white.withValues(alpha: 0.30),
                thumbColor: scheme.primaryContainer,
                overlayColor: scheme.primaryContainer.withValues(alpha: 0.24),
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 7,
                ),
                overlayShape: const RoundSliderOverlayShape(
                  overlayRadius: 13,
                ),
              ),
              child: Slider(
                value: value.clamp(0.0, 1.0),
                // Disabled until the duration is known, or the thumb would
                // sit at 0 and swallow drags.
                onChanged: state.duration > Duration.zero ? onDragUpdate : null,
                onChangeStart: onDragStart,
                onChangeEnd: onDragEnd,
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: spacing.sm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(formatDuration(shown), style: _timeStyle),
                  Text(
                    '-${formatDuration(state.duration - shown)}',
                    style: _timeStyle,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const _timeStyle = TextStyle(
    color: Colors.white,
    fontSize: 12,
    fontWeight: FontWeight.w500,
  );
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
