// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../servers/media_library_source.dart';
import '../../servers/stream_preferences.dart';
import '../../widgets/backdrop_header.dart';
import 'detail_sections.dart';
import 'item_action_row.dart';
import 'server_library.dart';

/// One episode, with its tracks chosen before anything starts playing.
///
/// The point of the screen: a server knows every audio and subtitle track a
/// file has *before* it sends a byte of it, so the choice can be made here
/// rather than three taps into a player that already started in the wrong
/// language. It also matters more here than for a local file — a transcode
/// bakes the choice in, and once the server has started re-encoding there is
/// nothing left for the player to switch to.
class EpisodePage extends ConsumerStatefulWidget {
  const EpisodePage({super.key, this.episodeId});

  /// Null when the route was opened directly rather than from a row.
  final String? episodeId;

  @override
  ConsumerState<EpisodePage> createState() => _EpisodePageState();
}

class _EpisodePageState extends ConsumerState<EpisodePage> {
  /// Null means "as the server would". Chosen values are the server's own
  /// stream indexes, not positions in any list drawn here.
  int? _audioIndex;
  int? _subtitleIndex;
  bool _audioTouched = false;
  bool _subtitleTouched = false;

  bool _overviewExpanded = false;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final l10n = AppLocalizations.of(context);
    final episodeId = widget.episodeId;

    final request = episodeId == null
        ? const AsyncValue<ServerItem?>.data(null)
        : ref.watch(serverItemProvider(episodeId));
    final item = request.value;

    if (item == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: request.isLoading
              ? const CircularProgressIndicator()
              : Text(l10n.nothingToPlay),
        ),
      );
    }

    final playback = ref.watch(playbackInfoProvider(item.id)).value;
    final padding = spacing.screenPadding(context.windowSize);
    final siblings = item.seriesId == null
        ? const <ServerItem>[]
        : ref.watch(seriesEpisodesProvider(item.seriesId!)).value ??
            const <ServerItem>[];

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.only(
          bottom: spacing.xl * 2 + context.systemBottomInset,
        ),
        children: <Widget>[
          BackdropHeader(
            seed: item.title,
            artUrl: artUrlFor(ref, item, maxWidth: 900),
            height: 220,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (item.seriesTitle != null)
                  Text(
                    item.seriesTitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.texts.bodyMedium
                        ?.copyWith(color: context.colors.onSurfaceVariant),
                  ),
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.texts.headlineSmall,
                ),
                SizedBox(height: spacing.xs),
                Text(
                  _metaLine(item, l10n),
                  style: context.texts.bodySmall
                      ?.copyWith(color: context.colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Padding(
            padding: padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ItemActionRow(
                  item: item,
                  seriesId: item.seriesId,
                  shuffleFrom: siblings,
                  playlistIds: <String>[item.id],
                  onPlay: () => _play(item, playback),
                  onStartOver: () => _play(item, playback, fromStart: true),
                  onMediaInfo: playback == null
                      ? null
                      : () => _showMediaInfo(playback),
                ),
                if ((item.overview ?? '').isNotEmpty) ...<Widget>[
                  SizedBox(height: spacing.lg),
                  _Overview(
                    text: item.overview!,
                    expanded: _overviewExpanded,
                    onToggle: () =>
                        setState(() => _overviewExpanded = !_overviewExpanded),
                  ),
                ],
                SizedBox(height: spacing.lg),
                _TrackPickers(
                  playback: playback,
                  audioIndex: _effectiveAudio(playback),
                  subtitleIndex: _effectiveSubtitle(playback),
                  onAudio: (i) => setState(() {
                    _audioIndex = i;
                    _audioTouched = true;
                  }),
                  onSubtitle: (i) => setState(() {
                    _subtitleIndex = i;
                    _subtitleTouched = true;
                  }),
                ),
              ],
            ),
          ),
          if (item.people.isNotEmpty) ...<Widget>[
            Padding(
              padding: padding.copyWith(top: spacing.xl, bottom: spacing.md),
              child: Text(l10n.cast, style: context.texts.titleMedium),
            ),
            PeopleStrip(people: item.people),
          ],
        ],
      ),
    );
  }

  /// What the pickers show: the user's choice if they made one, otherwise
  /// what the server said it would do.
  int? _effectiveAudio(ServerPlayback? playback) =>
      _audioTouched ? _audioIndex : playback?.defaultAudioIndex;

  int? _effectiveSubtitle(ServerPlayback? playback) =>
      _subtitleTouched ? _subtitleIndex : playback?.defaultSubtitleIndex;

  Future<void> _play(
    ServerItem item,
    ServerPlayback? playback, {
    bool fromStart = false,
  }) async {
    // Recorded against this item's id, so a choice cannot leak onto whatever
    // is played next — the indexes mean something entirely different there.
    ref.read(trackChoiceProvider.notifier).set(
          _audioTouched || _subtitleTouched
              ? TrackChoice(
                  itemId: item.id,
                  audioStreamIndex: _effectiveAudio(playback),
                  subtitleStreamIndex: _effectiveSubtitle(playback),
                  mediaSourceId: playback?.mediaSourceId,
                )
              : null,
        );

    await playServerItem(context, ref, item.id, fromStart: fromStart);
  }

  void _showMediaInfo(ServerPlayback playback) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) => _MediaInfoSheet(playback: playback),
    );
  }

  static String _metaLine(ServerItem item, AppLocalizations l10n) {
    final season = item.seasonNumber;
    final episode = item.episodeNumber;
    final runtime = item.runtime;

    return <String>[
      if (season != null && episode != null) l10n.episodeOf(episode, season),
      if (runtime != null) durationLabel(runtime),
      if (item.played) l10n.watched,
    ].where((s) => s.isNotEmpty).join(' · ');
  }
}

