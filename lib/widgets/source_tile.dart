// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';

import '../app/tokens.dart';
import '../core/models/media_models.dart';

/// Filled tile on `surfaceContainerLow` with a white circular leading icon and
/// a trailing status dot — the Network rows on Storage (1a) and the
/// "Where to look" rows on Search (1n).
class SourceTile extends StatelessWidget {
  const SourceTile({
    super.key,
    required this.source,
    this.subtitleOverride,
    this.trailing,
    this.onTap,
  });

  final MediaSourceRef source;

  /// Replaces [MediaSourceRef.detail] — Search shows capability text instead.
  final String? subtitleOverride;

  /// Defaults to a status dot; Search passes a checkbox.
  final Widget? trailing;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final scheme = context.colors;
    final offline = !source.online;

    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: context.radii.cardAll,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: spacing.rowMinHeight),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: spacing.lg,
              vertical: spacing.md,
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: scheme.brightness == Brightness.light
                        ? Colors.white
                        : scheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(source.kind.icon, size: 22, color: scheme.primary),
                ),
                SizedBox(width: spacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        source.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.texts.bodyLarge
                            ?.copyWith(color: scheme.onSurface),
                      ),
                      Text(
                        subtitleOverride ?? source.detail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.texts.bodySmall?.copyWith(
                          color: offline
                              ? scheme.outline
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: spacing.md),
                trailing ?? _StatusDot(online: source.online),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 8px dot: success green when reachable, outline grey when not.
class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.online});

  final bool online;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;
    return Semantics(
      label: online ? 'Connected' : 'Offline',
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: online ? semantic.success : semantic.offline,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// Dashed-outline "add a source" row that closes the Network list.
class AddSourceTile extends StatelessWidget {
  const AddSourceTile({
    super.key,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final scheme = context.colors;

    return InkWell(
      onTap: onTap,
      borderRadius: context.radii.cardAll,
      child: DottedOutline(
        borderRadius: context.radii.cardAll,
        color: scheme.outlineVariant,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: spacing.rowMinHeight),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: spacing.lg,
              vertical: spacing.md,
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    border: Border.all(color: scheme.outlineVariant),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.add_rounded,
                    size: 22,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                SizedBox(width: spacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        title,
                        style: context.texts.bodyLarge
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                      Text(
                        subtitle,
                        style: context.texts.bodySmall
                            ?.copyWith(color: scheme.outline),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Rounded dashed border. Flutter has no dashed `BoxBorder`, so this paints
/// the path manually rather than faking it with an image.
class DottedOutline extends StatelessWidget {
  const DottedOutline({
    super.key,
    required this.child,
    required this.borderRadius,
    required this.color,
    this.dash = 5,
    this.gap = 4,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final Color color;
  final double dash;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(
        borderRadius: borderRadius,
        color: color,
        dash: dash,
        gap: gap,
      ),
      child: child,
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({
    required this.borderRadius,
    required this.color,
    required this.dash,
    required this.gap,
  });

  final BorderRadius borderRadius;
  final Color color;
  final double dash;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final rrect = borderRadius.toRRect(Offset.zero & size).deflate(0.5);
    final path = Path()..addRRect(rrect);

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = (distance + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color ||
      old.borderRadius != borderRadius ||
      old.dash != dash ||
      old.gap != gap;
}
