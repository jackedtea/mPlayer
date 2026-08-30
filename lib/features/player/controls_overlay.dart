// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../servers/media_library_source.dart';
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
    this.qualityLabel,
    required this.onSpeed,
    required this.onLock,
    required this.onRotate,
    required this.onChapters,
    required this.onFullscreen,
    required this.onMore,
    this.onPip,
    this.onCast,
    this.skipBack = const Duration(seconds: 10),
    this.skipForward = const Duration(seconds: 30),
    required this.onSkipIntro,
    this.skipSegment,
    required this.onSkipSegment,
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

  /// What the quality pill reads. Null falls back to "Original", which is
  /// also the default the setting starts on.
  final String? qualityLabel;
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

  /// Null while nothing can be cast to — the button would otherwise open a
  /// picker that can never fill.
  final VoidCallback? onCast;
  final ValueChanged<MediaChapter> onSkipIntro;

  /// The stretch the viewer is being *offered* a way past, or null.
  ///
  /// Already filtered by the page against the user's per-kind setting: a
  /// segment set to skip itself never reaches here, and one set to be left
  /// alone never had a pill to begin with.
  final MediaSegment? skipSegment;

  final ValueChanged<MediaSegment> onSkipSegment;
  final void Function(String) notImplemented;

  /// The amounts from Player settings. The transport buttons used to be fixed
  /// at 10 and 30 seconds, which quietly ignored the setting the gestures
  /// were already honouring — so the two disagreed about what a skip was.
  final Duration skipBack;
  final Duration skipForward;

  @override
  Widget build(BuildContext context) {
    final intro = state.currentIntro;
    final segment = skipSegment;
    final trickplay = media.trickplay;

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
              // Only while the scrubber is being dragged, and only where the
              // server generated the sheets to draw from.
              if (trickplay != null &&
                  dragProgress != null &&
                  state.duration > Duration.zero)
                _TrickplayStrip(
                  trickplay: trickplay,
                  position: state.duration * dragProgress!,
                  chapter: state.chapterAt(state.duration * dragProgress!),
                  // The thumb travels the full width, so the preview lines up
                  // with it by riding the same fraction and clamping itself
                  // at the ends.
                  fraction: dragProgress!,
                ),

              // A segment the server labelled wins over a chapter the
              // container merely named; `currentIntro` already stands down
              // when there are segments, so at most one of these is non-null.
              if (segment != null)
                _PillSlot(
                  child: _SkipPill(
                    label: _segmentLabel(context, segment.kind),
                    onTap: () => onSkipSegment(segment),
                  ),
                )
              else if (intro != null)
                _PillSlot(
                  child: _SkipPill(
                    label: AppLocalizations.of(context).skipIntro,
                    onTap: () => onSkipIntro(intro),
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

/// What the pill for a segment reads.
///
/// "Skip credits" rather than "Skip outro": nobody watching a film calls the
/// closing titles an outro, and the wire name is the server's vocabulary,
/// not the viewer's.
String _segmentLabel(BuildContext context, MediaSegmentKind kind) {
  final l10n = AppLocalizations.of(context);
  return switch (kind) {
    MediaSegmentKind.intro => l10n.skipIntro,
    MediaSegmentKind.outro => l10n.skipCredits,
    MediaSegmentKind.recap => l10n.skipRecap,
    MediaSegmentKind.preview => l10n.skipPreview,
    MediaSegmentKind.commercial => l10n.skipAdvert,
    // Never reached: an unknown kind is dropped while parsing rather than
    // carried this far.
    MediaSegmentKind.unknown => l10n.skipIntro,
  };
}

/// Where every skip pill sits: bottom right, clear of the scrubber.
class _PillSlot extends StatelessWidget {
  const _PillSlot({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: EdgeInsets.only(
          right: context.spacing.lg,
          bottom: context.spacing.sm,
        ),
        child: child,
      ),
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
              tooltip: AppLocalizations.of(context).actionBack,
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
                tooltip: AppLocalizations.of(context).pictureInPicture,
                onPressed: this_.onPip,
              ),
            if (this_.onCast != null)
              IconButton(
                icon: const Icon(Icons.cast_rounded),
                color: Colors.white,
                tooltip: AppLocalizations.of(context).castTo,
                onPressed: this_.onCast,
              ),
            IconButton(
              icon: const Icon(Icons.more_vert_rounded),
              color: Colors.white,
              tooltip: AppLocalizations.of(context).actionMore,
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
            tooltip: AppLocalizations.of(context).previousFile,
            onPressed: queue.hasPrevious ? this_.onPrevious : null,
          ),
          const SizedBox(width: 16),
        ],
        CircleButton(
          icon: _replayIcon(this_.skipBack),
          size: 56,
          iconSize: 28,
          background: Colors.white.withValues(alpha: 0.12),
          foreground: Colors.white,
          tooltip: AppLocalizations.of(context)
              .back10(this_.skipBack.inSeconds),
          onPressed: () {
            this_.onInteraction();
            this_.onSkip(-this_.skipBack);
          },
        ),
        const SizedBox(width: 28),
        if (this_.state.buffering && this_.state.error == null)
          const _TransportSpinner(size: 80)
        else
          CircleButton(
            icon: this_.state.playing
                ? Icons.pause_rounded
                : Icons.play_arrow_rounded,
            size: 80,
            iconSize: 42,
            // No fill: the glyph carries the control on its own, and at 42pt
            // over a scrimmed frame it reads without a disc behind it. The
            // ink ripple still lands, since the Material is only transparent,
            // not absent.
            background: Colors.transparent,
            foreground: Colors.white,
            tooltip: this_.state.playing
                ? AppLocalizations.of(context).pause
                : AppLocalizations.of(context).play,
            onPressed: this_.onPlayPause,
          ),
        const SizedBox(width: 28),
        CircleButton(
          icon: _forwardIcon(this_.skipForward),
          size: 56,
          iconSize: 28,
          background: Colors.white.withValues(alpha: 0.12),
          foreground: Colors.white,
          tooltip: AppLocalizations.of(context)
              .forward30(this_.skipForward.inSeconds),
          onPressed: () {
            this_.onInteraction();
            this_.onSkip(this_.skipForward);
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
            tooltip: AppLocalizations.of(context).nextFile,
            onPressed: queue.hasNext ? this_.onNext : null,
          ),
        ],
      ],
    );
  }
}

