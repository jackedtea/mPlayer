// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';

/// Window size classes from the design spec's adaptive-layout table.
///
/// | width      | navigation        | content            |
/// |------------|-------------------|--------------------|
/// | < 600      | `NavigationBar`   | single pane        |
/// | 600–1239   | `NavigationRail`  | two pane           |
/// | >= 1240    | `NavigationDrawer`| grid + playback bar|
enum WindowSize {
  compact,
  medium,
  large;

  static WindowSize fromWidth(double width) {
    if (width >= 1240) return WindowSize.large;
    if (width >= 600) return WindowSize.medium;
    return WindowSize.compact;
  }

  bool get isCompact => this == WindowSize.compact;
  bool get isMedium => this == WindowSize.medium;
  bool get isLarge => this == WindowSize.large;
}

/// The 4-pt spacing scale. Widgets read these instead of hard-coding numbers.
@immutable
class AppSpacing extends ThemeExtension<AppSpacing> {
  const AppSpacing({
    this.xs = 4,
    this.sm = 8,
    this.md = 12,
    this.lg = 16,
    this.xl = 24,
    this.screenH = 16,
    this.screenHDesktop = 24,
    this.cardGap = 12,
    this.sectionGap = 24,
    this.rowMinHeight = 64,
    this.rowMinHeightTwoLine = 72,
    this.touchTarget = 48,
    this.hitInset = 6,
  });

  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;

  /// Screen horizontal padding: 16 on phone/tablet, 24 on desktop.
  final double screenH;
  final double screenHDesktop;

  final double cardGap;
  final double sectionGap;

  /// List row minimum heights; 72 for two-line rows with a leading avatar.
  final double rowMinHeight;
  final double rowMinHeightTwoLine;

  /// Icon buttons are 48x48; nothing interactive goes below 44.
  final double touchTarget;

  /// Gap between a tappable surface's ink edge and the content inside it.
  ///
  /// Cards whose artwork and caption sit flush to the edge need this, or the
  /// hover/press highlight hugs the text with no breathing room. Layouts
  /// subtract it from their own padding and gaps so the *content* still lands
  /// on the design's grid — see `ContinueWatchingCard` and its shelf.
  final double hitInset;

  double screenHorizontal(WindowSize size) =>
      size.isLarge ? screenHDesktop : screenH;

  EdgeInsets screenPadding(WindowSize size) =>
      EdgeInsets.symmetric(horizontal: screenHorizontal(size));

  @override
  AppSpacing copyWith({
    double? xs,
    double? sm,
    double? md,
    double? lg,
    double? xl,
    double? screenH,
    double? screenHDesktop,
    double? cardGap,
    double? sectionGap,
    double? rowMinHeight,
    double? rowMinHeightTwoLine,
    double? touchTarget,
    double? hitInset,
  }) {
    return AppSpacing(
      xs: xs ?? this.xs,
      sm: sm ?? this.sm,
      md: md ?? this.md,
      lg: lg ?? this.lg,
      xl: xl ?? this.xl,
      screenH: screenH ?? this.screenH,
      screenHDesktop: screenHDesktop ?? this.screenHDesktop,
      cardGap: cardGap ?? this.cardGap,
      sectionGap: sectionGap ?? this.sectionGap,
      rowMinHeight: rowMinHeight ?? this.rowMinHeight,
      rowMinHeightTwoLine: rowMinHeightTwoLine ?? this.rowMinHeightTwoLine,
      touchTarget: touchTarget ?? this.touchTarget,
      hitInset: hitInset ?? this.hitInset,
    );
  }

  @override
  AppSpacing lerp(AppSpacing? other, double t) {
    if (other == null) return this;
    return AppSpacing(
      xs: lerpDouble(xs, other.xs, t),
      sm: lerpDouble(sm, other.sm, t),
      md: lerpDouble(md, other.md, t),
      lg: lerpDouble(lg, other.lg, t),
      xl: lerpDouble(xl, other.xl, t),
      screenH: lerpDouble(screenH, other.screenH, t),
      screenHDesktop: lerpDouble(screenHDesktop, other.screenHDesktop, t),
      cardGap: lerpDouble(cardGap, other.cardGap, t),
      sectionGap: lerpDouble(sectionGap, other.sectionGap, t),
      rowMinHeight: lerpDouble(rowMinHeight, other.rowMinHeight, t),
      rowMinHeightTwoLine:
          lerpDouble(rowMinHeightTwoLine, other.rowMinHeightTwoLine, t),
      touchTarget: lerpDouble(touchTarget, other.touchTarget, t),
      hitInset: lerpDouble(hitInset, other.hitInset, t),
    );
  }
}

