// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../player/playback_controller.dart';
import 'player_settings.dart';
import 'settings_widgets.dart';

/// Screen 1l, Player section.
///
/// Every control here writes through to [playerSettingsProvider], which is
/// persisted and applied to libmpv immediately — a switch that only moved a
/// local bool would be worse than no switch at all.
class PlayerSettingsPage extends ConsumerWidget {
  const PlayerSettingsPage({super.key});

  /// The amounts the transport buttons and double-tap gestures offer.
  static const _skipChoices = <int>[5, 10, 15, 30, 60];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(playerSettingsProvider);

    Future<void> save(PlayerSettings next) async {
      await ref.read(playerSettingsProvider.notifier).update(next);
      // Takes effect mid-playback rather than on the next file.
      await ref.read(playbackControllerProvider.notifier).applySettings(next);
    }

    return SettingsScaffold(
      title: 'Player',
      children: <Widget>[
        const SettingsSection(title: 'Playback'),
        SettingsValueRow(
          title: 'Hardware decoding',
          value: settings.hardwareDecoding.label,
          subtitle: 'Falls back to software when a codec is unsupported',
          onTap: () => _pickHardwareDecoding(context, settings, save),
        ),
        SettingsValueRow(
          title: 'Skip back',
          value: '${settings.skipBack.inSeconds}s',
          onTap: () => _pickSkip(
            context,
            settings.skipBack,
            (d) => save(settings.copyWith(skipBack: d)),
          ),
        ),
        SettingsValueRow(
          title: 'Skip forward',
          value: '${settings.skipForward.inSeconds}s',
          onTap: () => _pickSkip(
            context,
            settings.skipForward,
            (d) => save(settings.copyWith(skipForward: d)),
          ),
        ),
        SettingsSwitchRow(
          title: 'Auto-play next episode',
          subtitle: 'Continues with the next video in the folder',
          value: settings.autoPlayNext,
          onChanged: (v) => save(settings.copyWith(autoPlayNext: v)),
        ),
        SettingsSwitchRow(
          title: 'Auto skip intro',
          subtitle: 'Only where the source marks an intro chapter',
          value: settings.autoSkipIntro,
          onChanged: (v) => save(settings.copyWith(autoSkipIntro: v)),
        ),
        const SettingsSection(title: 'Screen & gestures'),
        // Both are Android behaviours with no desktop equivalent, so the rows
        // are absent rather than present and inert.
        if (Platform.isAndroid) ...<Widget>[
          SettingsSwitchRow(
            title: 'Picture in picture',
            subtitle: 'Shrink into a floating window when you leave the app',
            value: settings.pipOnLeave,
            onChanged: (v) => save(settings.copyWith(pipOnLeave: v)),
          ),
          SettingsSwitchRow(
            title: 'Play audio in background',
            subtitle: 'Keeps playing with the screen off, with a notification',
            value: settings.backgroundAudio,
            onChanged: (v) => save(settings.copyWith(backgroundAudio: v)),
          ),
        ],
        SettingsSwitchRow(
          title: 'Swipe gestures',
          subtitle: 'Brightness on the left, volume on the right',
          value: settings.swipeGestures,
          onChanged: (v) => save(settings.copyWith(swipeGestures: v)),
        ),
        const SettingsValueRow(title: 'Rotation', value: 'Follow video'),
        const SettingsSection(title: 'Streaming quality'),
        const SettingsValueRow(title: 'On Wi-Fi', value: 'Original'),
        const SettingsValueRow(
          title: 'On cellular',
          value: 'Original',
          subtitle: 'Needs a server that can transcode',
        ),
      ],
    );
  }

  Future<void> _pickHardwareDecoding(
    BuildContext context,
    PlayerSettings settings,
    Future<void> Function(PlayerSettings) save,
  ) async {
    final chosen = await showModalBottomSheet<HardwareDecoding>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final HardwareDecoding mode in HardwareDecoding.values)
              ListTile(
                title: Text(mode.label),
                trailing: mode == settings.hardwareDecoding
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(mode),
              ),
          ],
        ),
      ),
    );

    if (chosen == null) return;
    await save(settings.copyWith(hardwareDecoding: chosen));
  }

  Future<void> _pickSkip(
    BuildContext context,
    Duration current,
    Future<void> Function(Duration) save,
  ) async {
    final chosen = await showModalBottomSheet<int>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final int seconds in _skipChoices)
              ListTile(
                title: Text('$seconds seconds'),
                trailing: seconds == current.inSeconds
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(seconds),
              ),
          ],
        ),
      ),
    );

    if (chosen == null) return;
    await save(Duration(seconds: chosen));
  }
}
