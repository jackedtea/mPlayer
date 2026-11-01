// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';

import '../../app/tokens.dart';
import '../../core/languages.dart';
import 'playback_state.dart';
import 'stable_insets.dart';

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
    this.action,
  });

  final String title;
  final List<TrackOption> options;
  final String? selectedId;
  final ValueChanged<TrackOption> onSelected;

  /// An optional command below the list — "Open subtitle file", say. It is
  /// not one of the [options] because it selects nothing; it dismisses the
  /// sheet and goes off to do something.
  final TrackSheetAction? action;

  static Future<void> show({
    required BuildContext context,
    required String title,
    required List<TrackOption> options,
    required String? selectedId,
    required ValueChanged<TrackOption> onSelected,
    TrackSheetAction? action,
  }) {
    return showPlayerSheet<void>(
      context: context,
      builder: (_) => TrackSheet(
        title: title,
        options: options,
        selectedId: selectedId,
        onSelected: onSelected,
        action: action,
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
                  TrackRow(
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
          if (action != null) ...<Widget>[
            const Divider(height: 1),
            ListTile(
              leading: Icon(action!.icon, color: Colors.white70),
              title: Text(
                action!.label,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              onTap: () {
                Navigator.of(context).pop();
                action!.onTap();
              },
            ),
          ],
          SizedBox(height: spacing.sm),
        ],
      ),
    );
  }
}

/// The command row at the foot of a [TrackSheet].
@immutable
class TrackSheetAction {
  const TrackSheetAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
}

/// One selectable row: a label, an optional detail line and still, and a
/// tick on the current one. Shared by [TrackSheet] and the audio-and-subtitle
/// dialog, so a track looks the same in both.
class TrackRow extends StatelessWidget {
  const TrackRow({
    super.key,
    required this.option,
    required this.selected,
    required this.onTap,
    this.badgeSlot = false,
  });

  final TrackOption option;
  final bool selected;
  final VoidCallback onTap;

  /// Keeps the badge's width free on a row that has none — Off, Auto, an
  /// unlabelled track — so the titles in a list of tracks line up.
  final bool badgeSlot;

  static const _badgeWidth = 34.0;

  @override
  Widget build(BuildContext context) {
    final accent = context.colors.primaryContainer;

    final thumbnail = option.thumbnail;
    final badge = option.badge;

    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.symmetric(horizontal: context.spacing.xl),
      // 16:9 at the height of a two-line tile, so the rows stay the size the
      // sheet already is: a chapter list that suddenly doubles in height on
      // a server and not on a local file reads as two different sheets.
      leading: thumbnail == null
          ? (badge != null
              ? _LanguageBadge(
                  tag: badge,
                  width: _badgeWidth,
                  selected: selected,
                )
              : (badgeSlot ? const SizedBox(width: _badgeWidth) : null))
          : ClipRRect(
              borderRadius: BorderRadius.circular(context.radii.thumb),
              child: Container(
                width: 64,
                height: 36,
                color: Colors.white.withValues(alpha: 0.08),
                child: Image.network(
                  thumbnail.toString(),
                  fit: BoxFit.cover,
                  // A still that will not load leaves the placeholder behind
                  // it; the chapter is still selectable, which is the point
                  // of the row.
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
      minLeadingWidth: badge != null || badgeSlot ? _badgeWidth : null,
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

/// A track's language as a short tag in a box — "EN", "VI" — so a list of
/// tracks can be scanned by language before any title is read.
class _LanguageBadge extends StatelessWidget {
  const _LanguageBadge({
    required this.tag,
    required this.width,
    required this.selected,
  });

  final String tag;
  final double width;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final accent = context.colors.primaryContainer;
    final colour = selected ? accent : Colors.white.withValues(alpha: 0.8);

    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 3),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: colour.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        tag,
        maxLines: 1,
        overflow: TextOverflow.clip,
        style: TextStyle(
          color: colour,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
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
    this.thumbnail,
    this.badge,
  });

  factory TrackOption.fromTrack(MediaTrack track) {
    final placeholder = track.isOff || track.isAuto;
    final language = placeholder ? null : trackLanguageName(track.language);
    // Said in the detail line unless the title already says it: a track
    // labelled "English 5.1" gains nothing from "English" under it.
    final sayLanguage = language != null &&
        !track.label.toLowerCase().contains(language.toLowerCase());

    final notes = <String>[
      if (sayLanguage) language,
      // An image-based track can be selected but will not appear, so say so
      // here rather than letting the user wonder what broke.
      if (track.isImageBased)
        'Image-based (${track.codec}) — cannot be displayed yet'
      else if (track.isDefault)
        'Default',
    ];

    return TrackOption(
      id: track.id,
      label: track.label,
      detail: notes.isEmpty ? null : notes.join(' · '),
      badge: placeholder ? null : trackLanguageTag(track.language),
      track: track,
    );
  }

  final String id;
  final String label;
  final String? detail;

  /// Set for subtitle and audio rows.
  final MediaTrack? track;

  /// Set for value rows such as speed.
  final double? value;

  /// A still to draw beside the row.
  ///
  /// Only a server chapter has one — a container carries titles and
  /// timestamps and no pictures — so a row without it is the normal case,
  /// not a missing image.
  final Uri? thumbnail;

  /// The short language tag drawn at the start of an audio or subtitle row,
  /// or null where the track does not name one.
  final String? badge;
}
