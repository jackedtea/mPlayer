// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

/// The two horizontal rows every server screen is built out of.
///
/// Extracted when the library screen grew a Suggestions tab: the server home
/// (1d) and that tab draw exactly the same shelves from different queries, and
/// two copies of the ink-inset arithmetic below is two places to get it wrong.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/television.dart';
import '../../app/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../servers/media_library_source.dart';
import '../../servers/server_registry.dart';
import '../../widgets/continue_watching_card.dart';
import '../../widgets/focus_ring.dart';
import '../../widgets/poster_tile.dart';
import 'server_library.dart';

/// How big a shelf's tiles are for a row [width] wide.
///
/// A phone keeps the design's fixed sizes. Past that the tiles grow with the
/// window, so a maximised desktop shows posters rather than a strip of
/// stamps, and a television shows fewer, larger ones still — read from across
/// a room and picked one at a time with a remote.
@immutable
class ShelfMetrics {
  const ShelfMetrics._({
    required this.posterWidth,
    required this.cardWidth,
    required this.focusRoom,
  });

  factory ShelfMetrics.of(
    BuildContext context, {
    required double width,
    required bool television,
  }) {
    if (context.windowSize.isCompact && !television) {
      return const ShelfMetrics._(
        posterWidth: ServerPosterShelf.posterWidth,
        cardWidth: 200,
        focusRoom: 0,
      );
    }
    return ShelfMetrics._(
      posterWidth: television
          ? (width / 6.2).clamp(120.0, 240.0)
          : (width / 8.5).clamp(ServerPosterShelf.posterWidth, 200.0),
      cardWidth: television
          ? (width / 3.4).clamp(220.0, 420.0)
          : (width / 4.6).clamp(200.0, 380.0),
      // Above and below the row, so a focused tile can grow without being
      // clipped by the list it sits in.
      focusRoom: context.spacing.sm,
    );
  }

  final double posterWidth;
  double get posterHeight => (posterWidth * 1.5).roundToDouble();
  final double cardWidth;
  double get cardArtHeight => (cardWidth * 9 / 16).roundToDouble();
  final double focusRoom;
}

/// A row of resume cards, or nothing at all.
///
/// An empty shelf renders as zero height rather than as an empty state: two
/// "nothing here" panels stacked above each other on a fresh server is worse
/// than a screen that simply starts at the next section. A shelf that has not
/// *arrived* yet is a different thing and shows a spinner — over a slow
/// connection that is what the user is actually looking at.
class ServerCardShelf extends ConsumerWidget {
  const ServerCardShelf({super.key, required this.items});

  final AsyncValue<List<ServerItem>> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final television = ref.watch(isTelevisionProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final m = ShelfMetrics.of(
          context,
          width: constraints.maxWidth,
          television: television,
        );
        final height = ContinueWatchingCard.outerHeight(
              context,
              artHeight: m.cardArtHeight,
            ) +
            m.focusRoom * 2;

        final resolved = items.value ?? const <ServerItem>[];
        if (resolved.isEmpty) {
          return items.isLoading
              ? SizedBox(
                  height: height,
                  child: const Center(child: CircularProgressIndicator()),
                )
              : const SizedBox.shrink();
        }

        final l10n = AppLocalizations.of(context);
        final serverName = ref.watch(serverRegistryProvider).active?.name ?? '';
        final radius = context.radii.card + context.spacing.hitInset;

        return ShelfRow(
          height: height,
          focusRoom: m.focusRoom,
          itemCount: resolved.length,
          itemBuilder: (context, i) => FocusRing(
            radius: radius,
            child: ContinueWatchingCard(
              item: resumeItemFrom(resolved[i], l10n, serverLabel: serverName),
              artUrl: artUrlFor(ref, resolved[i], maxWidth: 400),
              width: m.cardWidth,
              artHeight: m.cardArtHeight,
              // The card opens the item; the glyph in the middle of it
              // resumes. These shelves exist to carry on watching, so the
              // play button has to be the short way there rather than a third
              // tap into it.
              onTap: () => openServerItem(context, resolved[i]),
              onPlay: () => playServerItem(context, ref, resolved[i].id),
            ),
          ),
        );
      },
    );
  }
}

