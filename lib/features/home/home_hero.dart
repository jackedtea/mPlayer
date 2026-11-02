// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/television.dart';
import '../../app/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../servers/media_library_source.dart';
import '../../widgets/gradient_art.dart';
import '../../widgets/remote_art.dart';
import '../servers/server_library.dart';

/// The top of Home on anything wider than a phone: one item at a time,
/// across the whole width, with its backdrop, its overview and the two things
/// a person does with it.
///
/// What the phone's carousel shows as a row of cards. On a phone the
/// neighbours peeking in are the affordance — swipe — but a desktop has no
/// swipe and a television no pointer at all, and a row of five 460px cards on
/// a 1920px window was a strip of postcards with most of the screen unused.
///
/// It moves on by itself every [_dwell], and stops doing so while the pointer
/// is over it or focus is inside it: a banner that changes under a hovering
/// mouse, or under a remote about to press Play, swaps what was about to be
/// chosen.
class HomeHero extends ConsumerStatefulWidget {
  const HomeHero({super.key});

  @override
  ConsumerState<HomeHero> createState() => _HomeHeroState();
}

class _HomeHeroState extends ConsumerState<HomeHero> {
  static const _dwell = Duration(seconds: 9);

  int _index = 0;
  Timer? _timer;
  bool _hovering = false;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _restartTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _restartTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(_dwell, (_) {
      if (_hovering || _focused || !mounted) return;
      _step(1, fromTimer: true);
    });
  }

  void _step(int by, {bool fromTimer = false}) {
    final count = ref.read(homeResumeProvider).value?.length ?? 0;
    if (count < 2) return;
    setState(() => _index = (_index + by) % count);
    // A press is the user taking over; the next automatic step waits a full
    // dwell from it rather than landing a second later.
    if (!fromTimer) _restartTimer();
  }

  void _go(int index) {
    setState(() => _index = index);
    _restartTimer();
  }

  @override
  Widget build(BuildContext context) {
    final request = ref.watch(homeResumeProvider);
    final items = request.value ?? const <ServerItem>[];
    final television = ref.watch(isTelevisionProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final screen = MediaQuery.sizeOf(context);
        final height = television
            ? (screen.height * 0.62).clamp(260.0, 720.0)
            // Three quarters of a 16:9 backdrop's own height: at 0.36 the
            // crop took the heads off the characters in most anime art.
            : (constraints.maxWidth * 0.42).clamp(280.0, 600.0);

        if (items.isEmpty) {
          if (!request.isLoading) return const SizedBox.shrink();
          return SizedBox(
            height: height,
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        // A refresh can return fewer items than the one being shown.
        final index = _index.clamp(0, items.length - 1);
        final item = items[index];

        return MouseRegion(
          onEnter: (_) => _hovering = true,
          onExit: (_) => _hovering = false,
          child: Focus(
            canRequestFocus: false,
            skipTraversal: true,
            onFocusChange: (has) => _focused = has,
            child: SizedBox(
              height: height,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 600),
                    child: _Backdrop(key: ValueKey(item.id), item: item),
                  ),
                  const _Scrims(),
                  _Details(
                    item: item,
                    television: television,
                    width: constraints.maxWidth,
                  ),
                  if (items.length > 1)
                    Positioned(
                      right: context.spacing.screenHorizontal(
                        context.windowSize,
                      ),
                      bottom: context.spacing.xl,
                      child: _Pager(
                        count: items.length,
                        current: index,
                        onPrevious: () => _step(-1),
                        onNext: () => _step(1),
                        onSelected: _go,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Backdrop extends ConsumerWidget {
  const _Backdrop({super.key, required this.item});

  final ServerItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // An episode's own still is a frame from the middle of it; the series'
    // backdrop is the picture made to be shown this big.
    final art = backdropUrlFor(ref, item, maxWidth: 1920) ??
        artUrlFor(ref, item, maxWidth: 1280);

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        GradientArt(seed: item.id),
        // What the crop loses goes from the foot, which fades into the page,
        // rather than from the head.
        RemoteArt(url: art, alignment: const Alignment(0, -0.6)),
      ],
    );
  }
}

/// Dark from the left for the text to sit on, and a fade at the foot into
/// the page, so the banner runs into the shelves rather than ending on a
/// hard edge.
class _Scrims extends StatelessWidget {
  const _Scrims();

  @override
  Widget build(BuildContext context) {
    final surface = context.colors.surface;

    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                stops: <double>[0, 0.45, 0.8],
                colors: <Color>[
                  Color(0xE6000000),
                  Color(0x99000000),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                stops: const <double>[0, 0.28],
                colors: <Color>[surface, surface.withValues(alpha: 0)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Details extends ConsumerWidget {
  const _Details({
    required this.item,
    required this.television,
    required this.width,
  });

  final ServerItem item;
  final bool television;
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final texts = context.texts;
    final side = spacing.screenHorizontal(context.windowSize);

    final title = item.seriesTitle ?? item.title;
    final subtitle = <String>[
      if (item.seriesTitle != null) ...<String>[episodeCode(item), item.title],
      remainingLabel(item, l10n),
    ].where((s) => s.isNotEmpty).join(' · ');
    final overview = item.overview?.trim() ?? '';

    return Positioned(
      left: side,
      bottom: spacing.xl + spacing.lg,
      // Text over the dark half only: past that the backdrop is bare.
      width: (width * 0.5).clamp(280.0, 640.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: (television ? texts.displaySmall : texts.headlineMedium)
                ?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          if (subtitle.isNotEmpty) ...<Widget>[
            SizedBox(height: spacing.xs),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: texts.titleSmall?.copyWith(color: Colors.white70),
            ),
          ],
          if (overview.isNotEmpty) ...<Widget>[
            SizedBox(height: spacing.sm),
            Text(
              overview,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: texts.bodyMedium?.copyWith(color: Colors.white70),
            ),
          ],
          SizedBox(height: spacing.md),
          SizedBox(
            width: 240,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: item.watchedFraction ?? 0,
                minHeight: 3,
                backgroundColor: Colors.white24,
              ),
            ),
          ),
          SizedBox(height: spacing.lg),
          Wrap(
            spacing: spacing.sm,
            runSpacing: spacing.sm,
            children: <Widget>[
              FilledButton.icon(
                // On a television nothing else is focused when Home opens,
                // and the remote's first press should do the obvious thing.
                autofocus: television,
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(l10n.heroResume),
                onPressed: () => playServerItem(context, ref, item.id),
              ),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.info_outline_rounded),
                label: Text(l10n.heroDetails),
                onPressed: () => openServerItem(context, item),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Previous · dots · next. The arrows are buttons a remote can land on, which
/// the dots alone are too small to be.
class _Pager extends StatelessWidget {
  const _Pager({
    required this.count,
    required this.current,
    required this.onPrevious,
    required this.onNext,
    required this.onSelected,
  });

  final int count;
  final int current;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    // Its own dark pill: it sits where the banner fades into the page, which
    // is light under the light theme.
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(context.radii.sheet),
      ),
      child: _row(),
    );
  }

  Widget _row() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        IconButton(
          color: Colors.white,
          icon: const Icon(Icons.chevron_left_rounded),
          onPressed: onPrevious,
        ),
        for (var i = 0; i < count; i++)
          ExcludeFocus(
            child: InkResponse(
              onTap: () => onSelected(i),
              radius: 12,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  width: i == current ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == current ? Colors.white : Colors.white38,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
        IconButton(
          color: Colors.white,
          icon: const Icon(Icons.chevron_right_rounded),
          onPressed: onNext,
        ),
      ],
    );
  }
}