/// The audio and subtitle choice, made before anything plays.
class _TrackPickers extends StatelessWidget {
  const _TrackPickers({
    required this.playback,
    required this.audioIndex,
    required this.subtitleIndex,
    required this.onAudio,
    required this.onSubtitle,
  });

  final ServerPlayback? playback;
  final int? audioIndex;
  final int? subtitleIndex;
  final ValueChanged<int?> onAudio;
  final ValueChanged<int?> onSubtitle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final info = playback;

    if (info == null) {
      // The track list is a second request, and it is slower than the item.
      // A row of empty pickers would suggest the file has no tracks.
      return const SizedBox(
        height: 48,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final audio = info.streamsOfType(ServerStreamType.audio);
    final subtitles = info.streamsOfType(ServerStreamType.subtitle);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (audio.isNotEmpty)
          _PickerRow(
            icon: Icons.multitrack_audio_rounded,
            label: l10n.audioTrack,
            value: _labelFor(audio, audioIndex) ?? l10n.serverDefault,
            onTap: () => _pick(
              context,
              title: l10n.audioTrack,
              streams: audio,
              selected: audioIndex,
              // Audio is never "off" — a file with no audio simply has no
              // tracks to list, and this picker is not drawn at all.
              offLabel: null,
              onPicked: onAudio,
            ),
          ),
        if (subtitles.isNotEmpty)
          _PickerRow(
            icon: Icons.closed_caption_outlined,
            label: l10n.subtitleTrack,
            value: _labelFor(subtitles, subtitleIndex) ?? l10n.subtitlesOff,
            onTap: () => _pick(
              context,
              title: l10n.subtitleTrack,
              streams: subtitles,
              selected: subtitleIndex,
              offLabel: l10n.subtitlesOff,
              onPicked: onSubtitle,
            ),
          ),
      ],
    );
  }

  static String? _labelFor(List<ServerStream> streams, int? index) {
    if (index == null) return null;
    for (final ServerStream s in streams) {
      if (s.index == index) return s.label;
    }
    return null;
  }

  Future<void> _pick(
    BuildContext context, {
    required String title,
    required List<ServerStream> streams,
    required int? selected,
    required String? offLabel,
    required ValueChanged<int?> onPicked,
  }) async {
    final chosen = await showModalBottomSheet<_Choice>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.all(context.spacing.lg),
              child: Text(title, style: context.texts.titleMedium),
            ),
            if (offLabel != null)
              ListTile(
                title: Text(offLabel),
                trailing:
                    selected == null ? const Icon(Icons.check_rounded) : null,
                onTap: () =>
                    Navigator.of(sheetContext).pop(const _Choice(null)),
              ),
            for (final ServerStream stream in streams)
              ListTile(
                title: Text(stream.label),
                subtitle: stream.isForced
                    ? Text(AppLocalizations.of(context).subtitleTrack)
                    : null,
                trailing: stream.index == selected
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () =>
                    Navigator.of(sheetContext).pop(_Choice(stream.index)),
              ),
          ],
        ),
      ),
    );

    if (chosen == null) return;
    onPicked(chosen.index);
  }
}

