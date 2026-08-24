// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/languages.dart';
import '../player/playback_controller.dart';
import 'player_settings.dart';
import '../../l10n/app_localizations.dart';
import 'settings_widgets.dart';

/// Screen 1l, Audio.
///
/// The design lists this page without drawing it — passthrough, preferred
/// track language, volume boost, gapless — so it follows the same
/// section-and-tile pattern as the Player page. Every row is a libmpv
/// property, applied to the running file rather than at the next open.
class AudioSettingsPage extends ConsumerWidget {
  const AudioSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(playerSettingsProvider);

    Future<void> save(PlayerSettings next) async {
      await ref.read(playerSettingsProvider.notifier).update(next);
      await ref.read(playbackControllerProvider.notifier).applySettings(next);
    }

    return SettingsScaffold(
      title: l10n.settingsAudio,
      children: <Widget>[
        SettingsSection(title: l10n.audioOutput),
        SettingsSwitchRow(
          title: l10n.passthrough,
          subtitle: l10n.passthroughSub,
          value: settings.audioPassthrough,
          onChanged: (v) => save(settings.copyWith(audioPassthrough: v)),
        ),
        // Stated rather than left to be discovered: passthrough with nothing
        // to decode the stream at the far end is silence, and the cause is
        // not obvious from inside a film.
        SettingsNote(l10n.passthroughNote),
        SettingsSliderRow(
          title: l10n.volumeBoost,
          valueLabel: '${settings.volumeBoost}%',
          value: settings.volumeBoost.toDouble(),
          min: 100,
          max: 200,
          divisions: 10,
          onChanged: (v) => save(settings.copyWith(volumeBoost: v.round())),
        ),
        SettingsNote(l10n.volumeBoostNote),
        SettingsValueRow(
          title: l10n.gapless,
          value: _label(context, settings.gapless),
          subtitle: l10n.gaplessSub,
          onTap: () => _pickGapless(context, settings, save),
        ),
        SettingsSection(title: l10n.tracks),
        SettingsValueRow(
          title: l10n.preferredLanguage,
          value: languageLabel(settings.preferredLanguage),
          // One preference drives both: picking the audio the user
          // understands is the same question as deciding whether they need
          // subtitles for it.
          subtitle: l10n.sharedWithSubtitles,
          onTap: () => context.push('/settings/subtitle'),
        ),
      ],
    );
  }

  Future<void> _pickGapless(
    BuildContext context,
    PlayerSettings settings,
    Future<void> Function(PlayerSettings) save,
  ) async {
    final chosen = await showModalBottomSheet<GaplessAudio>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final GaplessAudio mode in GaplessAudio.values)
              ListTile(
                title: Text(_label(sheetContext, mode)),
                subtitle: Text(_describe(sheetContext, mode)),
                trailing: mode == settings.gapless
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(mode),
              ),
          ],
        ),
      ),
    );

    if (chosen == null) return;
    await save(settings.copyWith(gapless: chosen));
  }

  /// The mode's own name, and the sentence under it. Both live here
  /// rather than on the enum: an enum constant is built before there is
  /// a locale to build it in.
  static String _label(BuildContext context, GaplessAudio mode) {
    final l10n = AppLocalizations.of(context);
    return switch (mode) {
      GaplessAudio.off => l10n.gaplessOff,
      GaplessAudio.automatic => l10n.gaplessAutomatic,
      GaplessAudio.always => l10n.gaplessAlways,
    };
  }

  static String _describe(BuildContext context, GaplessAudio mode) {
    final l10n = AppLocalizations.of(context);
    return switch (mode) {
      GaplessAudio.off => l10n.gaplessOffSub,
      GaplessAudio.automatic => l10n.gaplessAutomaticSub,
      GaplessAudio.always => l10n.gaplessAlwaysSub,
    };
  }
}
