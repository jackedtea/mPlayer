// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/tokens.dart';
import '../../sources/media_source.dart';
import 'playback_state.dart';
import 'player_ui_state.dart';

/// Everything drawn over the video when the chrome is visible.
///
/// Split out of `player_page.dart` so the page is left composing three
/// layers — surface, gestures, chrome — rather than owning 600 lines of
/// buttons.
class ControlsOverlay extends StatelessWidget {
  const ControlsOverlay({
    super.key,
    required this.media,
    required this.state,
    required this.ui,
    required this.dragProgress,
    required this.onInteraction,
    required this.onPlayPause,
    required this.onSkip,
    required this.onPrevious,
    required this.onNext,
    required this.onScrubStart,
    required this.onScrubUpdate,
    required this.onScrubEnd,
    required this.onSubtitles,
    required this.onAudio,
    required this.onQuality,
    required this.onSpeed,
    required this.onLock,
    required this.onRotate,
    required this.onChapters,
    required this.onFullscreen,
    required this.onMore,
    this.onPip,
    required this.onSkipIntro,
    required this.notImplemented,
  });

  final PlayableMedia media;
  final PlaybackState state;
  final PlayerUiState ui;

  /// Non-null while the user drags the scrubber.
  final double? dragProgress;

  final VoidCallback onInteraction;
  final VoidCallback onPlayPause;
  final ValueChanged<Duration> onSkip;

  /// Step to the neighbouring file in the folder.
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  final ValueChanged<double> onScrubStart;
  final ValueChanged<double> onScrubUpdate;
  final ValueChanged<double> onScrubEnd;
  final VoidCallback onSubtitles;
  final VoidCallback onAudio;
  final VoidCallback onQuality;
  final VoidCallback onSpeed;
  final VoidCallback onLock;
  final VoidCallback onRotate;
  final VoidCallback onChapters;
  final VoidCallback onFullscreen;
  final VoidCallback onMore;

  /// Null where the platform has no picture in picture — desktop, and the
  /// Android devices whose manufacturer left it out. The button is hidden
  /// rather than shown reporting that it does nothing.
  final VoidCallback? onPip;
  final ValueChanged<MediaChapter> onSkipIntro;
  final void Function(String) notImplemented;

  @override
  Widget build(BuildContext context) {
    final intro = state.currentIntro;

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        const _Scrim(top: true, opacity: 0.60, height: 140),
        const _Scrim(top: false, opacity: 0.80, height: 210),
        Align(alignment: Alignment.topCenter, child: _TopBar(this_: this)),
        Center(child: _Transport(this_: this)),
        Align(
          alignment: Alignment.bottomCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // Only inside a chapter the source marked as an intro.
              if (intro != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: context.spacing.lg,
                      bottom: context.spacing.sm,
                    ),
                    child: _SkipIntroPill(onTap: () => onSkipIntro(intro)),
                  ),
                ),
              _BottomBar(this_: this),
            ],
          ),
        ),
      ],
    );
  }
}

class _Scrim extends StatelessWidget {
  const _Scrim({required this.top, required this.opacity, required this.height});

  final bool top;
  final double opacity;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: top ? Alignment.topCenter : Alignment.bottomCenter,
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
  const _TopBar({required this.this_});

  final ControlsOverlay this_;

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
                this_.onInteraction();
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
                    this_.media.title,
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
                        this_.media.kind.icon,
                        size: 13,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          this_.media.sourceLine,
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
            if (this_.onPip != null)
              IconButton(
                icon: const Icon(Icons.picture_in_picture_alt_rounded),
                color: Colors.white,
                tooltip: 'Picture in picture',
                onPressed: this_.onPip,
              ),
            IconButton(
              icon: const Icon(Icons.cast_rounded),
              color: Colors.white,
              tooltip: 'Cast',
              onPressed: () => this_.notImplemented('Cast'),
            ),
            IconButton(
              icon: const Icon(Icons.more_vert_rounded),
              color: Colors.white,
              tooltip: 'More',
              onPressed: this_.onMore,
            ),
          ],
        ),
      ),
    );
  }
}

class _Transport extends StatelessWidget {
  const _Transport({required this.this_});

