// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';

import '../../app/tokens.dart';
import 'playback_state.dart';

/// "Stats for nerds" — a monospace key/value card over the video.
///
/// Every value is optional and renders as `—` when the backend has not
/// reported it yet. Showing a confident `0 fps` while a stream is still
/// probing would be worse than showing nothing.
class StatsOverlay extends StatelessWidget {
  const StatsOverlay({super.key, required this.state});

  final PlaybackState state;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final stats = state.stats;
    final media = state.media;

    final rows = <(String, String)>[
      ('source', media?.uri.toString() ?? '—'),
      ('mode', media?.sourceLine ?? '—'),
      (
        'video',
        _join(<String?>[
          stats.videoCodec?.toUpperCase(),
          if (stats.width != null && stats.height != null)
            '${stats.width}×${stats.height}',
          stats.fps == null ? null : '${stats.fps!.toStringAsFixed(2)} fps',
        ]),
      ),
      (
        'decoder',
        stats.videoDecoder == null
            ? '—'
            : '${stats.videoDecoder} '
                '(${stats.isHardwareDecoded ? 'hw' : 'sw'})',
      ),
      (
        'audio',
        _join(<String?>[
          stats.audioCodec?.toUpperCase(),
          stats.audioChannels,
          stats.audioSampleRate == null
              ? null
              : '${(stats.audioSampleRate! / 1000).toStringAsFixed(1)} kHz',
        ]),
      ),
      (
        'bitrate',
        _join(<String?>[
          stats.videoBitrate == null
              ? null
              : 'v ${_mbps(stats.videoBitrate!.toDouble())}',
          stats.audioBitrate == null
              ? null
              : 'a ${_mbps(stats.audioBitrate!)}',
        ]),
      ),
      (
        'buffer',
        '${(state.buffered - state.position).inSeconds.clamp(0, 999)} s ahead',
      ),
      ('position', '${formatDuration(state.position)} / '
          '${formatDuration(state.duration)}'),
      ('speed', '${state.speed.toStringAsFixed(2)}×'),
      ('subtitle', state.activeSubtitle?.label ?? 'Off'),
      ('state', state.buffering ? 'buffering' : (state.playing ? 'playing' : 'paused')),
    ];

    return Align(
      alignment: Alignment.topLeft,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(spacing.lg),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: EdgeInsets.all(spacing.md),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.72),
              borderRadius: context.radii.cardAll,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (final (String key, String value) in rows)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        SizedBox(
                          width: 74,
                          child: Text(
                            key,
                            style: _style.copyWith(
                              color: Colors.white.withValues(alpha: 0.55),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            value,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: _style,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _join(List<String?> parts) {
    final kept = parts.whereType<String>().where((s) => s.isNotEmpty).toList();
    return kept.isEmpty ? '—' : kept.join(' · ');
  }

  static String _mbps(double bitsPerSecond) =>
      '${(bitsPerSecond / 1000000).toStringAsFixed(2)} Mbps';

  static const _style = TextStyle(
    fontFamily: 'monospace',
    fontFamilyFallback: <String>['Consolas', 'Menlo', 'monospace'],
    fontSize: 10.5,
    height: 17 / 10.5,
    color: Colors.white,
  );
}
