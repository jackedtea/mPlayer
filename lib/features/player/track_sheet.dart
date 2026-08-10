// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';

import '../../app/tokens.dart';
import 'playback_state.dart';

/// Bottom sheet for picking a subtitle or audio stream, and for speed.
///
/// One sheet type for all three: they are the same interaction — a titled list
/// of options with the current one ticked — and the design draws them the
/// same way.
class TrackSheet extends StatelessWidget {
  const TrackSheet({
    super.key,
    required this.title,
    required this.options,
    required this.selectedId,
    required this.onSelected,
  });

  final String title;
  final List<TrackOption> options;
  final String? selectedId;
  final ValueChanged<TrackOption> onSelected;

  static Future<void> show({
    required BuildContext context,
    required String title,
    required List<TrackOption> options,
    required String? selectedId,
    required ValueChanged<TrackOption> onSelected,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      // The player is a dark surface; the sheet has to match it rather than
      // flashing the app's light theme over the video.
      backgroundColor: const Color(0xFF1A2125),
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) => TrackSheet(
        title: title,
        options: options,
        selectedId: selectedId,
        onSelected: onSelected,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.fromLTRB(
              spacing.xl,
              spacing.sm,
              spacing.xl,
              spacing.md,
            ),
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: <Widget>[
                for (final TrackOption option in options)
                  _Row(
                    option: option,
                    selected: option.id == selectedId,
                    onTap: () {
                      onSelected(option);
                      Navigator.of(context).pop();
                    },
                  ),
              ],
            ),
          ),
          SizedBox(height: spacing.sm),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final TrackOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = context.colors.primaryContainer;

    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.symmetric(horizontal: context.spacing.xl),
      title: Text(
        option.label,
        style: TextStyle(color: selected ? accent : Colors.white),
      ),
      subtitle: option.detail == null
          ? null
          : Text(
              option.detail!,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
            ),
      trailing: selected ? Icon(Icons.check_rounded, color: accent) : null,
    );
  }
}

/// One row in a [TrackSheet]. Wraps a [MediaTrack] or a plain value such as a
/// playback speed, which has no track behind it.
@immutable
class TrackOption {
  const TrackOption({
    required this.id,
    required this.label,
    this.detail,
    this.track,
    this.value,
  });

  factory TrackOption.fromTrack(MediaTrack track) => TrackOption(
        id: track.id,
        label: track.label,
        detail: track.isDefault ? 'Default' : null,
        track: track,
      );

  final String id;
  final String label;
  final String? detail;

  /// Set for subtitle and audio rows.
  final MediaTrack? track;

  /// Set for value rows such as speed.
  final double? value;
}
