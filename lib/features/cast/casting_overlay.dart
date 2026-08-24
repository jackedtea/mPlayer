// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';

import '../../app/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../cast/cast_device.dart';

/// What the player shows while the television is the one playing.
///
/// It replaces the video and the chrome rather than sitting over them: the
/// surface here is decoding nothing, and leaving a black frame with a
/// scrubber under it would read as a player that has stopped working.
class CastingOverlay extends StatelessWidget {
  const CastingOverlay({
    super.key,
    required this.device,
    required this.title,
    required this.status,
    required this.onPlayPause,
    required this.onSeek,
    required this.onStop,
    required this.onBack,
  });

  final CastDevice device;
  final String title;
  final CastStatus status;
  final VoidCallback onPlayPause;
  final ValueChanged<Duration> onSeek;
  final VoidCallback onStop;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final duration = status.duration;
    final progress = duration > Duration.zero
        ? (status.position.inMilliseconds / duration.inMilliseconds)
            .clamp(0.0, 1.0)
        : 0.0;

    return Material(
      color: Colors.black,
      child: SafeArea(
        child: Column(
          children: <Widget>[
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                color: Colors.white,
                tooltip: l10n.actionBack,
                onPressed: onBack,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.tv_rounded,
              size: 64,
              color: Colors.white.withValues(alpha: 0.85),
            ),
            SizedBox(height: spacing.lg),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: spacing.xl),
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
            SizedBox(height: spacing.xs),
            Text(
              l10n.playingOn(device.name),
              style: const TextStyle(color: Colors.white70),
            ),
            const Spacer(),

            Padding(
              padding: EdgeInsets.symmetric(horizontal: spacing.xl),
              child: Column(
                children: <Widget>[
                  Slider(
                    value: progress,
                    // A device that reports no duration cannot be scrubbed —
                    // a slider that snapped back to zero on release would be
                    // worse than one that plainly does not move.
                    onChanged: duration > Duration.zero
                        ? (v) => onSeek(duration * v)
                        : null,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(
                        _clock(status.position),
                        style: const TextStyle(color: Colors.white70),
                      ),
                      Text(
                        _clock(duration),
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            SizedBox(height: spacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                IconButton.filled(
                  iconSize: 36,
                  icon: Icon(
                    status.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                  ),
                  onPressed: onPlayPause,
                ),
                SizedBox(width: spacing.xl),
                IconButton(
                  iconSize: 28,
                  icon: const Icon(Icons.stop_circle_outlined),
                  color: Colors.white,
                  tooltip: l10n.stopCasting,
                  onPressed: onStop,
                ),
              ],
            ),
            SizedBox(height: spacing.xl),
          ],
        ),
      ),
    );
  }

  /// `1:02:03` past an hour, `2:03` below it — the same shape the scrubber
  /// uses, so the two never disagree about how long something is.
  static String _clock(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:$seconds';
    }
    return '$minutes:$seconds';
  }
}
