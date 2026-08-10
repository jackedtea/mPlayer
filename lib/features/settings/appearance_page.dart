// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';

import '../../app/tokens.dart';
import 'settings_widgets.dart';

/// Screen 1m, Appearance.
///
/// The controls are live but not yet persisted — wiring them to
/// `shared_preferences` and lifting theme mode into a provider is the next
/// task on this page.
class AppearancePage extends StatefulWidget {
  const AppearancePage({super.key});

  @override
  State<AppearancePage> createState() => _AppearancePageState();
}

class _AppearancePageState extends State<AppearancePage> {
  /// The design's four presets. The first is the app's seed.
  static const _accents = <Color>[
    Color(0xFF00658F),
    Color(0xFF00629E),
    Color(0xFF00696E),
    Color(0xFF6750A4),
  ];

  ThemeMode _mode = ThemeMode.light;
  int _accent = 0;
  bool _dynamicColour = false;
  bool _pureBlack = false;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    return SettingsScaffold(
      title: 'Appearance',
      children: <Widget>[
        const SettingsSection(title: 'Theme'),
        SizedBox(
          height: 108,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: spacing.screenPadding(context.windowSize),
            children: <Widget>[
              for (final (ThemeMode mode, String label) in <(ThemeMode, String)>[
                (ThemeMode.light, 'Light'),
                (ThemeMode.dark, 'Dark'),
                (ThemeMode.system, 'System'),
              ])
                Padding(
                  padding: EdgeInsets.only(right: spacing.md),
                  child: _ThemeCard(
                    label: label,
                    mode: mode,
                    selected: _mode == mode,
                    onTap: () => setState(() => _mode = mode),
                  ),
                ),
            ],
          ),
        ),
        const SettingsSection(title: 'Accent'),
        Padding(
          padding: spacing.screenPadding(context.windowSize),
          child: Wrap(
            spacing: spacing.md,
            runSpacing: spacing.md,
            children: <Widget>[
              for (final (int i, Color colour) in _accents.indexed)
                _AccentSwatch(
                  colour: colour,
                  selected: i == _accent && !_dynamicColour,
                  onTap: () => setState(() {
                    _accent = i;
                    _dynamicColour = false;
                  }),
                ),
              _WallpaperSwatch(
                selected: _dynamicColour,
                onTap: () => setState(() => _dynamicColour = true),
              ),
            ],
          ),
        ),
        SizedBox(height: spacing.sm),
        SettingsSwitchRow(
          title: 'Material You dynamic colour',
          subtitle: 'Follow the system wallpaper palette',
          value: _dynamicColour,
          onChanged: (v) => setState(() => _dynamicColour = v),
        ),
        SettingsSwitchRow(
          title: 'Pure black in dark mode',
          subtitle: 'Saves power on OLED screens',
          value: _pureBlack,
          onChanged: (v) => setState(() => _pureBlack = v),
        ),
        const SettingsSection(title: 'Layout'),
        const SettingsValueRow(title: 'Default library view', value: 'Grid'),
        const SettingsValueRow(title: 'Density', value: 'Comfortable'),
      ],
    );
  }
}

/// 88h preview card. The swatch shows what the choice looks like rather than
/// relying on the word alone.
class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.label,
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final ThemeMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final radii = context.radii;

    return InkWell(
      onTap: onTap,
      borderRadius: radii.cardAll,
      child: Container(
        width: 104,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: radii.cardAll,
          border: Border.all(
            color: selected ? scheme.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: <Widget>[
            Expanded(
              child: ClipRRect(
                borderRadius: radii.chipAll,
                child: _Preview(mode: mode),
              ),
            ),
            SizedBox(height: context.spacing.xs),
            Text(
              label,
              style: context.texts.bodySmall?.copyWith(
                fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.mode});

  final ThemeMode mode;

  static const _light = Color(0xFFF6FAFE);
  static const _dark = Color(0xFF0F1417);

  @override
  Widget build(BuildContext context) {
    if (mode == ThemeMode.system) {
      // Split diagonally, the way the design shows "follows the system".
      return Row(
        children: const <Widget>[
          Expanded(child: ColoredBox(color: _light)),
          Expanded(child: ColoredBox(color: _dark)),
        ],
      );
    }
    return ColoredBox(color: mode == ThemeMode.light ? _light : _dark);
  }
}

class _AccentSwatch extends StatelessWidget {
  const _AccentSwatch({
    required this.colour,
    required this.selected,
    required this.onTap,
  });

  final Color colour;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
        child: selected
            ? const Icon(Icons.check_rounded, color: Colors.white, size: 22)
            : null,
      ),
    );
  }
}

class _WallpaperSwatch extends StatelessWidget {
  const _WallpaperSwatch({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: scheme.outline),
        ),
        child: Icon(
          selected ? Icons.check_rounded : Icons.wallpaper_rounded,
          size: 22,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
