// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';

import 'tokens.dart';

/// Sky blue, per the design spec. Schemes are seeded from this and then
/// pinned to the exact role values the spec lists, so generator changes in a
/// future Flutter release cannot silently shift the palette.
const seedColor = Color(0xFF0A6E9E);

/// Light is the default theme — the spec is explicit about this.
ColorScheme _lightScheme() {
  return ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: Brightness.light,
  ).copyWith(
    primary: const Color(0xFF00658F),
    onPrimary: const Color(0xFFFFFFFF),
    primaryContainer: const Color(0xFFC7E7FF),
    onPrimaryContainer: const Color(0xFF001E2E),
    surface: const Color(0xFFF6FAFE),
    onSurface: const Color(0xFF191C1E),
    onSurfaceVariant: const Color(0xFF41484D),
    surfaceContainerLow: const Color(0xFFECF1F8),
    surfaceContainer: const Color(0xFFEAEFF6),
    surfaceContainerHigh: const Color(0xFFE6ECF4),
    surfaceContainerHighest: const Color(0xFFDDE3EA),
    outline: const Color(0xFF71787E),
    outlineVariant: const Color(0xFFC1C7CE),
    error: const Color(0xFFBA1A1A),
  );
}

ColorScheme _darkScheme() {
  return ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: Brightness.dark,
  ).copyWith(
    primary: const Color(0xFF82CFFF),
    primaryContainer: const Color(0xFF004C6D),
    onPrimaryContainer: const Color(0xFFC7E7FF),
    surface: const Color(0xFF0F1417),
    onSurface: const Color(0xFFDEE3E7),
    onSurfaceVariant: const Color(0xFFBFC8CE),
    surfaceContainer: const Color(0xFF1A2125),
    outline: const Color(0xFF404A50),
    error: const Color(0xFFFFB4AB),
  );
}

/// True black surfaces for OLED screens, applied on top of the dark scheme.
///
/// Only the surface roles move. Recolouring the containers to pure black too
/// would erase the elevation steps the design relies on to separate a sheet
/// from the page behind it.
ColorScheme _pureBlackify(ColorScheme scheme) {
  return scheme.copyWith(
    surface: const Color(0xFF000000),
    surfaceContainerLowest: const Color(0xFF000000),
    surfaceContainerLow: const Color(0xFF0A0A0A),
  );
}

/// Builds the app theme.
///
/// [accent] null — or the design's own [seedColor] — keeps the palette the
/// spec pins role by role. Any other accent means the user has deliberately
/// left that palette, so the scheme is generated from their colour instead
/// and only the tokens and component shapes carry over.
///
/// [dynamicScheme] wins over both: it is the system wallpaper palette, which
/// only Android 12+ supplies.
ThemeData buildTheme(
  Brightness brightness, {
  Color? accent,
  ColorScheme? dynamicScheme,
  bool pureBlack = false,
}) {
  final isLight = brightness == Brightness.light;

  var scheme = switch ((dynamicScheme, accent)) {
    (final ColorScheme d, _) => d.harmonized(),
    (_, final Color a) when a != seedColor =>
      ColorScheme.fromSeed(seedColor: a, brightness: brightness),
    _ => isLight ? _lightScheme() : _darkScheme(),
  };
  if (!isLight && pureBlack) scheme = _pureBlackify(scheme);

  final semantic = isLight ? AppSemanticColors.light : AppSemanticColors.dark;
  const spacing = AppSpacing();
  const radii = AppRadii();

  return ThemeData(
    colorScheme: scheme,
    // Bundled variable Roboto — see pubspec. Without this, only Android would
    // render the design's typeface; the other platforms fall back to Segoe UI
    // / SF / Cantarell and the whole type scale drifts.
    fontFamily: 'Roboto',
    // Stock M3 TextTheme — the size/leading/tracking values in the spec are
    // the M3 defaults, so overriding them would only introduce drift.
    extensions: <ThemeExtension<dynamic>>[spacing, radii, semantic],
    scaffoldBackgroundColor: scheme.surface,
    dividerTheme: DividerThemeData(
      color: semantic.divider,
      thickness: 1,
      space: 1,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      // titleTextStyle is left to M3: it already resolves to titleLarge in
      // onSurface, and setting it here would bypass the themed font family.
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surfaceContainer,
      indicatorColor: scheme.primaryContainer,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 80,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: scheme.primaryContainer,
      useIndicator: true,
    ),
    navigationDrawerTheme: NavigationDrawerThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      indicatorColor: scheme.primaryContainer,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainer,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: RoundedRectangleBorder(borderRadius: radii.sheetTop),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primaryContainer,
      foregroundColor: scheme.onPrimaryContainer,
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radii.action),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: radii.chipAll),
      side: BorderSide(color: scheme.outline),
      backgroundColor: Colors.transparent,
      selectedColor: scheme.primaryContainer,
      showCheckmark: true,
      checkmarkColor: scheme.onPrimaryContainer,
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radii.field),
      ),
    ),
    searchBarTheme: SearchBarThemeData(
      backgroundColor: WidgetStatePropertyAll(scheme.surfaceContainerHigh),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      elevation: const WidgetStatePropertyAll(0),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(radii.sheet)),
      ),
    ),
    listTileTheme: const ListTileThemeData(minVerticalPadding: 12),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: radii.cardAll),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
      },
    ),
  );
}