/// Stands in for play/pause while the file is still loading.
///
/// The transport sits dead centre, which is also where the page draws its
/// buffering indicator — so with the chrome up the 80pt button covered the
/// spinner completely and loading looked like a dead button. Showing the
/// progress *in* the slot is what the page then defers to.
///
/// Same footprint as the button it replaces, so the row does not jump when
/// playback starts.
class _TransportSpinner extends StatelessWidget {
  const _TransportSpinner({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: AppLocalizations.of(context).loading,
      child: SizedBox(
        width: size,
        height: size,
        child: Center(
          child: SizedBox(
            // Smaller than the slot it stands in: a ring at the button's full
            // width would read as a border rather than as progress.
            width: size * 0.45,
            height: size * 0.45,
            child: const CircularProgressIndicator(
              strokeWidth: 3,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _SkipPill extends StatelessWidget {
  const _SkipPill({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        // **No alignment, and no fixed height.** A Container given either one
        // expands to fill the constraints it is handed, which is what turned
        // this pill into a bar across the whole screen. Padding around the
        // text is the only thing that should size it.
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          // A semantic token, not `onPrimaryContainer`: the pill's surface is
          // white whatever the theme is, so the scheme role went pale blue in
          // the dark theme — and anywhere at all under a custom accent — and
          // left the label barely readable on it.
          child: Text(
            label,
            style: TextStyle(
              color: context.semantic.onPlayerPill,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}


/// The frame under the scrubber while it is being dragged.
///
/// A server generates these as **sprite sheets** — one image holding a
/// hundred thumbnails — so a scrub across a two-hour film costs a handful of
/// requests instead of a thousand. The cost of that is that the frame wanted
/// is a rectangle inside a much larger picture, which is why this paints
/// through a canvas rather than showing an `Image`: there is no widget that
/// crops a source rect without first laying the whole sheet out.
class _TrickplayStrip extends StatelessWidget {
  const _TrickplayStrip({
    required this.trickplay,
    required this.position,
    required this.chapter,
    required this.fraction,
  });

  final ServerTrickplay trickplay;
  final Duration position;
  final MediaChapter? chapter;

  /// 0..1 along the scrubber, which is where the thumb is.
  final double fraction;

  /// Tall enough to read a face in, short enough to leave the film visible.
  static const _height = 84.0;

  @override
  Widget build(BuildContext context) {
    final tile = trickplay.tileFor(position);
    if (tile == null) return const SizedBox.shrink();

    final width = _height * trickplay.width / trickplay.height;

    return Padding(
      // The same inset the scrubber's own track sits at, so the preview and
      // the thumb agree about where the ends are.
      padding: EdgeInsets.symmetric(horizontal: context.spacing.lg + 7),
      child: SizedBox(
        height: _height + 26,
        width: double.infinity,
        child: Align(
          // `Alignment` runs -1..1 and clamps at the edges by itself, which
          // is exactly the behaviour wanted at the ends of the film.
          alignment: Alignment(fraction * 2 - 1, 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(context.radii.thumb),
                child: Container(
                  width: width,
                  height: _height,
                  color: Colors.black,
                  child: _TrickplayTileImage(tile: tile),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                // The chapter name earns its place here: it is the one label
                // that says *what* is at this position rather than when.
                chapter == null
                    ? formatDuration(position)
                    : '${formatDuration(position)} · ${chapter!.title}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  shadows: <Shadow>[Shadow(blurRadius: 4)],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Loads one sheet and paints the single frame wanted out of it.
///
/// The sheet is held across rebuilds and only re-fetched when the tile index
/// changes, so dragging within one sheet — a hundred thumbnails, minutes of
/// film — costs nothing after the first frame.
class _TrickplayTileImage extends StatefulWidget {
  const _TrickplayTileImage({required this.tile});

  final TrickplayTile tile;

  @override
  State<_TrickplayTileImage> createState() => _TrickplayTileImageState();
}

class _TrickplayTileImageState extends State<_TrickplayTileImage> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  ui.Image? _sheet;
  Uri? _loaded;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(_TrickplayTileImage old) {
    super.didUpdateWidget(old);
    if (old.tile.url != widget.tile.url) _resolve();
  }

  void _resolve() {
    if (_loaded == widget.tile.url) return;
    _loaded = widget.tile.url;

    _detach();

    final stream = NetworkImage(widget.tile.url.toString())
        .resolve(createLocalImageConfiguration(context));
    final listener = ImageStreamListener(
      (image, _) {
        if (!mounted) {
          image.image.dispose();
          return;
        }
        setState(() {
          _sheet?.dispose();
          _sheet = image.image;
        });
      },
      // A sheet that will not load leaves the last frame on screen rather
      // than flashing a placeholder; the scrub itself still works.
      onError: (_, _) {},
    );

    _stream = stream..addListener(listener);
    _listener = listener;
  }

  void _detach() {
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
    _stream = null;
    _listener = null;
  }

  @override
  void dispose() {
    _detach();
    _sheet?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sheet = _sheet;
    if (sheet == null) return const SizedBox.expand();

    return CustomPaint(
      painter: _TrickplayTilePainter(sheet: sheet, tile: widget.tile),
      size: Size.infinite,
    );
  }
}

class _TrickplayTilePainter extends CustomPainter {
  _TrickplayTilePainter({required this.sheet, required this.tile});

  final ui.Image sheet;
  final TrickplayTile tile;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(
      sheet,
      Rect.fromLTWH(
        tile.left.toDouble(),
        tile.top.toDouble(),
        tile.width.toDouble(),
        tile.height.toDouble(),
      ),
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(_TrickplayTilePainter old) =>
      old.sheet != sheet || old.tile != tile;
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
              // How far ahead the decoder has read. Zero for a local file,
              // where there is nothing to wait for and nothing to show.
              buffered: state.duration > Duration.zero
                  ? state.buffered.inMilliseconds /
                      state.duration.inMilliseconds
                  : 0,
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
    required this.buffered,
    required this.duration,
    required this.chapters,
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
  });

  final double value;

  /// 0..1 of the file that has been read ahead.
  final double buffered;

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
          // Behind the slider, and above the chapter ticks: the buffered
          // stretch is context for the track, not a control, so the thumb and
          // the played portion both draw over it.
          if (buffered > 0.001 && duration > Duration.zero)
            Positioned.fill(
              child: IgnorePointer(
                child: Padding(
                  // The same inset the ticks use — the slider's usable track
                  // is shortened by the thumb radius at each end.
                  padding: const EdgeInsets.symmetric(horizontal: 7),
                  child: CustomPaint(
                    painter: _BufferedTrack(
                      progress: buffered.clamp(0.0, 1.0),
                      colour: Colors.white.withValues(alpha: 0.45),
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

/// The read-ahead stretch, drawn as a dimmer version of the played track.
class _BufferedTrack extends CustomPainter {
  _BufferedTrack({required this.progress, required this.colour});

  final double progress;
  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    // 4 logical pixels, matching `trackHeight`, and rounded at both ends the
    // way Material draws the track itself.
    const height = 4.0;
    final top = (size.height - height) / 2;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, top, size.width * progress, height),
        const Radius.circular(height / 2),
      ),
      Paint()..color = colour,
    );
  }

  @override
  bool shouldRepaint(_BufferedTrack old) =>
      old.progress != progress || old.colour != colour;
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
              ..._icons(context),
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
            for (final button
                in <Widget>[..._trackIcons(context), ..._icons(context)])
              Expanded(child: button),
          ],
        );
      },
    );
  }

  /// The pills, reduced to icons.
  List<Widget> _trackIcons(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
        tooltip: l10n.subtitlesValue(state.activeSubtitle?.label ?? l10n.off),
        colour: subtitleOn ? accent : null,
        onTap: this_.onSubtitles,
      ),
      _SmallIcon(
        icon: Icons.graphic_eq_rounded,
        tooltip:
            l10n.audioValue(state.activeAudio?.label ?? l10n.defaultLabel),
        onTap: this_.onAudio,
      ),
      if (this_.media.capabilities.transcoding)
        _SmallIcon(
          icon: Icons.hd_rounded,
          tooltip: l10n.quality,
          onTap: this_.onQuality,
        ),
      _SmallIcon(
        icon: Icons.speed_rounded,
        // Playing at anything but normal speed is easy to forget and hard to
        // notice; the tint is the only cue left once the label is gone.
        tooltip: l10n.speedValue(state.speed.toStringAsFixed(2)),
        colour: speedChanged ? accent : null,
        onTap: this_.onSpeed,
      ),
    ];
  }

  Widget _pills(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = this_.state;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          _Pill(
            icon: Icons.subtitles_rounded,
            label: state.activeSubtitle?.label ?? l10n.off,
            onTap: this_.onSubtitles,
          ),
          _Pill(
            icon: Icons.graphic_eq_rounded,
            label: state.activeAudio?.label ?? l10n.defaultLabel,
            onTap: this_.onAudio,
          ),
          // Quality only means something when the far end can re-encode.
          // A local file, a share or a WebDAV stream is served as-is, so the
          // pill would open a sheet with exactly one choice in it.
          if (this_.media.capabilities.transcoding)
            _Pill(
              icon: Icons.hd_rounded,
              label: this_.qualityLabel ?? l10n.original,
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

  List<Widget> _icons(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ui = this_.ui;

    return <Widget>[
      _SmallIcon(
        icon: ui.locked ? Icons.lock_rounded : Icons.lock_open_rounded,
        tooltip: l10n.lockPlayer,
        onTap: this_.onLock,
      ),
      _SmallIcon(
        icon: ui.rotation.icon,
        tooltip: l10n.rotationValue(ui.rotation.label(l10n)),
        onTap: this_.onRotate,
      ),
      _SmallIcon(
        icon: Icons.segment_rounded,
        tooltip: l10n.chapters,
        onTap: this_.onChapters,
      ),
      _SmallIcon(
        icon: Icons.fullscreen_rounded,
        tooltip: l10n.fullscreen,
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

/// Material ships replay/forward glyphs for 5, 10 and 30 seconds only, so any
/// other amount falls back to the plain arrow rather than drawing a number the
/// button does not honour.
IconData _replayIcon(Duration amount) => switch (amount.inSeconds) {
      5 => Icons.replay_5_rounded,
      10 => Icons.replay_10_rounded,
      30 => Icons.replay_30_rounded,
      _ => Icons.fast_rewind_rounded,
    };

IconData _forwardIcon(Duration amount) => switch (amount.inSeconds) {
      5 => Icons.forward_5_rounded,
      10 => Icons.forward_10_rounded,
      30 => Icons.forward_30_rounded,
      _ => Icons.fast_forward_rounded,
    };