/// Corner radii, named after what they wrap rather than their value.
@immutable
class AppRadii extends ThemeExtension<AppRadii> {
  const AppRadii({
    this.sheet = 28,
    this.dialog = 24,
    this.action = 16,
    this.card = 12,
    this.chip = 8,
    this.field = 4,
  });

  /// Bottom sheets (top corners) and the 56h search bar.
  final double sheet;
  final double dialog;

  /// Large 56h action buttons and the FAB.
  final double action;

  /// Cards, filled list tiles, thumbnails.
  final double card;

  /// Chips and posters.
  final double chip;

  /// Outlined text fields, subtitle preview pill.
  final double field;

  BorderRadius get sheetTop => BorderRadius.vertical(
        top: Radius.circular(sheet),
      );
  BorderRadius get cardAll => BorderRadius.circular(card);
  BorderRadius get chipAll => BorderRadius.circular(chip);

  @override
  AppRadii copyWith({
    double? sheet,
    double? dialog,
    double? action,
    double? card,
    double? chip,
    double? field,
  }) {
    return AppRadii(
      sheet: sheet ?? this.sheet,
      dialog: dialog ?? this.dialog,
      action: action ?? this.action,
      card: card ?? this.card,
      chip: chip ?? this.chip,
      field: field ?? this.field,
    );
  }

  @override
  AppRadii lerp(AppRadii? other, double t) {
    if (other == null) return this;
    return AppRadii(
      sheet: lerpDouble(sheet, other.sheet, t),
      dialog: lerpDouble(dialog, other.dialog, t),
      action: lerpDouble(action, other.action, t),
      card: lerpDouble(card, other.card, t),
      chip: lerpDouble(chip, other.chip, t),
      field: lerpDouble(field, other.field, t),
    );
  }
}

/// Colours the M3 `ColorScheme` has no slot for.
///
/// Everything else must come from `Theme.of(context).colorScheme` — the hexes
/// in the design spec are for verifying the generated scheme, not for
/// hard-coding into widgets.
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.success,
    required this.onSuccess,
    required this.offline,
    required this.ratingStar,
    required this.divider,
    required this.scrimStrong,
  });

  /// "Direct play" labels and online status dots.
  final Color success;
  final Color onSuccess;

  /// Disconnected status dots.
  final Color offline;

  final Color ratingStar;
  final Color divider;

  /// Player chrome scrims and overlay badges.
  final Color scrimStrong;

  static const light = AppSemanticColors(
    success: Color(0xFF2E7D5B),
    onSuccess: Color(0xFFFFFFFF),
    offline: Color(0xFFC1C7CE),
    ratingStar: Color(0xFFB98900),
    divider: Color(0xFFD3DBE3),
    scrimStrong: Color(0x8C000000), // rgba(0,0,0,.55)
  );

  static const dark = AppSemanticColors(
    success: Color(0xFF8FD8C6),
    onSuccess: Color(0xFF00382A),
    offline: Color(0xFF404A50),
    ratingStar: Color(0xFFE6C15A),
    divider: Color(0xFF2A3238),
    scrimStrong: Color(0x8C000000),
  );

  @override
  AppSemanticColors copyWith({
    Color? success,
    Color? onSuccess,
    Color? offline,
    Color? ratingStar,
    Color? divider,
    Color? scrimStrong,
  }) {
    return AppSemanticColors(
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      offline: offline ?? this.offline,
      ratingStar: ratingStar ?? this.ratingStar,
      divider: divider ?? this.divider,
      scrimStrong: scrimStrong ?? this.scrimStrong,
    );
  }

  @override
  AppSemanticColors lerp(AppSemanticColors? other, double t) {
    if (other == null) return this;
    return AppSemanticColors(
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      offline: Color.lerp(offline, other.offline, t)!,
      ratingStar: Color.lerp(ratingStar, other.ratingStar, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      scrimStrong: Color.lerp(scrimStrong, other.scrimStrong, t)!,
    );
  }
}

double lerpDouble(double a, double b, double t) => a + (b - a) * t;

/// Terse token access: `context.spacing.lg`, `context.radii.card`.
extension TokenAccess on BuildContext {
  AppSpacing get spacing => Theme.of(this).extension<AppSpacing>()!;
  AppRadii get radii => Theme.of(this).extension<AppRadii>()!;
  AppSemanticColors get semantic =>
      Theme.of(this).extension<AppSemanticColors>()!;
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get texts => Theme.of(this).textTheme;
  WindowSize get windowSize =>
      WindowSize.fromWidth(MediaQuery.sizeOf(this).width);
}
