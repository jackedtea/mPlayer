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
import 'playback_controller.dart';
import 'playback_state.dart';
import 'player_ui_state.dart';

/// The player's overflow sheet: rotation, aspect, sleep timer, audio delay
/// and the decoder, then stats and the settings page below a divider.
///
/// Seven rows is the ceiling, not a coincidence. The shortest screen the
/// player is held on is a phone on its side — 393 points — and the theme's
/// drag handle takes 48 of them, so an eighth row is one nothing can be
/// scrolled to without the sheet having cost a swipe first. A row added here
/// has to earn its place against the ones already in it.
class MoreMenu extends ConsumerWidget {
  const MoreMenu({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A2125),
      // A sheet left to the default is capped at nine sixteenths of the
      // screen, which is less than seven rows and a drag handle come to on a
      // phone held sideways — and the player is *always* held sideways. The
      // rows past the cap were not scrolled to, they were cut off.
      isScrollControlled: true,
      // **Not** `useSafeArea`, which wraps the whole sheet in a `SafeArea`
      // and so gives up the status bar's strip of height at the far end of
      // the screen from where the sheet is drawn. On a phone on its side that
      // strip is the difference between seven rows and six: with the bars up
      // the last row fell off the bottom, and hiding them put it back. The
      // sheet takes the whole window and keeps clear of the navigation bar
      // through the `SafeArea` in its own build, which is the inset that
      // actually overlaps it.
      builder: (_) => const MoreMenu(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final ui = ref.watch(playerUiProvider);
    final controller = ref.read(playerUiProvider.notifier);

    // SafeArea for the navigation bar, which `useSafeArea` deliberately
    // leaves to the sheet itself; the list scrolls rather than clips on a
    // screen too short to hold every row at once.
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        children: <Widget>[
          _Row(
            icon: ui.rotation.icon,
            label: l10n.rotation,
            value: ui.rotation.label(l10n),
            onTap: controller.cycleRotation,
          ),
          _Row(
            icon: Icons.aspect_ratio_rounded,
            label: l10n.aspectRatio,
            value: ui.aspect.label(l10n),
            onTap: controller.cycleAspect,
          ),
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

    final chosen = await showModalBottomSheet<HardwareDecoding>(
      context: context,
      backgroundColor: const Color(0xFF1A2125),
      isScrollControlled: true,
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

    final chosen = await showModalBottomSheet<(String, Duration?)>(
      context: context,
      backgroundColor: const Color(0xFF1A2125),
      isScrollControlled: true,
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
        dense: true,
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
