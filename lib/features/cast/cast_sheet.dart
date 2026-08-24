// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../cast/cast_device.dart';
import 'cast_controller.dart';

/// The device picker, opened from the player's cast button.
///
/// Searching starts as the sheet opens and can be run again from the header:
/// a television that was asleep a moment ago is the normal reason for an
/// empty list, and the fix is to look again.
class CastSheet extends ConsumerStatefulWidget {
  const CastSheet({super.key, required this.onSelected});

  final ValueChanged<CastDevice> onSelected;

  static Future<void> show(
    BuildContext context, {
    required ValueChanged<CastDevice> onSelected,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      // The player is a dark surface and the sheet opens over it.
      backgroundColor: const Color(0xFF1A2125),
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) => CastSheet(onSelected: onSelected),
    );
  }

  @override
  ConsumerState<CastSheet> createState() => _CastSheetState();
}

class _CastSheetState extends ConsumerState<CastSheet> {
  @override
  void initState() {
    super.initState();
    // After the frame: this mutates a provider, which a build must not do.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(castControllerProvider.notifier).search();
    });
  }

  @override
  void dispose() {
    // An active Cast scan keeps the radio busy; nothing is watching the list
    // once the sheet is gone.
    ref.read(castControllerProvider.notifier).stopSearching();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final state = ref.watch(castControllerProvider);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.fromLTRB(
              spacing.xl,
              spacing.sm,
              spacing.sm,
              spacing.sm,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    l10n.playOn,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                if (state.searching)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white70,
                      ),
                    ),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded),
                    color: Colors.white70,
                    tooltip: l10n.searchAgain,
                    onPressed: ref.read(castControllerProvider.notifier).search,
                  ),
              ],
            ),
          ),

          if (state.error != null)
            Padding(
              padding: EdgeInsets.fromLTRB(spacing.xl, 0, spacing.xl, spacing.md),
              child: Text(
                state.error!,
                style: const TextStyle(color: Color(0xFFFFB4AB)),
              ),
            ),

          if (state.devices.isEmpty && !state.searching)
            Padding(
              padding: EdgeInsets.fromLTRB(
                spacing.xl,
                spacing.md,
                spacing.xl,
                spacing.xl,
              ),
              child: Text(
                l10n.noDevicesFound,
                style: const TextStyle(color: Colors.white70),
              ),
            ),

          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: <Widget>[
                for (final CastDevice device in state.devices)
                  ListTile(
                    leading: Icon(
                      device.kind == CastKind.chromecast
                          ? Icons.cast_rounded
                          : Icons.tv_rounded,
                      color: device == state.device
                          ? context.colors.primary
                          : Colors.white70,
                    ),
                    title: Text(
                      device.name,
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      <String>[
                        device.kind.label,
                        if (device.model != null) device.model!,
                        if (device.address != null) device.address!,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white54),
                    ),
                    trailing: device == state.device
                        ? Icon(Icons.check_rounded, color: context.colors.primary)
                        : null,
                    onTap: () {
                      Navigator.of(context).pop();
                      widget.onSelected(device);
                    },
                  ),
              ],
            ),
          ),

          if (state.isCasting)
            ListTile(
              leading: const Icon(Icons.stop_circle_outlined, color: Colors.white70),
              title: Text(
                l10n.stopCasting,
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.of(context).pop();
                ref.read(castControllerProvider.notifier).disconnect();
              },
            ),

          SizedBox(height: spacing.sm),
        ],
      ),
    );
  }
}
