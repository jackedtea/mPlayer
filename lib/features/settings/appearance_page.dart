// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/appearance_settings.dart';
import '../../app/tokens.dart';
import '../../l10n/app_localizations.dart';
import 'settings_widgets.dart';

/// Screen 1m, Appearance.
///
/// Every control writes straight through to [appearanceSettingsProvider],
/// which persists it and which the app root themes from — so a choice takes
/// effect on the page that made it, with no apply step.
class AppearancePage extends ConsumerWidget {
  const AppearancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = context.spacing;
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(appearanceSettingsProvider);
    final controller = ref.read(appearanceSettingsProvider.notifier);

    return SettingsScaffold(
      title: l10n.settingsAppearance,
      children: <Widget>[
        SettingsSection(title: l10n.theme),
        SizedBox(
          height: 108,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: spacing.screenPadding(context.windowSize),
            children: <Widget>[
              for (final (ThemeMode mode, String label) in <(ThemeMode, String)>[
                (ThemeMode.light, l10n.themeLight),
                (ThemeMode.dark, l10n.themeDark),
                (ThemeMode.system, l10n.themeSystem),
              ])
                Padding(
                  padding: EdgeInsets.only(right: spacing.md),
                  child: _ThemeCard(
                    label: label,
                    mode: mode,
                    selected: settings.mode == mode,
                    onTap: () =>
                        controller.update(settings.copyWith(mode: mode)),
                  ),
                ),
            ],
          ),
        ),
        SettingsSection(title: l10n.accent),
        Padding(
          padding: spacing.screenPadding(context.windowSize),
          child: Wrap(
            spacing: spacing.md,
            runSpacing: spacing.md,
            children: <Widget>[
              for (final (int i, Color colour) in accentPresets.indexed)
                _AccentSwatch(
                  colour: colour,
                  selected: i == settings.accentIndex && !settings.dynamicColour,
                  // Picking a colour is also how the user turns the wallpaper
                  // palette back off — the two are one choice in the design.
                  onTap: () => controller.update(
                    settings.copyWith(accentIndex: i, dynamicColour: false),
                  ),
                ),
              _WallpaperSwatch(
                selected: settings.dynamicColour,
                onTap: () =>
                    controller.update(settings.copyWith(dynamicColour: true)),
              ),
            ],
          ),
        ),
        SizedBox(height: spacing.sm),
        SettingsSwitchRow(
          title: l10n.dynamicColour,
          subtitle: l10n.dynamicColourSub,
          value: settings.dynamicColour,
          onChanged: (v) =>
              controller.update(settings.copyWith(dynamicColour: v)),
        ),
        SettingsSwitchRow(
          title: l10n.pureBlack,
          subtitle: l10n.pureBlackSub,
          value: settings.pureBlack,
          onChanged: (v) => controller.update(settings.copyWith(pureBlack: v)),
        ),
        SettingsSection(title: l10n.layout),
        SettingsValueRow(title: l10n.defaultLibraryView, value: l10n.grid),
        SettingsValueRow(title: l10n.density, value: l10n.comfortable),
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
