// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/route_location.dart';
import '../../app/television.dart';
import '../../app/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/gradient_art.dart';
import '../../widgets/remote_art.dart';
import '../player/playback_controller.dart';
import 'audio_session.dart';

/// What is playing, docked at the foot of whatever is on screen. Tapping it
/// opens Now playing. Nothing at all while no music is playing.
///
/// Glyphs carry semantic labels rather than tooltips: [MiniPlayerHost] draws
/// this beside the navigator rather than inside it, where there is no overlay
/// for a tooltip to open in.
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key, required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(audioSessionProvider)) return const SizedBox.shrink();

    final state = ref.watch(playbackControllerProvider);
    final media = state.media;
    if (media == null) return const SizedBox.shrink();

    final session = ref.read(audioSessionProvider.notifier);
    final playback = ref.read(playbackControllerProvider.notifier);
    final spacing = context.spacing;
    final scheme = context.colors;
    final l10n = AppLocalizations.of(context);

    final duration = state.duration.inMilliseconds;
    final line = state.error ?? media.artist;

    return Material(
      color: scheme.surfaceContainerHigh,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          LinearProgressIndicator(
            value: duration <= 0
                ? 0
                : (state.position.inMilliseconds / duration).clamp(0.0, 1.0),
            minHeight: 2,
            backgroundColor: scheme.surfaceContainerHighest,
          ),
          InkWell(
            onTap: onOpen,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: spacing.sm,
                vertical: spacing.xs,
              ),
              child: Row(
                children: <Widget>[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(context.radii.thumb),
                    child: SizedBox.square(
                      dimension: 48,
                      child: Stack(
                        fit: StackFit.expand,
                        children: <Widget>[
                          GradientArt(seed: media.album ?? media.title),
                          RemoteArt(url: media.artworkUri),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: spacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          media.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.texts.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (line != null)
                          Text(
                            line,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.texts.bodySmall?.copyWith(
                              color: state.error != null
                                  ? scheme.error
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: session.togglePlaying,
                    icon: Icon(
                      state.playing
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      semanticLabel: state.playing ? l10n.pause : l10n.play,
                    ),
                  ),
                  IconButton(
                    onPressed: state.queue.hasNext ? playback.playNext : null,
                    icon: Icon(
                      Icons.skip_next_rounded,
                      semanticLabel: l10n.nextFile,
                    ),
                  ),
                  IconButton(
                    onPressed: () => unawaited(session.end()),
                    icon: Icon(
                      Icons.close_rounded,
                      semanticLabel: l10n.stopPlayback,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Whether the shell draws the mini player itself, above its navigation bar.
///
/// A phone's shell does. A rail and a drawer run down the side and have no bar
/// to sit above, so there [MiniPlayerHost] draws it across the whole window.
bool miniPlayerInShell(BuildContext context, WidgetRef ref) =>
    context.windowSize == WindowSize.compact &&
    !ref.watch(isTelevisionProvider);

/// Docks the mini player under every route that does not place its own.
///
/// Beside the navigator rather than in each screen: `/library` and everything
/// reached from it, album and artist pages included, sit above the shell, so
/// a mini player only in the shell would vanish the moment a song started
/// from one of them.
///
/// The same widgets whatever the answer, for the reason `_InsetFromSystemBars`
/// gives: changing the shape of the tree above the navigator rebuilds it, and
/// takes the route stack with it.
class MiniPlayerHost extends ConsumerWidget {
  const MiniPlayerHost({super.key, required this.router, required this.child});

  final GoRouter router;
  final Widget child;

  /// The shell's branches, which on a phone place the mini player themselves.
  static const _shellRoutes = <String>{
    'home',
    'libraries',
    'search',
    'downloads',
    'settings',
  };

  /// Screens that are the player. The video player has one decoder to itself,
  /// and Now playing is already showing all of this.
  static const _playerRoutes = <String>{'player', 'now-playing', 'smoke'};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inShell = miniPlayerInShell(context, ref);

    return Column(
      children: <Widget>[
        Expanded(child: child),
        ListenableBuilder(
          listenable: router.routerDelegate,
          builder: (context, _) {
            final route = topRoutePath(router).split('/').skip(1).firstOrNull;

            if (_playerRoutes.contains(route) ||
                (inShell && _shellRoutes.contains(route)) ||
                // The keyboard is up and would only cover it.
                MediaQuery.viewInsetsOf(context).bottom > 0) {
              return const SizedBox.shrink();
            }
            return MiniPlayer(onOpen: () => router.push('/now-playing'));
          },
        ),
      ],
    );
  }
}
