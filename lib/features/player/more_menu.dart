// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../settings/player_settings.dart';
import '../settings/player_settings_page.dart';
import 'controls_overlay.dart' show loopLabel;
import 'playback_controller.dart';
import 'playback_state.dart';
import 'player_ui_state.dart';
import 'stable_insets.dart';

/// The player's overflow sheet: a row of quick actions — background play,
/// speed, loop, screenshot — then sleep timer, audio delay and the decoder,
/// then stats and the settings page below a divider.
///
/// The quick actions were buttons on the bar. They are set once a film rather
/// than reached for during one, and as one row of tiles they cost the sheet
/// a single row's height rather than four. Rotation and aspect left to make
/// room: both are buttons on the bar, and a row repeating a button is a row
/// the sheet cannot afford.
///
/// Seven rows is the ceiling, not a coincidence. The shortest screen the
/// player is held on is a phone on its side — 393 points — and the theme's
/// drag handle takes 48 of them, so an eighth row is one nothing can be
/// scrolled to without the sheet having cost a swipe first. A row added here
/// has to earn its place against the ones already in it.
class MoreMenu extends ConsumerWidget {
  const MoreMenu({
    super.key,
    this.onSpeed,
    this.onScreenshot,
    this.onBackgroundPlay,
  });

  /// Opens the speed picker. The sheet closes first: the picker is a sheet of
  /// its own, and two stacked over a film is one too many.
  final VoidCallback? onSpeed;

  /// Grabs the frame. The sheet closes first, so the confirmation that
  /// follows is not hidden under it.
  final VoidCallback? onScreenshot;

  /// Flips the background-audio preference; the tile follows the setting.
  final VoidCallback? onBackgroundPlay;

  static Future<void> show(
    BuildContext context, {
    VoidCallback? onSpeed,
    VoidCallback? onScreenshot,
    VoidCallback? onBackgroundPlay,
  }) {
    return showPlayerSheet<void>(
      context: context,
      builder: (_) => MoreMenu(
        onSpeed: onSpeed,
        onScreenshot: onScreenshot,
        onBackgroundPlay: onBackgroundPlay,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final ui = ref.watch(playerUiProvider);
    final controller = ref.read(playerUiProvider.notifier);
    final playback = ref.watch(playbackControllerProvider);
    final background = ref.watch(playerSettingsProvider).backgroundAudio;
    final speedChanged = (playback.speed - 1.0).abs() > 0.01;

    // SafeArea for the navigation bar, which `useSafeArea` deliberately
    // leaves to the sheet itself; the list scrolls rather than clips on a
    // screen too short to hold every row at once.
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        // The track sheets' top and bottom spacing.
        padding: EdgeInsets.only(
          top: context.spacing.sm,
          bottom: context.spacing.sm,
        ),
        children: <Widget>[
          Padding(
            // Tiles are as wide as a quarter of the row, so their icons sit
            // under the rows' text rather than their leading icon; the outer
            // margin is the rows' own.
            padding: EdgeInsets.fromLTRB(
              context.spacing.xl - context.spacing.sm,
              0,
              context.spacing.xl - context.spacing.sm,
              context.spacing.xs,
            ),
            child: Row(
              children: <Widget>[
                if (onBackgroundPlay != null)
                  _QuickAction(
                    icon: background
                        ? Icons.headphones_rounded
                        : Icons.headphones_battery_rounded,
                    label: l10n.quickBackground,
                    value: background ? l10n.on : l10n.off,
                    active: background,
                    onTap: onBackgroundPlay!,
                  ),
                if (onSpeed != null)
                  _QuickAction(
                    icon: Icons.speed_rounded,
                    label: l10n.quickSpeed,
                    // Anything but normal is easy to forget and hard to
                    // notice; the tint is the reminder.
                    value: '${playback.speed.toStringAsFixed(2)}×',
                    active: speedChanged,
                    onTap: () {
                      Navigator.of(context).pop();
                      onSpeed!();
                    },
                  ),
                _QuickAction(
                  icon: _loopIcon(playback.loop),
                  label: l10n.loop,
                  value: loopLabel(l10n, playback.loop),
                  active: playback.loop != LoopMode.off,
                  onTap: () => ref
                      .read(playbackControllerProvider.notifier)
                      .cycleLoop(),
                ),
                if (onScreenshot != null)
                  _QuickAction(
                    icon: Icons.photo_camera_rounded,
                    label: l10n.quickScreenshot,
                    onTap: () {
                      Navigator.of(context).pop();
                      onScreenshot!();
                    },
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white24),
          _Row(
            icon: Icons.bedtime_rounded,
            label: l10n.sleepTimer,
            value: ui.sleepLabel,
            onTap: () => _pickSleepTimer(context, ref),
          ),
          // Here as well as in settings: lips out of step with the dialogue
          // is noticed mid-film, and leaving the player to fix it loses the
          // moment you were judging it by.
          _Row(
            icon: Icons.av_timer_rounded,
            label: l10n.audioDelay,
            value: formatDelay(ref.watch(playerSettingsProvider).audioDelay),
            onTap: () => _pickAudioDelay(context, ref),
          ),
          // Here as well as in settings, and for the same reason the audio
          // delay is: a driver that mishandles a codec shows a green or
          // juddering picture, and the file it happens on is the one already
          // on screen. Sending the viewer to Settings to fix it means losing
          // the film they were watching.
          _Row(
            icon: Icons.memory_rounded,
            label: l10n.decoder,
            value: ref
                .watch(playerSettingsProvider)
                .hardwareDecoding
                .label(l10n),
            onTap: () => _pickDecoder(context, ref),
          ),
          const Divider(height: 1, color: Colors.white24),
          _Row(
            icon: Icons.analytics_rounded,
            label: l10n.statsForNerds,
            value: ui.statsVisible ? l10n.on : l10n.off,
            onTap: () {
              controller.toggleStats();
              Navigator.of(context).pop();
            },
          ),
          _Row(
            icon: Icons.settings_rounded,
            label: l10n.playerSettings,
            onTap: () {
              Navigator.of(context).pop();
              context.push('/settings/player');
            },
          ),
        ],
      ),
    );
  }

  Future<void> _pickAudioDelay(BuildContext context, WidgetRef ref) async {
    final settings = ref.read(playerSettingsProvider);

    await pickAudioDelay(context, settings.audioDelay, (delay) async {
      final next = settings.copyWith(audioDelay: delay);
      await ref.read(playerSettingsProvider.notifier).update(next);
      // Straight into libmpv: the point of adjusting this here is hearing the
      // difference on the frame you are looking at.
      await ref.read(playbackControllerProvider.notifier).applySettings(next);
    });
  }

  /// Hardware or software, with what mpv actually settled on at the top.
  ///
  /// The reading matters as much as the choice: asking for hardware is not
  /// the same as getting it, since mpv drops to software on its own whenever
  /// the GPU cannot take a codec. Without it the sheet would report the
  /// user's request back to them as though it were the outcome.
  Future<void> _pickDecoder(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final current = ref.read(playerSettingsProvider).hardwareDecoding;
    final stats = ref.read(playbackControllerProvider).stats;

    final chosen = await showPlayerSheet<HardwareDecoding>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          children: <Widget>[
            if (stats.hwdec != null || stats.videoDecoder != null)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  context.spacing.xl,
                  context.spacing.md,
                  context.spacing.xl,
                  context.spacing.xs,
                ),
                child: Text(
                  l10n.decodingNow(_decodingNow(l10n, stats)),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                ),
              ),
            for (final HardwareDecoding mode in HardwareDecoding.values)
              ListTile(
                title: Text(
                  mode.label(l10n),
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  mode.description(l10n),
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                ),
                trailing: mode == current
                    ? const Icon(Icons.check_rounded, color: Colors.white)
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(mode),
              ),
          ],
        ),
      ),
    );

    if (chosen == null) return;
    // Straight into libmpv, which reinitialises the video chain: the point of
    // changing this here is seeing the frame in front of you decode again.
    await ref
        .read(playbackControllerProvider.notifier)
        .setHardwareDecoding(chosen);
  }

  Future<void> _pickSleepTimer(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final choices = <(String, Duration?)>[
      (l10n.off, null),
      (l10n.minutes(15), const Duration(minutes: 15)),
      (l10n.minutes(30), const Duration(minutes: 30)),
      (l10n.minutes(60), const Duration(minutes: 60)),
    ];

    final chosen = await showPlayerSheet<(String, Duration?)>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          children: <Widget>[
            for (final (String label, Duration? d) in choices)
              ListTile(
                title: Text(label, style: const TextStyle(color: Colors.white)),
                onTap: () => Navigator.of(sheetContext).pop((label, d)),
              ),
          ],
        ),
      ),
    );

    if (chosen == null) return;
    ref.read(playerUiProvider.notifier).setSleepTimer(chosen.$2);
  }
}

