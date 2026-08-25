// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../servers/media_library_source.dart';
import 'server_library.dart';

/// Opens the stream list for [itemId], fetching it if it is not already here.
///
/// The track list arrives with the server's playback decision rather than
/// with the item, so this is a second request — which is why the sheet opens
/// on a spinner rather than the caller waiting with nothing on screen.
Future<void> showMediaInfo(BuildContext context, String itemId) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (_) => _MediaInfoSheet(itemId: itemId),
  );
}

class _MediaInfoSheet extends ConsumerWidget {
  const _MediaInfoSheet({required this.itemId});

  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = context.spacing;
    final scheme = context.colors;
    final l10n = AppLocalizations.of(context);

    final request = ref.watch(playbackInfoProvider(itemId));
    final playback = request.value;

    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: EdgeInsets.only(bottom: spacing.xl),
        children: <Widget>[
          Padding(
            padding: EdgeInsets.all(spacing.lg),
            child: Text(l10n.mediaInfo, style: context.texts.titleMedium),
          ),
          if (playback == null)
            Padding(
              padding: EdgeInsets.all(spacing.xl),
              child: Center(
                child: request.isLoading
                    ? const CircularProgressIndicator()
                    : Text(l10n.actionFailed),
              ),
            )
          else ...<Widget>[
            _Fact(
              label: 'Container',
              value: playback.container?.toUpperCase() ?? '—',
            ),
            _Fact(label: 'Bitrate', value: mbps(playback.bitrate)),
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
                    if (stream.bitrate != null) mbps(stream.bitrate),
                  ].join(' · '),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// A bit rate as the player's own source line words it.
String mbps(int? bits) =>
    bits == null ? '—' : '${(bits / 1000000).toStringAsFixed(1)} Mbps';

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
