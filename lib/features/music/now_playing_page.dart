// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:math' show min;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/tokens.dart';
import '../../cast/cast_device.dart';
import '../../l10n/app_localizations.dart';
import '../../sources/media_source.dart';
import '../../widgets/gradient_art.dart';
import '../../widgets/remote_art.dart';
import '../cast/cast_controller.dart';
import '../cast/cast_sheet.dart';
import '../cast/casting_overlay.dart';
import '../player/playback_controller.dart';
import '../player/playback_state.dart';
import '../servers/item_actions.dart';
import '../servers/server_library.dart';
import 'audio_session.dart';
import 'music_widgets.dart';

/// The second face of the player: large art, a seek bar and the transport.
///
/// On a phone the queue is a sheet behind a button; where there is room it
/// stands beside the art. Leaving the screen leaves the music playing.
class NowPlayingPage extends ConsumerWidget {
  const NowPlayingPage({super.key});

  /// Media keys, and Escape to leave. Arrows are left to focus traversal, so a
  /// remote can walk the buttons; the video player can take them for seeking
  /// because its chrome hides, and this screen is nothing but buttons.
  KeyEventResult _onKey(BuildContext context, WidgetRef ref, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final session = ref.read(audioSessionProvider.notifier);
    final playback = ref.read(playbackControllerProvider.notifier);

    switch (event.logicalKey) {
      case LogicalKeyboardKey.mediaPlayPause:
      case LogicalKeyboardKey.keyK:
        session.togglePlaying();
      case LogicalKeyboardKey.mediaTrackNext:
        playback.playNext();
      case LogicalKeyboardKey.mediaTrackPrevious:
        session.previous();
      case LogicalKeyboardKey.escape:
        if (context.canPop()) context.pop();
      default:
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final media = ref.watch(playbackControllerProvider.select((s) => s.media));
    final compact = context.windowSize == WindowSize.compact;

    final back = IconButton(
      icon: const Icon(Icons.keyboard_arrow_down_rounded),
      tooltip: l10n.actionBack,
      onPressed: () => context.pop(),
    );

    if (media == null) {
      return Scaffold(
        appBar: AppBar(leading: back),
        body: MusicNote(text: l10n.nothingHere),
      );
    }

    // The television is playing it now, and this screen becomes its remote,
    // as the video player does.
    final cast = ref.watch(castControllerProvider);
    if (cast.isCasting) {
      return CastingOverlay(
        device: cast.device!,
        title: media.title,
        status: cast.status,
        onPlayPause: ref.read(castControllerProvider.notifier).playOrPause,
        onSeek: ref.read(castControllerProvider.notifier).seek,
        onStop: () => ref.read(castControllerProvider.notifier).disconnect(),
        onBack: () => context.pop(),
      );
    }

    return Focus(
      onKeyEvent: (_, event) => _onKey(context, ref, event),
      child: Scaffold(
        appBar: AppBar(
          leading: back,
          title: Text(l10n.nowPlaying),
          actions: <Widget>[
            _FavouriteButton(itemId: media.ref.itemId),
            IconButton(
              icon: const Icon(Icons.cast_rounded),
              tooltip: l10n.playOn,
              onPressed: () => _pickCastDevice(context, ref, media),
            ),
            if (compact)
              IconButton(
                icon: const Icon(Icons.queue_music_rounded),
                tooltip: l10n.queue,
                onPressed: () => _showQueue(context),
              ),
          ],
        ),
        body: compact
            ? _ArtAndControls(media: media)
            : Row(
                children: <Widget>[
                  Expanded(child: _ArtAndControls(media: media)),
                  VerticalDivider(width: 1, color: context.semantic.divider),
                  const SizedBox(width: 360, child: _QueueList()),
                ],
              ),
      ),
    );
  }

  /// Hands the song to a device on the network. Paused here rather than
  /// stopped, so coming back carries on where the room left off.
  Future<void> _pickCastDevice(
    BuildContext context,
    WidgetRef ref,
    PlayableMedia media,
  ) {
    return CastSheet.show(
      context,
      onSelected: (CastDevice device) async {
        final messenger = ScaffoldMessenger.maybeOf(context);
        final l10n = AppLocalizations.of(context);
        final from = ref.read(playbackControllerProvider).position;

        await ref.read(playbackControllerProvider.notifier).pause();
        final started = await ref
            .read(castControllerProvider.notifier)
            .castTo(device, media, from: from);
        if (started) return;

        final error = ref.read(castControllerProvider).error;
        messenger?.showSnackBar(
          SnackBar(content: Text(error ?? l10n.couldNotCast)),
        );
      },
    );
  }

  Future<void> _showQueue(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: const _QueueList(),
      ),
    );
  }
}