/// Distinguishes "the user picked Off" from "the sheet was dismissed", which
/// a bare nullable int cannot.
class _Choice {
  const _Choice(this.index);
  final int? index;
}

class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.expand_more_rounded),
      onTap: onTap,
    );
  }
}

/// Every stream in the file, as the server describes it.
class _MediaInfoSheet extends StatelessWidget {
  const _MediaInfoSheet({required this.playback});

  final ServerPlayback playback;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final scheme = context.colors;
    final l10n = AppLocalizations.of(context);

    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: EdgeInsets.only(bottom: spacing.xl),
        children: <Widget>[
          Padding(
            padding: EdgeInsets.all(spacing.lg),
            child: Text(l10n.mediaInfo, style: context.texts.titleMedium),
          ),
          _Fact(
            label: 'Container',
            value: playback.container?.toUpperCase() ?? '—',
          ),
          _Fact(label: 'Bitrate', value: _mbps(playback.bitrate)),
          _Fact(
            label: 'Delivery',
            value: playback.isDirectPlay ? 'Direct play' : 'Transcoding',
          ),
          const Divider(),
          for (final ServerStream stream in playback.streams)
            ListTile(
              dense: true,
              leading: Icon(
                switch (stream.type) {
                  ServerStreamType.video => Icons.movie_outlined,
                  ServerStreamType.audio => Icons.multitrack_audio_rounded,
                  ServerStreamType.subtitle => Icons.closed_caption_outlined,
                  ServerStreamType.unknown => Icons.help_outline_rounded,
                },
                color: scheme.onSurfaceVariant,
              ),
              title: Text(stream.label),
              subtitle: Text(
                <String>[
                  if (stream.width != null && stream.height != null)
                    '${stream.width}×${stream.height}',
                  if (stream.bitrate != null) _mbps(stream.bitrate),
                ].join(' · '),
              ),
            ),
        ],
      ),
    );
  }

  static String _mbps(int? bits) =>
      bits == null ? '—' : '${(bits / 1000000).toStringAsFixed(1)} Mbps';
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.spacing.lg,
        vertical: context.spacing.xs,
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: context.texts.bodySmall
                  ?.copyWith(color: context.colors.onSurfaceVariant),
            ),
          ),
          Expanded(child: Text(value, style: context.texts.bodySmall)),
        ],
      ),
    );
  }
}

/// The episode summary, three lines until it is tapped.
class _Overview extends StatelessWidget {
  const _Overview({
    required this.text,
    required this.expanded,
    required this.onToggle,
  });

  final String text;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return GestureDetector(
      onTap: onToggle,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            text,
            maxLines: expanded ? null : 3,
            overflow: expanded ? null : TextOverflow.ellipsis,
            style: context.texts.bodyMedium
                ?.copyWith(color: context.colors.onSurfaceVariant),
          ),
          Text(
            expanded ? l10n.less : l10n.more,
            style: context.texts.bodyMedium?.copyWith(
              color: context.colors.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
