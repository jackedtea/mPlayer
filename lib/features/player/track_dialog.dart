// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/tokens.dart';
import '../../l10n/app_localizations.dart';
import 'playback_controller.dart';
import 'playback_state.dart';
import 'track_sheet.dart';

/// Audio on the left, subtitles on the right, in one dialog.
///
/// They are chosen together more often than apart — switching to the
/// original audio is usually the moment subtitles go on — so one dialog
/// showing both saves the second trip through the controls. A choice applies
/// at once and leaves the dialog open, since the other side is the likely
/// next tap; the ticks follow the player, not the tap, so a track the
/// decoder refused does not show as chosen.
Future<void> showAudioSubtitleDialog(
  BuildContext context, {
  required ValueChanged<MediaTrack> onAudio,
  required ValueChanged<MediaTrack?> onSubtitle,
  required VoidCallback onOpenSubtitleFile,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => AudioSubtitleDialog(
      onAudio: onAudio,
      onSubtitle: onSubtitle,
      onOpenSubtitleFile: onOpenSubtitleFile,
    ),
  );
}

class AudioSubtitleDialog extends ConsumerWidget {
  const AudioSubtitleDialog({
    super.key,
    required this.onAudio,
    required this.onSubtitle,
    required this.onOpenSubtitleFile,
  });

  final ValueChanged<MediaTrack> onAudio;
  final ValueChanged<MediaTrack?> onSubtitle;
  final VoidCallback onOpenSubtitleFile;

  /// The player's dark surface; the app's light theme flashing over a film
  /// is worse than a dialog that looks slightly unlike the rest of the app.
  static const _surface = Color(0xFF1A2125);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = context.spacing;
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(playbackControllerProvider);
    final divider = Colors.white.withValues(alpha: 0.12);

    return Dialog(
      backgroundColor: _surface,
      clipBehavior: Clip.antiAlias,
      insetPadding: EdgeInsets.all(spacing.lg),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 760,
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.fromLTRB(
                spacing.xl,
                spacing.md,
                spacing.sm,
                spacing.sm,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      l10n.audioAndSubtitles,
                      style: const TextStyle(color: Colors.white, fontSize: 20),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white70,
                    ),
                    tooltip: l10n.close,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: divider),
            Flexible(
              // Each side as tall as its own list, up to the dialog's limit,
              // and scrolling past it — not both stretched to the taller.
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: _Column(
                      icon: Icons.graphic_eq_rounded,
                      title: l10n.audio,
                      options: <TrackOption>[
                        for (final MediaTrack t in state.audioTracks)
                          TrackOption.fromTrack(t),
                      ],
                      selectedId: state.activeAudio?.id,
                      onSelected: (o) {
                        final track = o.track;
                        if (track != null) onAudio(track);
                      },
                    ),
                  ),
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border(left: BorderSide(color: divider)),
                      ),
                      child: _Column(
                        icon: Icons.subtitles_rounded,
                        title: l10n.subtitles,
                        options: <TrackOption>[
                          for (final MediaTrack t in state.subtitleTracks)
                            TrackOption.fromTrack(t),
                        ],
                        selectedId: state.activeSubtitle?.id,
                        onSelected: (o) => onSubtitle(o.track),
                        footer: ListTile(
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: spacing.xl,
                          ),
                          leading: const Icon(
                            Icons.file_open_outlined,
                            color: Colors.white70,
                          ),
                          title: Text(
                            l10n.openSubtitleFile,
                            style: const TextStyle(color: Colors.white),
                          ),
                          // Closes first: the file picker is a window of its
                          // own, and coming back to this dialog under it
                          // would be a second thing to dismiss.
                          onTap: () {
                            Navigator.of(context).pop();
                            onOpenSubtitleFile();
                          },
                        ),
                      ),
                    ),
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

/// One side of the dialog: a heading, its tracks, and anything under them.
class _Column extends StatelessWidget {
  const _Column({
    required this.icon,
    required this.title,
    required this.options,
    required this.selectedId,
    required this.onSelected,
    this.footer,
  });

  final IconData icon;
  final String title;
  final List<TrackOption> options;
  final String? selectedId;
  final ValueChanged<TrackOption> onSelected;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final l10n = AppLocalizations.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.fromLTRB(
            spacing.xl,
            spacing.lg,
            spacing.xl,
            spacing.sm,
          ),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 18, color: context.colors.primaryContainer),
              SizedBox(width: spacing.sm),
              // Half a portrait phone is narrow; the heading wraps there
              // rather than running under the other side.
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    color: context.colors.primaryContainer,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        Flexible(
          child: options.isEmpty
              ? Padding(
                  padding: EdgeInsets.symmetric(horizontal: spacing.xl),
                  child: Text(
                    l10n.noTracks,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                )
              : ListView(
                  shrinkWrap: true,
                  children: <Widget>[
                    for (final TrackOption option in options)
                      TrackRow(
                        option: option,
                        selected: option.id == selectedId,
                        onTap: () => onSelected(option),
                        // The titles line up whether or not a row has a
                        // language to show.
                        badgeSlot: options.any((o) => o.badge != null),
                      ),
                  ],
                ),
        ),
        if (footer != null) ...<Widget>[
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.12)),
          footer!,
        ],
      ],
    );
  }
}