/// The cover, as large as the controls leave room for.
class _ArtAndControls extends ConsumerWidget {
  const _ArtAndControls({required this.media});

  final PlayableMedia media;

  /// What the controls under the art need. Asked for rather than measured, so
  /// the art is a fixed size while a title of one line or two comes and goes.
  static const _controlsHeight = 300.0;

  /// Under this a cover says nothing, and the window is better spent on the
  /// controls: a phone on its side.
  static const _smallestArt = 120.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = context.spacing;
    final gutter = spacing.screenHorizontal(context.windowSize);

    return LayoutBuilder(
      builder: (context, box) {
        final side = min(
          min(box.maxWidth - gutter * 2, box.maxHeight - _controlsHeight),
          560.0,
        );

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: gutter),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: box.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                if (side >= _smallestArt) ...<Widget>[
                  ClipRRect(
                    borderRadius: context.radii.cardAll,
                    child: SizedBox.square(
                      dimension: side,
                      child: Stack(
                        fit: StackFit.expand,
                        children: <Widget>[
                          GradientArt(
                            seed: media.album ?? media.title,
                            icon: Icons.album_rounded,
                          ),
                          RemoteArt(url: media.artworkUri),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: spacing.lg),
                ],
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: _Controls(media: media),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Controls extends ConsumerStatefulWidget {
  const _Controls({required this.media});

  final PlayableMedia media;

  @override
  ConsumerState<_Controls> createState() => _ControlsState();
}

class _ControlsState extends ConsumerState<_Controls> {
  /// While the user drags, the bar follows the finger rather than the position
  /// stream, which would fight it.
  double? _drag;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playbackControllerProvider);
    final session = ref.read(audioSessionProvider.notifier);
    final playback = ref.read(playbackControllerProvider.notifier);
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final scheme = context.colors;
    final media = widget.media;

    final credits = <String>[?media.artist, ?media.album].join(' · ');
    final duration = state.duration;
    final known = duration > Duration.zero;
    final progress =
        _drag ??
        (known
            ? (state.position.inMilliseconds / duration.inMilliseconds).clamp(
                0.0,
                1.0,
              )
            : 0.0);
    final shown = _drag == null ? state.position : duration * _drag!;
    final timeStyle = context.texts.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          media.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: context.texts.titleLarge,
        ),
        if (credits.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: spacing.xs),
            child: Text(
              credits,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.texts.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        if (state.error != null)
          Padding(
            padding: EdgeInsets.only(top: spacing.xs),
            child: Text(
              state.error!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: context.texts.bodySmall?.copyWith(color: scheme.error),
            ),
          ),
        SizedBox(height: spacing.sm),
        Slider(
          value: progress,
          onChanged: known ? (v) => setState(() => _drag = v) : null,
          onChangeEnd: known
              ? (v) {
                  setState(() => _drag = null);
                  playback.seek(duration * v);
                }
              : null,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(formatDuration(shown), style: timeStyle),
            Text(known ? formatDuration(duration) : '', style: timeStyle),
          ],
        ),
        SizedBox(height: spacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            IconButton(
              tooltip: l10n.shuffle,
              isSelected: state.queue.isShuffled,
              color: scheme.onSurfaceVariant,
              selectedIcon: Icon(Icons.shuffle_rounded, color: scheme.primary),
              icon: const Icon(Icons.shuffle_rounded),
              onPressed: state.queue.hasSiblings
                  ? () => playback.setShuffle(!state.queue.isShuffled)
                  : null,
            ),
            IconButton(
              tooltip: l10n.previousFile,
              iconSize: 36,
              icon: const Icon(Icons.skip_previous_rounded),
              onPressed: session.previous,
            ),
            SizedBox.square(
              dimension: 72,
              child: state.buffering && !state.playing
                  ? const Center(child: CircularProgressIndicator())
                  : IconButton.filled(
                      autofocus: true,
                      iconSize: 40,
                      tooltip: state.playing ? l10n.pause : l10n.play,
                      icon: Icon(
                        state.playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                      ),
                      onPressed: session.togglePlaying,
                    ),
            ),
            IconButton(
              tooltip: l10n.nextFile,
              iconSize: 36,
              icon: const Icon(Icons.skip_next_rounded),
              onPressed: state.queue.hasNext ? playback.playNext : null,
            ),
            IconButton(
              tooltip: switch (state.loop) {
                LoopMode.off => l10n.repeatOff,
                LoopMode.one => l10n.repeatOne,
                LoopMode.all => l10n.repeatAll,
              },
              isSelected: state.loop != LoopMode.off,
              color: scheme.onSurfaceVariant,
              selectedIcon: Icon(
                state.loop == LoopMode.one
                    ? Icons.repeat_one_rounded
                    : Icons.repeat_rounded,
                color: scheme.primary,
              ),
              icon: const Icon(Icons.repeat_rounded),
              onPressed: playback.cycleLoop,
            ),
          ],
        ),
      ],
    );
  }
}

