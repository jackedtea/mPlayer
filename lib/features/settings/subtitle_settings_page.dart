// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';

import '../../app/tokens.dart';
import 'settings_widgets.dart';

/// Screen 1m, Subtitle.
///
/// The preview is the point of this page: every control above the fold
/// changes it live, so the user never has to start playback to judge a
/// setting.
class SubtitleSettingsPage extends StatefulWidget {
  const SubtitleSettingsPage({super.key});

  @override
  State<SubtitleSettingsPage> createState() => _SubtitleSettingsPageState();
}

class _SubtitleSettingsPageState extends State<SubtitleSettingsPage> {
  static const _colours = <Color>[
    Colors.white,
    Color(0xFFFFE082),
    Color(0xFF8FD8C6),
    Color(0xFF82CFFF),
    Color(0xFFFFAB91),
  ];

  double _textScale = 1.0;
  double _backgroundOpacity = 0.55;
  int _colour = 0;
  bool _burnIn = true;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    return SettingsScaffold(
      title: 'Subtitle',
      children: <Widget>[
        _Preview(
          textScale: _textScale,
          backgroundOpacity: _backgroundOpacity,
          colour: _colours[_colour],
        ),
        const SettingsSection(title: 'Style'),
        const SettingsValueRow(title: 'Font', value: 'Roboto'),
        SettingsSliderRow(
          title: 'Text size',
          valueLabel: '${(_textScale * 100).round()}%',
          value: _textScale,
          min: 0.5,
          max: 2.0,
          divisions: 15,
          onChanged: (v) => setState(() => _textScale = v),
        ),
        SettingsSliderRow(
          title: 'Background opacity',
          valueLabel: '${(_backgroundOpacity * 100).round()}%',
          value: _backgroundOpacity,
          divisions: 20,
          onChanged: (v) => setState(() => _backgroundOpacity = v),
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
                  onTap: () => setState(() => _colour = i),
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(color: context.colors.outline),
                    ),
                    child: i == _colour
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
        const SettingsValueRow(title: 'Sync offset', value: '0 ms'),
      ],
    );
  }
}

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