/// What is decoding, in as few words as it takes.
///
/// mpv names the API — `d3d11va-copy`, `mediacodec`, `videotoolbox` — which
/// is the useful answer and needs no translating. `no` is the one value that
/// is a word rather than a name, so it is the one that does.
String _decodingNow(AppLocalizations l10n, PlaybackStats stats) {
  final hwdec = stats.hwdec;
  final codec = stats.videoDecoder;

  final how = hwdec == null || hwdec == 'no' || hwdec.isEmpty
      ? l10n.decodingSoftware
      : hwdec;

  return codec == null ? how : '$codec · $how';
}

/// Repeat-one gets its own glyph; the folder loop and "off" share one and are
/// told apart by the tint, the way every other stateful control in the row is.
IconData _loopIcon(LoopMode mode) => switch (mode) {
      LoopMode.off => Icons.repeat_rounded,
      LoopMode.one => Icons.repeat_one_rounded,
      LoopMode.all => Icons.repeat_on_rounded,
    };


/// One tile in the quick-action row: an icon that lights up while its
/// setting is on, its name, and its value underneath.
class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.value,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final String? value;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = context.colors.primaryContainer;
    final muted = Colors.white.withValues(alpha: 0.6);

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(context.radii.card),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: active
                      ? accent.withValues(alpha: 0.22)
                      : Colors.white.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: active ? accent : Colors.white),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
              if (value != null)
                Text(
                  value!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: active ? accent : muted, fontSize: 12),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    required this.onTap,
    this.value,
  });

  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListTile(
        // Compact for height only — the sheet has to hold its rows on a
        // phone on its side — and not dense, which also shrank the text to
        // 13pt. The side margin is the track sheets', so the two read as one
        // family.
        visualDensity: VisualDensity.compact,
        onTap: onTap,
        contentPadding: EdgeInsets.symmetric(horizontal: context.spacing.xl),
        leading: Icon(icon, color: Colors.white, size: 22),
        title: Text(label, style: const TextStyle(color: Colors.white)),
        trailing: value == null
            ? null
            : Text(
                value!,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
              ),
      ),
    );
  }
}
