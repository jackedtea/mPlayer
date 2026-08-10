// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';

/// Tonal gradient stand-in for artwork, exactly as the design canvas renders
/// placeholders. Real posters and thumbnails drop into the same box with no
/// layout change, so this stays as the fallback for missing/loading images.
///
/// The hue is derived from [seed] so a given title keeps the same colour
/// between rebuilds instead of flickering.
class GradientArt extends StatelessWidget {
  const GradientArt({
    super.key,
    required this.seed,
    this.icon,
    this.borderRadius,
  });

  final String seed;
  final IconData? icon;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hash = seed.codeUnits.fold<int>(0, (a, b) => (a * 31 + b) & 0x7FFFFFFF);
    final hue = (hash % 360).toDouble();
    final isDark = scheme.brightness == Brightness.dark;

    final base = HSLColor.fromAHSL(1, hue, 0.32, isDark ? 0.26 : 0.62).toColor();
    final tint = HSLColor.fromAHSL(
      1,
      (hue + 28) % 360,
      0.38,
      isDark ? 0.15 : 0.44,
    ).toColor();

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[base, tint],
        ),
      ),
      child: icon == null
          ? const SizedBox.expand()
          : Center(
              child: Icon(icon, size: 24, color: Colors.white.withValues(alpha: 0.35)),
            ),
    );
  }
}