  final ControlsOverlay this_;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    final queue = this_.state.queue;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        // Only when the file came from a folder holding others — a lone video
        // should not show dead controls. The design's centre row is three
        // buttons because its frames show a single item; stepping through a
        // folder is what `skip_next` in its icon inventory is for.
        if (queue.hasSiblings) ...<Widget>[
          CircleButton(
            icon: Icons.skip_previous_rounded,
            size: 48,
            iconSize: 26,
            background: Colors.white.withValues(alpha: 0.12),
            foreground: queue.hasPrevious
                ? Colors.white
                : Colors.white.withValues(alpha: 0.3),
            tooltip: 'Previous',
            onPressed: queue.hasPrevious ? this_.onPrevious : null,
          ),
          const SizedBox(width: 16),
        ],
        CircleButton(
          icon: Icons.replay_10_rounded,
          size: 56,
          iconSize: 28,
          background: Colors.white.withValues(alpha: 0.12),
          foreground: Colors.white,
          tooltip: 'Back 10 seconds',
          onPressed: () {
            this_.onInteraction();
            this_.onSkip(const Duration(seconds: -10));
          },
        ),
        const SizedBox(width: 28),
        CircleButton(
          // Fill is reserved for play/pause and the selected destination.
          icon: this_.state.playing
              ? Icons.pause_rounded
              : Icons.play_arrow_rounded,
          size: 80,
          iconSize: 42,
          background: scheme.primaryContainer,
          foreground: scheme.onPrimaryContainer,
          tooltip: this_.state.playing ? 'Pause' : 'Play',
          onPressed: this_.onPlayPause,
        ),
        const SizedBox(width: 28),
        CircleButton(
          icon: Icons.forward_30_rounded,
          size: 56,
          iconSize: 28,
          background: Colors.white.withValues(alpha: 0.12),
          foreground: Colors.white,
          tooltip: 'Forward 30 seconds',
          onPressed: () {
            this_.onInteraction();
            this_.onSkip(const Duration(seconds: 30));
          },
        ),
        if (queue.hasSiblings) ...<Widget>[
          const SizedBox(width: 16),
          CircleButton(
            icon: Icons.skip_next_rounded,
            size: 48,
            iconSize: 26,
            background: Colors.white.withValues(alpha: 0.12),
            foreground: queue.hasNext
                ? Colors.white
                : Colors.white.withValues(alpha: 0.3),
            tooltip: 'Next',
            onPressed: queue.hasNext ? this_.onNext : null,
          ),
        ],
      ],
    );
  }
}

