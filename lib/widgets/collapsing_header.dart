// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../app/tokens.dart';
import '../l10n/app_localizations.dart';

/// A detail screen's header as a sliver: measured on its first layout, then
/// collapsing under a pinned toolbar that keeps [title] on screen.
///
/// Shared by the series and movie screens, so the two scroll the same way.
/// The header's natural height depends on its title, facts and the window's
/// width, and the collapse needs it before it can say how far to go — so
/// until it has laid out once it is drawn as a plain sliver.
class CollapsingHeaderSliver extends StatefulWidget {
  const CollapsingHeaderSliver({
    super.key,
    required this.title,
    required this.header,
  });

  final String title;
  final Widget header;

  @override
  State<CollapsingHeaderSliver> createState() => _CollapsingHeaderSliverState();
}

class _CollapsingHeaderSliverState extends State<CollapsingHeaderSliver> {
  /// Re-measured whenever it changes, as it does on rotation.
  double? _height;

  void _setHeight(Size size) {
    if (!mounted || _height == size.height) return;
    setState(() => _height = size.height);
  }

  @override
  Widget build(BuildContext context) {
    final measured = _height;
    if (measured == null) {
      return SliverToBoxAdapter(
        child: MeasureSize(onSize: _setHeight, child: widget.header),
      );
    }
    return SliverPersistentHeader(
      pinned: true,
      delegate: _CollapsingHeader(
        header: widget.header,
        height: measured,
        title: widget.title,
        topInset: context.systemTopInset,
        background: context.colors.surface,
        brightness: Theme.of(context).brightness,
        backTooltip: AppLocalizations.of(context).actionBack,
        onSize: _setHeight,
      ),
    );
  }
}

/// The detail header, scrolling away under a toolbar that keeps the title.
///
/// The backdrop, poster and facts scroll up as they always did; over the last
/// stretch of the collapse a solid bar fades in under the status bar with the
/// back arrow and the series' name, and stays pinned there. The page runs
/// edge to edge for the backdrop, and this bar is also what keeps everything
/// pinned below it — the season tabs — out from under the clock.
class _CollapsingHeader extends SliverPersistentHeaderDelegate {
  _CollapsingHeader({
    required this.header,
    required this.height,
    required this.title,
    required this.topInset,
    required this.background,
    required this.brightness,
    required this.backTooltip,
    required this.onSize,
  });

  final Widget header;

  /// The header's measured natural height.
  final double height;
  final String title;
  final double topInset;
  final Color background;
  final Brightness brightness;
  final String backTooltip;
  final ValueChanged<Size> onSize;

  /// How much of the collapse the toolbar takes to fade in.
  static const _fade = 48.0;

  @override
  double get minExtent => topInset + kToolbarHeight;

  @override
  double get maxExtent => height < minExtent ? minExtent : height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    final range = maxExtent - minExtent;
    final shown = range <= 0
        ? 1.0
        : ((shrinkOffset - (range - _fade)) / _fade).clamp(0.0, 1.0);

    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // At its natural height, slid up by however far the page has
          // scrolled — so it scrolls rather than squashing — and measured
          // again in case that height changes.
          Positioned(
            top: -shrinkOffset,
            left: 0,
            right: 0,
            child: MeasureSize(onSize: onSize, child: header),
          ),
          if (shown > 0)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: minExtent,
              child: IgnorePointer(
                ignoring: shown < 0.5,
                child: Opacity(
                  opacity: shown,
                  child: _annotated(
                    shown >= 0.5,
                    Material(
                      color: background,
                      child: Padding(
                        padding: EdgeInsets.only(top: topInset),
                        child: Row(
                          children: <Widget>[
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.arrow_back_rounded),
                              tooltip: backTooltip,
                              onPressed: () {
                                if (context.canPop()) context.pop();
                              },
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.texts.titleLarge,
                              ),
                            ),
                            const SizedBox(width: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Status-bar icons for the page colour once the bar is mostly in; until
  /// then the backdrop under them annotates its own.
  Widget _annotated(bool solid, Widget child) {
    if (!solid) return child;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: child,
    );
  }

  @override
  bool shouldRebuild(_CollapsingHeader old) => true;
}

/// Reports its child's size after every layout that changes it.
///
/// Used for the series header, whose height depends on its title, facts and
/// the window's width, and which the collapsing header needs before it can
/// say how far to collapse.
class MeasureSize extends SingleChildRenderObjectWidget {
  const MeasureSize({super.key, required this.onSize, required super.child});

  final ValueChanged<Size> onSize;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderMeasureSize(onSize);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderMeasureSize renderObject,
  ) {
    renderObject.onSize = onSize;
  }
}

class RenderMeasureSize extends RenderProxyBox {
  RenderMeasureSize(this.onSize);

  ValueChanged<Size> onSize;
  Size? _last;

  @override
  void performLayout() {
    super.performLayout();
    if (size == _last) return;
    _last = size;
    // After the frame: reporting during layout would ask for a rebuild in
    // the middle of one.
    final reported = size;
    WidgetsBinding.instance.addPostFrameCallback((_) => onSize(reported));
  }
}
