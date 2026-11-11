// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:screen_brightness/screen_brightness.dart';

import '../../app/tokens.dart';
import 'playback_state.dart';

/// What the transient centre/side indicator is currently showing.
enum _Indicator { none, brightness, volume, seek }

/// Touch handling over the video surface.
///
/// Zones follow the design: the left third adjusts brightness, the right third
/// volume, a double-tap on either side seeks, and a horizontal drag scrubs.
/// Single taps bubble up to the page, which toggles the chrome.
/// How far a swipe across the whole width of the player seeks.
///
/// A fixed span, not the length of the file: tied to the file, a swipe
/// across a two-hour film moved two hours, so a thumb's width was minutes
/// and landing anywhere near the line just missed took several tries. Ninety
/// seconds a width is the order of what other players use — about a tenth
/// of a second per point on a phone on its side — and the double tap is
/// still there for the bigger jumps.
const Duration swipeSeekSpan = Duration(seconds: 90);

/// Where a horizontal swipe of [dx] across a player [width] wide, begun at
/// [start], lands in a file [duration] long.
Duration swipeSeekTarget({
  required Duration start,
  required double dx,
  required double width,
  required Duration duration,
}) {
  final offset = Duration(
    milliseconds: (swipeSeekSpan.inMilliseconds * dx / width).round(),
  );
  final target = start + offset;
  if (target < Duration.zero) return Duration.zero;
  return target > duration ? duration : target;
}

class GestureLayer extends StatefulWidget {
  const GestureLayer({
    super.key,
    required this.enabled,
    this.gesturesEnabled = true,
    required this.state,
    required this.onTap,
    required this.onSeekBy,
    required this.onSeekTo,
    required this.onVolume,
    this.maxVolume = 100,
    this.skipBack = const Duration(seconds: 10),
    this.skipForward = const Duration(seconds: 30),
  });

  /// False while the player is locked — every gesture is ignored then.
  final bool enabled;

  /// The Player settings switch. Tap-to-toggle and double-tap seek survive;
  /// only the brightness and volume drags are turned off, because those are
  /// the ones people trigger by accident.
  final bool gesturesEnabled;

  final PlaybackState state;
  final VoidCallback onTap;
  final ValueChanged<Duration> onSeekBy;
  final ValueChanged<Duration> onSeekTo;

  /// 0 to [maxVolume], matching [PlaybackState.volumeLevel].
  final ValueChanged<double> onVolume;

  /// 100, or 200 with "Boost volume" on.
  final double maxVolume;

  final Duration skipBack;
  final Duration skipForward;

  @override
  State<GestureLayer> createState() => _GestureLayerState();
}

class _GestureLayerState extends State<GestureLayer> {
  _Indicator _indicator = _Indicator.none;
  double _value = 0;
  String _label = '';
  Timer? _hideTimer;

  /// Brightness is a system setting; it is restored when the player closes so
  /// a dimmed video does not leave the whole device dark.
  double? _restoreBrightness;
  double _brightness = 0.5;

  double? _dragStartVolume;
  double? _dragStartBrightness;
  Duration? _dragStartPosition;

  /// The swipe so far, and where it would land. The seek is made once, on
  /// release: seeking on every frame of the drag asked a network stream for a
  /// new position sixty times a second, each from wherever the last one had
  /// got to.
  double _dragDx = 0;
  Duration? _dragTarget;

  @override
  void initState() {
    super.initState();
    unawaited(_readBrightness());
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _restore();
    super.dispose();
  }

  Future<void> _readBrightness() async {
    try {
      final current = await ScreenBrightness.instance.application;
      if (!mounted) return;
      setState(() {
        _brightness = current;
        _restoreBrightness = current;
      });
    } catch (_) {
      // Desktop platforms without a brightness API: the gesture simply does
      // nothing rather than throwing into the widget tree.
    }
  }

  void _restore() {
    if (_restoreBrightness == null) return;
    unawaited(ScreenBrightness.instance.resetApplicationScreenBrightness());
  }

  Future<void> _applyBrightness(double value) async {
    final clamped = value.clamp(0.0, 1.0);
    setState(() => _brightness = clamped);
    try {
      await ScreenBrightness.instance.setApplicationScreenBrightness(clamped);
    } catch (_) {
      // Unsupported platform; the indicator still tracks so the gesture is
      // not silently dead on desktop.
    }
  }

