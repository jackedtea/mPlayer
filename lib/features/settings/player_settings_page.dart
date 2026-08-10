// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';

import 'settings_widgets.dart';

/// Screen 1l, Player section.
class PlayerSettingsPage extends StatefulWidget {
  const PlayerSettingsPage({super.key});

  @override
  State<PlayerSettingsPage> createState() => _PlayerSettingsPageState();
}

class _PlayerSettingsPageState extends State<PlayerSettingsPage> {
  bool _autoPlayNext = true;
  bool _autoSkipIntro = false;
  bool _swipeGestures = true;
  bool _backgroundPip = true;

  /// Mbps on cellular; 0 means "Original", matching the design's Wi-Fi value.
  double _cellularCap = 4;

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: 'Player',
      children: <Widget>[
        const SettingsSection(title: 'Playback'),
        const SettingsValueRow(
          title: 'Hardware decoding',
          value: 'Auto (safe)',
          subtitle: 'Falls back to software when a codec is unsupported',
        ),
        const SettingsValueRow(
          title: 'Resume behaviour',
          value: 'Ask',
        ),
        const SettingsValueRow(title: 'Skip back', value: '10s'),
        const SettingsValueRow(title: 'Skip forward', value: '30s'),
        SettingsSwitchRow(
          title: 'Auto-play next episode',
          value: _autoPlayNext,
          onChanged: (v) => setState(() => _autoPlayNext = v),
        ),
        SettingsSwitchRow(
          title: 'Auto skip intro',
          subtitle: 'Only where the server marks an intro chapter',
          value: _autoSkipIntro,
          onChanged: (v) => setState(() => _autoSkipIntro = v),
        ),
        const SettingsSection(title: 'Screen & gestures'),
        const SettingsValueRow(title: 'Rotation', value: 'Follow video'),
        SettingsSwitchRow(
          title: 'Swipe gestures',
          subtitle: 'Brightness on the left, volume on the right',
          value: _swipeGestures,
          onChanged: (v) => setState(() => _swipeGestures = v),
        ),
        SettingsSwitchRow(
          title: 'Background & picture-in-picture',
          value: _backgroundPip,
          onChanged: (v) => setState(() => _backgroundPip = v),
        ),
        const SettingsSection(title: 'Streaming quality'),
        const SettingsValueRow(title: 'On Wi-Fi', value: 'Original'),
        SettingsSliderRow(
          title: 'On cellular',
          valueLabel: _cellularCap == 0
              ? 'Original'
              : '${_cellularCap.round()} Mbps',
          value: _cellularCap,
          max: 20,
          divisions: 20,
          onChanged: (v) => setState(() => _cellularCap = v),
        ),
      ],
    );
  }
}
