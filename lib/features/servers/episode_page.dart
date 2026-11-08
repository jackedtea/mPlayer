// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../servers/media_library_source.dart';
import '../../servers/stream_preferences.dart';
import '../../widgets/backdrop_header.dart';
import '../../widgets/detail_header.dart';
import 'detail_sections.dart';
import 'item_action_row.dart';
import 'media_info_sheet.dart';
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

    final compact = context.windowSize == WindowSize.compact;

    return Scaffold(
      // The primary action lives at the foot of the screen on a phone, where
      // a thumb reaches without shifting grip, and inline above the overview
      // on anything wider — a tablet or a desktop window is not held in one
      // hand, and the design puts the row under the backdrop there.
      bottomNavigationBar: compact
          ? ItemPrimaryActionBar(
              item: item,
              onPlay: () => _play(item, playback),
              onStartOver: () => _play(item, playback, fromStart: true),
            )
          : null,
      body: ListView(
        padding: EdgeInsets.only(
          bottom: spacing.xl * 2 + context.systemBottomInset,
        ),
        children: <Widget>[
          BackdropHeader(
            seed: item.title,
            artUrl: artUrlFor(ref, item, maxWidth: 900),
            height: 220,
            child: _EpisodeTitles(item: item),
          ),
          Padding(
            padding: padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Glyphs with the rest behind ⋮, as on the series and movie
                // screens. The labelled chips ran off the side of a phone and
                // had to be scrolled to find the fourth.
                if (compact)
                  ItemActionIcons(
                    item: item,
                    // Play is in the bar at the foot of the screen.
                    primary: false,
                    alignment: WrapAlignment.start,
                    seriesId: item.seriesId,
                    shuffleFrom: siblings,
                    playlistIds: <String>[item.id],
                    onPlay: () => _play(item, playback),
                    // Always offered: the sheet fetches the track list itself
                    // and says so while it does.
                    onMediaInfo: () => showMediaInfo(context, item.id),
                  )
                else
                  _WideActions(
                    item: item,
                    siblings: siblings,
                    onPlay: () => _play(item, playback),
                    onStartOver: () => _play(item, playback, fromStart: true),
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
          ExternalLinks(
            links: item.links,
            padding: padding.copyWith(top: spacing.xl, bottom: 0),
          ),
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
    ref
        .read(trackChoiceProvider.notifier)
        .set(
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
}

/// Past compact: a labelled Play — "Continue watching" once started — and
/// Start over ahead of the glyphs, as the movie screen has.
class _WideActions extends StatelessWidget {
  const _WideActions({
    required this.item,
    required this.siblings,
    required this.onPlay,
    required this.onStartOver,
  });

  final ServerItem item;
  final List<ServerItem> siblings;
  final VoidCallback onPlay;
  final VoidCallback onStartOver;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final l10n = AppLocalizations.of(context);
    final started = (item.position ?? Duration.zero) > Duration.zero;

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: spacing.sm,
      runSpacing: spacing.sm,
      children: <Widget>[
        FilledButton.icon(
          onPressed: onPlay,
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text(started ? l10n.continueWatching : l10n.play),
        ),
        if (started)
          IconButton(
            tooltip: l10n.startOver,
            icon: const Icon(Icons.replay_rounded),
            onPressed: onStartOver,
          ),
        ItemActionIcons(
          item: item,
          primary: false,
          alignment: WrapAlignment.start,
          seriesId: item.seriesId,
          shuffleFrom: siblings,
          playlistIds: <String>[item.id],
          onPlay: onPlay,
          onMediaInfo: () => showMediaInfo(context, item.id),
        ),
      ],
    );
  }
}

/// The block under the still: the series, the episode's own title, the title
/// it was made under, then one line of facts — "S2E1 · 7/6/2013 · 27m ·
/// ★ 7.7 · Ends at 9:17 PM" — showing only what the server filled in.
class _EpisodeTitles extends StatelessWidget {
  const _EpisodeTitles({required this.item});

  final ServerItem item;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final scheme = context.colors;
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final muted = context.texts.bodyMedium?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    final season = item.seasonNumber;
    final episode = item.episodeNumber;
    final original = item.originalTitle?.trim() ?? '';
    final premiere = item.premiereDate;
    final runtime = item.runtime;
    final position = item.position ?? Duration.zero;
    final left = runtime == null || item.played ? null : runtime - position;

    final facts = <Widget>[
      if (season != null && episode != null)
        Text(l10n.episodeOf(season, episode), style: muted),
      if (premiere != null)
        Text(DateFormat.yMd(locale).format(premiere.toLocal()), style: muted),
      if (runtime != null) Text(durationLabel(runtime), style: muted),
      if (item.rating != null) RatingLabel(rating: item.rating!),
      if ((item.certificate ?? '').isNotEmpty)
        CertificateBox(certificate: item.certificate!),
      // When it would end if started now: the question someone deciding
      // whether there is time for one more is actually asking.
      if (left != null && left > Duration.zero)
        Text(
          l10n.endsAt(DateFormat.jm(locale).format(DateTime.now().add(left))),
          style: muted,
        ),
      if (item.played) Text(l10n.watched, style: muted),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (item.seriesTitle != null)
          Text(
            item.seriesTitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.texts.titleMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        Text(
          item.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: context.texts.headlineSmall,
        ),
        if (original.isNotEmpty && original != item.title)
          Padding(
            padding: EdgeInsets.only(top: spacing.xs / 2),
            child: Text(
              original,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: muted,
            ),
          ),
        if (facts.isNotEmpty) ...<Widget>[
          SizedBox(height: spacing.sm),
          Wrap(
            spacing: spacing.md,
            runSpacing: spacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: facts,
          ),
        ],
      ],
    );
  }
}

/// "1080p HEVC SDR": the resolution class, the codec and the dynamic range.
///
/// The class comes from the width as well as the height, so a 1920×800 scope
/// film reads as the 1080p it is rather than as "800p".
String videoSummary(ServerStream video) {
  final w = video.width ?? 0;
  final h = video.height ?? 0;
  final resolution = w >= 3800 || h >= 2100
      ? '4K'
      : w >= 2500 || h >= 1400
      ? '1440p'
      : w >= 1900 || h >= 1000
      ? '1080p'
      : w >= 1260 || h >= 700
      ? '720p'
      : h > 0
      ? '${h}p'
      : '';
  final codec = switch (video.codec?.toLowerCase()) {
    null || '' => '',
    'h264' || 'avc' => 'H.264',
    'hevc' || 'h265' => 'HEVC',
    final String other => other.toUpperCase(),
  };
  return <String>[
    resolution,
    codec,
    video.videoRange ?? '',
  ].where((p) => p.isNotEmpty).join(' ');
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

    final video = info.streamsOfType(ServerStreamType.video).firstOrNull;
    final videoLine = video == null ? '' : videoSummary(video);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Read-only: there is one video track to speak of, and what it is —
        // "1080p HEVC SDR" — is what decides whether this device will play
        // it directly.
        if (videoLine.isNotEmpty)
          _PickerRow(
            icon: Icons.videocam_outlined,
            label: l10n.videoTrack,
            value: videoLine,
          ),
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
                trailing: selected == null
                    ? const Icon(Icons.check_rounded)
                    : null,
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
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;

  /// Null draws a row that only informs, with no chevron.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: onTap == null ? null : const Icon(Icons.expand_more_rounded),
      onTap: onTap,
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
            style: context.texts.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
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