  void _show(_Indicator indicator, double value, String label) {
    setState(() {
      _indicator = indicator;
      _value = value;
      _label = label;
    });
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _indicator = _Indicator.none);
    });
  }

  bool _isLeftThird(Offset local, double width) => local.dx < width / 3;
  bool _isRightThird(Offset local, double width) => local.dx > width * 2 / 3;

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return const SizedBox.expand();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onDoubleTapDown: (details) =>
              _handleDoubleTap(details.localPosition, width),
          // The callback fires after onDoubleTapDown has recorded where.
          onDoubleTap: () {},
          onVerticalDragStart: (details) {
            _dragStartVolume = widget.state.volumeLevel;
            _dragStartBrightness = _brightness;
            if (!_isLeftThird(details.localPosition, width) &&
                !_isRightThird(details.localPosition, width)) {
              _dragStartVolume = null;
              _dragStartBrightness = null;
            }
          },
          onVerticalDragUpdate: (details) =>
              _handleVerticalDrag(details, width, height),
          onHorizontalDragStart: (_) {
            _dragStartPosition = widget.state.position;
            _dragDx = 0;
            _dragTarget = null;
          },
          onHorizontalDragUpdate: (details) =>
              _handleHorizontalDrag(details, width),
          onHorizontalDragEnd: (_) => _finishHorizontalDrag(),
          onHorizontalDragCancel: _finishHorizontalDrag,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              const SizedBox.expand(),
              if (_indicator != _Indicator.none) _buildIndicator(),
            ],
          ),
        );
      },
    );
  }

  void _handleDoubleTap(Offset local, double width) {
    if (_isLeftThird(local, width)) {
      widget.onSeekBy(-widget.skipBack);
      _show(_Indicator.seek, 0, '−${widget.skipBack.inSeconds}s');
    } else if (_isRightThird(local, width)) {
      widget.onSeekBy(widget.skipForward);
      _show(_Indicator.seek, 0, '+${widget.skipForward.inSeconds}s');
    }
  }

  void _handleVerticalDrag(
    DragUpdateDetails details,
    double width,
    double height,
  ) {
    // A full-height swipe covers the whole range; dy is inverted because
    // dragging up should increase.
    final delta = -details.delta.dy / height;

    if (!widget.gesturesEnabled) return;

    if (_isLeftThird(details.localPosition, width) &&
        _dragStartBrightness != null) {
      final next = (_brightness + delta).clamp(0.0, 1.0);
      unawaited(_applyBrightness(next));
      _show(_Indicator.brightness, next, '${(next * 100).round()}%');
    } else if (_isRightThird(details.localPosition, width) &&
        _dragStartVolume != null) {
      // Kept here rather than read back from the state: a synced device
      // volume lands in steps, and adding the swipe to a value rounded to
      // one would leave small swipes going nowhere. A full-height swipe is
      // 100% whatever the ceiling, so boosting does not halve its pace.
      final next =
          (_dragStartVolume! + delta * 100).clamp(0.0, widget.maxVolume);
      _dragStartVolume = next;
      widget.onVolume(next);
      _show(_Indicator.volume, next / widget.maxVolume, '${next.round()}%');
    }
  }

  void _handleHorizontalDrag(DragUpdateDetails details, double width) {
    final duration = widget.state.duration;
    final start = _dragStartPosition;
    if (duration <= Duration.zero || start == null) return;

    _dragDx += details.delta.dx;
    final target = swipeSeekTarget(
      start: start,
      dx: _dragDx,
      width: width,
      duration: duration,
    );
    _dragTarget = target;

    // How far as well as where to: the distance is what the thumb controls.
    final moved = target - start;
    final sign = moved.isNegative ? '−' : '+';
    _show(
      _Indicator.seek,
      0,
      '$sign${formatDuration(moved.abs())} · ${formatDuration(target)}',
    );
  }

  void _finishHorizontalDrag() {
    final target = _dragTarget;
    if (target != null && target != _dragStartPosition) {
      widget.onSeekTo(target);
    }
    _dragStartPosition = null;
    _dragTarget = null;
    _dragDx = 0;
  }

  Widget _buildIndicator() {
    if (_indicator == _Indicator.seek) {
      return Center(child: _Pill(label: _label));
    }

    final isBrightness = _indicator == _Indicator.brightness;
    return Align(
      alignment: isBrightness ? Alignment.centerLeft : Alignment.centerRight,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: context.spacing.xl + 8),
        child: _LevelBar(
          icon: isBrightness
              ? Icons.brightness_6_rounded
              : Icons.volume_up_rounded,
          value: _value,
          label: _label,
        ),
      ),
    );
  }
}

/// Centred pill for a seek amount or target timestamp.
class _Pill extends StatelessWidget {
  const _Pill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.66),
        borderRadius: BorderRadius.circular(context.radii.sheet),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// Icon over a 6x96 vertical bar with a percentage, per the design.
class _LevelBar extends StatelessWidget {
  const _LevelBar({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final double value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.66),
        borderRadius: BorderRadius.circular(context.radii.card),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(height: 10),
          SizedBox(
            width: 6,
            height: 96,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: ColoredBox(
                // Unfilled track, so the bar reads as a scale rather than a
                // floating sliver at low values.
                color: Colors.white.withValues(alpha: 0.3),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  // `widthFactor: 1` is what makes the fill visible at all.
                  // A childless `ColoredBox` takes the *smallest* size its
                  // constraints allow, and the fraction only tightened the
                  // height — so the fill was laid out the full height asked
                  // for and zero pixels wide, and every level read as empty
                  // however far the swipe went.
                  child: FractionallySizedBox(
                    widthFactor: 1,
                    heightFactor: value.clamp(0.0, 1.0),
                    // White over the 30% track, matching the scrubber and
                    // the rest of the chrome drawn over the video.
                    child: const ColoredBox(color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
