// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/tokens.dart';
import '../player/playback_controller.dart';
import 'player_settings.dart';
import 'settings_widgets.dart';

/// Screen 1m, Subtitle.
///
/// The preview is the point of this page: every control above the fold
/// changes it live, so the user never has to start playback to judge a
/// setting.
class SubtitleSettingsPage extends ConsumerStatefulWidget {
  const SubtitleSettingsPage({super.key});

  @override
  ConsumerState<SubtitleSettingsPage> createState() =>
      _SubtitleSettingsPageState();
}

class _SubtitleSettingsPageState extends ConsumerState<SubtitleSettingsPage> {
  static const _colours = <Color>[
    Colors.white,
    Color(0xFFFFE082),
    Color(0xFF8FD8C6),
    Color(0xFF82CFFF),
    Color(0xFFFFAB91),
  ];

  bool _burnIn = true;

  /// Writes through and applies to libmpv straight away, so the live preview
  /// and the actual subtitles cannot disagree.
  Future<void> _save(PlayerSettings next) async {
    await ref.read(playerSettingsProvider.notifier).update(next);
    await ref.read(playbackControllerProvider.notifier).applySettings(next);
  }

  Future<void> _pickDelay(PlayerSettings settings) async {
    final chosen = await showModalBottomSheet<int>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final int ms in _delayChoices)
              ListTile(
                title: Text('$ms ms'),
                trailing: ms == settings.subtitleDelay.inMilliseconds
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(ms),
              ),
          ],
        ),
      ),
    );

    if (chosen == null) return;
    await _save(
      settings.copyWith(subtitleDelay: Duration(milliseconds: chosen)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final settings = ref.watch(playerSettingsProvider);
    final colourIndex = _colours.indexWhere(
      (c) => c.toARGB32() == settings.subtitleColour.toARGB32(),
    );

    return SettingsScaffold(
      title: 'Subtitle',
      children: <Widget>[
        _Preview(
          textScale: settings.subtitleTextScale,
          backgroundOpacity: settings.subtitleBackgroundOpacity,
          colour: settings.subtitleColour,
        ),
        const SettingsSection(title: 'Style'),
        const SettingsValueRow(title: 'Font', value: 'Roboto'),
        SettingsSliderRow(
          title: 'Text size',
          valueLabel: '${(settings.subtitleTextScale * 100).round()}%',
          value: settings.subtitleTextScale,
          min: 0.5,
          max: 2.0,
          divisions: 15,
          onChanged: (v) => _save(settings.copyWith(subtitleTextScale: v)),
        ),
        SettingsSliderRow(
          title: 'Background opacity',
          valueLabel:
              '${(settings.subtitleBackgroundOpacity * 100).round()}%',
          value: settings.subtitleBackgroundOpacity,
          divisions: 20,
          onChanged: (v) =>
              _save(settings.copyWith(subtitleBackgroundOpacity: v)),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            spacing.screenHorizontal(context.windowSize),
            spacing.md,
            spacing.screenHorizontal(context.windowSize),
            0,
          ),
          child: Wrap(
            spacing: spacing.md,
            children: <Widget>[
              for (final (int i, Color c) in _colours.indexed)
                InkWell(
                  onTap: () => _save(settings.copyWith(subtitleColour: c)),
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(color: context.colors.outline),
                    ),
                    child: i == colourIndex
                        ? const Icon(Icons.check_rounded,
                            size: 20, color: Colors.black)
                        : null,
                  ),
                ),
            ],
          ),
        ),
        const SettingsSection(title: 'Behaviour'),
        const SettingsValueRow(
          title: 'Preferred languages',
          value: 'English, Vietnamese',
        ),
        SettingsSwitchRow(
          title: 'Burn in when transcoding',
          subtitle: 'Image-based subtitles only',
          value: _burnIn,
          onChanged: (v) => setState(() => _burnIn = v),
        ),
        SettingsValueRow(
          title: 'Sync offset',
          value: '${settings.subtitleDelay.inMilliseconds} ms',
          subtitle: 'Positive delays the subtitles',
          onTap: () => _pickDelay(settings),
        ),
      ],
    );
  }
}

/// A short list rather than free text: the useful range is small, and a
/// numeric keyboard for milliseconds is a poor way to nudge timing.
const _delayChoices = <int>[-2000, -1000, -500, 0, 500, 1000, 2000];

class _Preview extends StatelessWidget {
  const _Preview({
    required this.textScale,
    required this.backgroundOpacity,
    required this.colour,
  });

  final double textScale;
  final double backgroundOpacity;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    return Container(
      height: 132,
      margin: EdgeInsets.symmetric(
        horizontal: spacing.screenHorizontal(context.windowSize),
      ),
      decoration: BoxDecoration(
        borderRadius: context.radii.cardAll,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF2C3A44), Color(0xFF16202A)],
        ),
      ),
      alignment: Alignment.bottomCenter,
      padding: EdgeInsets.only(bottom: spacing.lg),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: spacing.sm,
          vertical: spacing.xs,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: backgroundOpacity),
          borderRadius: BorderRadius.circular(context.radii.field),
        ),
        child: Text(
          'The tide turns at midnight.',
          style: TextStyle(color: colour, fontSize: 15 * textScale),
        ),
      ),
    );
  }
}