/// The star for what is playing. Absent for a song with no server to ask,
/// such as a download played with nothing signed in.
class _FavouriteButton extends ConsumerWidget {
  const _FavouriteButton({required this.itemId});

  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(serverItemProvider(itemId)).value;
    if (item == null) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);

    return IconButton(
      tooltip: item.favourite ? l10n.removeFavourite : l10n.addFavourite,
      icon: Icon(
        item.favourite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
      ),
      onPressed: () async {
        final messenger = ScaffoldMessenger.of(context);
        final ok = await setFavourite(
          ref,
          item.id,
          favourite: !item.favourite,
        );
        if (!ok) {
          messenger.showSnackBar(SnackBar(content: Text(l10n.actionFailed)));
        }
      },
    );
  }
}

/// What plays after what. Tapping a row jumps to it; the handle rearranges,
/// and the cross takes a row out. What is playing has no cross: it is stopped
/// or stepped past, not deleted from under the decoder.
class _QueueList extends ConsumerStatefulWidget {
  const _QueueList();

  @override
  ConsumerState<_QueueList> createState() => _QueueListState();
}

class _QueueListState extends ConsumerState<_QueueList> {
  static const _rowHeight = 56.0;

  /// Opens with the current song in view, not at the top of a long album.
  late final ScrollController _scroll = ScrollController(
    initialScrollOffset:
        ref.read(playbackControllerProvider).queue.index * _rowHeight,
  );

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final queue = ref.watch(playbackControllerProvider.select((s) => s.queue));
    final playback = ref.read(playbackControllerProvider.notifier);
    final spacing = context.spacing;
    final padding = EdgeInsets.symmetric(horizontal: spacing.lg);

    // A song can be queued twice, and a reorderable row needs a key of its
    // own: its id and which time round this is.
    final seen = <String, int>{};
    final keys = <Key>[
      for (final MediaRef item in queue.items)
        ValueKey<String>(
          '${item.itemId}#${seen[item.itemId] = (seen[item.itemId] ?? 0) + 1}',
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: padding.copyWith(top: spacing.sm, bottom: spacing.xs),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(l10n.queue, style: context.texts.titleMedium),
              ),
              if (queue.hasSiblings)
                TextButton(
                  onPressed: playback.clearQueue,
                  child: Text(l10n.clearAll),
                ),
            ],
          ),
        ),
        Expanded(
          child: queue.isEmpty
              ? MusicNote(text: l10n.queueEmpty)
              : ReorderableListView.builder(
                  scrollController: _scroll,
                  itemExtent: _rowHeight,
                  buildDefaultDragHandles: false,
                  itemCount: queue.items.length,
                  onReorderItem: playback.moveInQueue,
                  itemBuilder: (context, i) => ListTile(
                    key: keys[i],
                    contentPadding: EdgeInsetsDirectional.only(
                      start: spacing.lg,
                      end: spacing.sm,
                    ),
                    selected: i == queue.index,
                    leading: i == queue.index
                        ? const Icon(Icons.equalizer_rounded)
                        : SizedBox(
                            width: 24,
                            child: Center(child: Text('${i + 1}')),
                          ),
                    title: Text(
                      queue.items[i].title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        if (i != queue.index)
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            tooltip: l10n.removeFromQueue,
                            onPressed: () => playback.removeFromQueue(i),
                          ),
                        ReorderableDragStartListener(
                          index: i,
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(Icons.drag_handle_rounded),
                          ),
                        ),
                      ],
                    ),
                    onTap: () => playback.playAt(i),
                  ),
                ),
        ),
      ],
    );
  }
}