class _SkipIntroPill extends StatelessWidget {
  const _SkipIntroPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 40,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Skip intro',
            style: TextStyle(
              color: context.colors.onPrimaryContainer,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.this_});

  final ControlsOverlay this_;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final state = this_.state;
    final value = this_.dragProgress ?? state.progress;
    final shown = state.duration * value;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(spacing.lg, 0, spacing.lg, spacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _Scrubber(
              value: value,
              duration: state.duration,
              chapters: state.chapters,
              onStart: this_.onScrubStart,
              onUpdate: this_.onScrubUpdate,
              onEnd: this_.onScrubEnd,
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
            SizedBox(height: spacing.sm),
            _ControlRow(this_: this_),
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

/// Slider plus chapter ticks. The ticks are painted behind the slider so the
/// thumb and the active track still read on top of them.
class _Scrubber extends StatelessWidget {
  const _Scrubber({
    required this.value,
    required this.duration,
    required this.chapters,
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
  });

  final double value;
  final Duration duration;
  final List<MediaChapter> chapters;
  final ValueChanged<double> onStart;
  final ValueChanged<double> onUpdate;
  final ValueChanged<double> onEnd;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return SizedBox(
      height: 32,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          if (chapters.isNotEmpty && duration > Duration.zero)
            Positioned.fill(
              child: IgnorePointer(
                child: Padding(
                  // Line the ticks up with the slider's usable track, which
                  // is inset by the thumb radius at both ends.
                  padding: const EdgeInsets.symmetric(horizontal: 7),
                  child: CustomPaint(
                    painter: _ChapterTicks(
                      chapters: chapters,
                      duration: duration,
                    ),
                  ),
                ),
              ),
            ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              activeTrackColor: scheme.primaryContainer,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.30),
              thumbColor: scheme.primaryContainer,
              overlayColor: scheme.primaryContainer.withValues(alpha: 0.24),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 13),
            ),
            child: Slider(
              value: value.clamp(0.0, 1.0),
              onChanged: duration > Duration.zero ? onUpdate : null,
              onChangeStart: onStart,
              onChangeEnd: onEnd,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChapterTicks extends CustomPainter {
  _ChapterTicks({required this.chapters, required this.duration});

  final List<MediaChapter> chapters;
  final Duration duration;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.55);
    final total = duration.inMilliseconds;
    if (total <= 0) return;

    for (final MediaChapter chapter in chapters) {
      // A tick at zero would sit under the thumb's start position and read
      // as a glitch rather than a marker.
      if (chapter.start <= Duration.zero) continue;
      final x = size.width * (chapter.start.inMilliseconds / total);
      canvas.drawRect(
        Rect.fromLTWH(x - 1, (size.height - 10) / 2, 2, 10),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ChapterTicks old) =>
      old.duration != duration || old.chapters != chapters;
}

/// Track pills on the left, the four icon buttons on the right.
///
/// The design draws these as one row, which it can: its player frames are
/// landscape. In portrait on a phone the four 44pt buttons leave the pills
/// almost no width and the two groups collide, so below [_twoRowBelow] they
/// stack instead — pills first, buttons under them.
class _ControlRow extends StatelessWidget {
  const _ControlRow({required this.this_});

  final ControlsOverlay this_;

  /// Four icon buttons (176) plus enough room for two readable pills.
  static const _twoRowBelow = 480.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= _twoRowBelow) {
          return Row(
            children: <Widget>[
              Expanded(child: _pills(context)),
              ..._icons(),
            ],
          );
        }

        // Portrait on a phone: labelled pills and four icon buttons cannot
        // share a row, so the track controls drop their labels and join the
        // others as icons. The label's information is not lost — each sheet
        // still names the current selection, and the icons themselves carry
        // the state worth seeing at a glance.
        //
        // Seven or eight buttons at their natural 44pt overrun a 320pt phone,
        // so they share the row equally instead: the tight width an [Expanded]
        // hands down overrides the button's own, shrinking the touch target
        // rather than pushing a control off-screen where it cannot be reached
        // at all.
        return Row(
          children: <Widget>[
            for (final button in <Widget>[..._trackIcons(context), ..._icons()])
              Expanded(child: button),
          ],
        );
      },
    );
  }

  /// The pills, reduced to icons.
  List<Widget> _trackIcons(BuildContext context) {
    final state = this_.state;
    final accent = context.colors.primaryContainer;
    final subtitleOn = state.activeSubtitle?.isOff == false;
    final speedChanged = (state.speed - 1.0).abs() > 0.01;

    return <Widget>[
      _SmallIcon(
        // Off is worth seeing without opening the sheet, so the glyph says so.
        icon: subtitleOn
            ? Icons.subtitles_rounded
            : Icons.subtitles_off_rounded,
        tooltip: 'Subtitles: ${state.activeSubtitle?.label ?? 'Off'}',
        colour: subtitleOn ? accent : null,
        onTap: this_.onSubtitles,
      ),
      _SmallIcon(
        icon: Icons.graphic_eq_rounded,
        tooltip: 'Audio: ${state.activeAudio?.label ?? 'Default'}',
        onTap: this_.onAudio,
      ),
      if (this_.media.capabilities.transcoding)
        _SmallIcon(
          icon: Icons.hd_rounded,
          tooltip: 'Quality',
          onTap: this_.onQuality,
        ),
      _SmallIcon(
        icon: Icons.speed_rounded,
        // Playing at anything but normal speed is easy to forget and hard to
        // notice; the tint is the only cue left once the label is gone.
        tooltip: 'Speed: ${state.speed.toStringAsFixed(2)}×',
        colour: speedChanged ? accent : null,
        onTap: this_.onSpeed,
      ),
    ];
  }

  Widget _pills(BuildContext context) {
    final state = this_.state;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          _Pill(
            icon: Icons.subtitles_rounded,
            label: state.activeSubtitle?.label ?? 'Off',
            onTap: this_.onSubtitles,
          ),
          _Pill(
            icon: Icons.graphic_eq_rounded,
            label: state.activeAudio?.label ?? 'Default',
            onTap: this_.onAudio,
          ),
          // Quality only means something when the far end can re-encode.
          // A local file, a share or a WebDAV stream is served as-is, so the
          // pill would open a sheet with exactly one choice in it.
          if (this_.media.capabilities.transcoding)
            _Pill(
              icon: Icons.hd_rounded,
              label: 'Original',
              onTap: this_.onQuality,
            ),
          _Pill(
            icon: Icons.speed_rounded,
            label: '${state.speed.toStringAsFixed(1)}×',
            onTap: this_.onSpeed,
          ),
        ],
      ),
    );
  }

  List<Widget> _icons() {
    final ui = this_.ui;

    return <Widget>[
      _SmallIcon(
        icon: ui.locked ? Icons.lock_rounded : Icons.lock_open_rounded,
        tooltip: 'Lock player',
        onTap: this_.onLock,
      ),
      _SmallIcon(
        icon: ui.rotation.icon,
        tooltip: 'Rotation: ${ui.rotation.label}',
        onTap: this_.onRotate,
      ),
      _SmallIcon(
        icon: Icons.segment_rounded,
        tooltip: 'Chapters',
        onTap: this_.onChapters,
      ),
      _SmallIcon(
        icon: Icons.fullscreen_rounded,
        tooltip: 'Fullscreen',
        onTap: this_.onFullscreen,
      ),
    ];
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(icon, size: 16, color: Colors.white),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 130),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
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
}

class _SmallIcon extends StatelessWidget {
  const _SmallIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.colour,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  /// Tints the glyph to carry state the label used to. Null means plain white.
  final Color? colour;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon),
      iconSize: 22,
      color: colour ?? Colors.white,
      tooltip: tooltip,
      onPressed: onTap,
      constraints: const BoxConstraints.tightFor(width: 44, height: 44),
      padding: EdgeInsets.zero,
    );
  }
}

/// Round translucent button, shared by the transport row and the lock state.
class CircleButton extends StatelessWidget {
  const CircleButton({
    super.key,
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

  /// Null renders the button inert rather than removing it, so the transport
  /// row keeps its shape at the ends of a playlist.
  final VoidCallback? onPressed;

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