/// A row of posters — recently added, or a shelf of suggestions.
class ServerPosterShelf extends ConsumerWidget {
  const ServerPosterShelf({super.key, required this.items});

  final AsyncValue<List<ServerItem>> items;

  /// The phone size, and the smallest a poster gets anywhere.
  static const posterWidth = 104.0;
  static const posterHeight = 156.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final television = ref.watch(isTelevisionProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final m = ShelfMetrics.of(
          context,
          width: constraints.maxWidth,
          television: television,
        );
        final height =
            PosterTile.outerHeight(context, m.posterHeight) + m.focusRoom * 2;

        final resolved = items.value ?? const <ServerItem>[];
        if (resolved.isEmpty) {
          if (!items.isLoading) return const SizedBox.shrink();
          return SizedBox(
            height: height,
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        final radius = context.radii.chip + context.spacing.hitInset;

        return ShelfRow(
          height: height,
          focusRoom: m.focusRoom,
          itemCount: resolved.length,
          itemBuilder: (context, i) => FocusRing(
            radius: radius,
            child: PosterTile(
              item: libraryItemFrom(resolved[i]),
              artUrl: artUrlFor(ref, resolved[i], maxWidth: 400),
              width: m.posterWidth,
              posterHeight: m.posterHeight,
              onTap: () => openServerItem(context, resolved[i]),
            ),
          ),
        );
      },
    );
  }
}

/// The horizontal list under both shelves, with a pair of arrows on hover.
///
/// A mouse wheel scrolls vertically and a desktop has no swipe, so without
/// the arrows the only way along a row was to drag it. They are hidden on a
/// phone, where a swipe is the way, and kept out of focus traversal: a remote
/// walks the tiles themselves, and the list scrolls to keep the focused one in
/// view.
class ShelfRow extends StatefulWidget {
  const ShelfRow({
    super.key,
    required this.height,
    required this.itemCount,
    required this.itemBuilder,
    this.focusRoom = 0,
  });

  final double height;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double focusRoom;

  @override
  State<ShelfRow> createState() => _ShelfRowState();
}

class _ShelfRowState extends State<ShelfRow> {
  final _scroll = ScrollController();
  bool _hovering = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _page(int direction) {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    final target =
        (position.pixels + direction * position.viewportDimension * 0.8)
            .clamp(position.minScrollExtent, position.maxScrollExtent);
    _scroll.animateTo(
      target,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final inset = spacing.hitInset;
    final side = (spacing.screenHorizontal(context.windowSize) - inset)
        .clamp(0.0, double.infinity);
    final gap = (spacing.cardGap - inset * 2).clamp(0.0, double.infinity);

    final list = ListView.separated(
      controller: _scroll,
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(
        horizontal: side,
        vertical: widget.focusRoom,
      ),
      itemCount: widget.itemCount,
      separatorBuilder: (_, _) => SizedBox(width: gap),
      itemBuilder: widget.itemBuilder,
    );

    if (context.windowSize.isCompact) {
      return SizedBox(height: widget.height, child: list);
    }

    return SizedBox(
      height: widget.height,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: Stack(
          children: <Widget>[
            Positioned.fill(child: list),
            if (_hovering)
              Positioned.fill(
                child: ListenableBuilder(
                  listenable: _scroll,
                  builder: (context, _) {
                    final known = _scroll.hasClients &&
                        _scroll.position.hasContentDimensions;
                    final atStart = !known ||
                        _scroll.position.pixels <=
                            _scroll.position.minScrollExtent + 1;
                    final atEnd = !known ||
                        _scroll.position.pixels >=
                            _scroll.position.maxScrollExtent - 1;
                    return ExcludeFocus(
                      child: Stack(
                        children: <Widget>[
                          if (!atStart)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: _Arrow(
                                icon: Icons.chevron_left_rounded,
                                onPressed: () => _page(-1),
                              ),
                            ),
                          if (!atEnd)
                            Align(
                              alignment: Alignment.centerRight,
                              child: _Arrow(
                                icon: Icons.chevron_right_rounded,
                                onPressed: () => _page(1),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.spacing.xs),
      child: IconButton.filledTonal(icon: Icon(icon), onPressed: onPressed),
    );
  }
}
