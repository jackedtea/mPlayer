// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

/// What one session is doing to the server: how its stream is delivered,
/// and — when it is being re-encoded — what into and why.
///
/// "Why is this transcoding?" is the question an administrator opens a
/// session to answer, so the reasons come first and in words.
library;

import 'package:flutter/material.dart';

import '../../app/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../servers/server_admin.dart';

/// The play method as a short label, coloured by how much work it costs.
class PlayMethodChip extends StatelessWidget {
  const PlayMethodChip({super.key, required this.method});

  final PlayMethod method;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = context.colors;
    final (String label, Color colour) = switch (method) {
      PlayMethod.directPlay => (l10n.adminDirectPlay, context.semantic.success),
      PlayMethod.directStream => (l10n.adminDirectStream, scheme.primary),
      PlayMethod.transcode => (l10n.adminTranscoding, context.semantic.warning),
    };
    return Text(
      label,
      style: context.texts.labelMedium?.copyWith(
        color: colour,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

/// Opens the session's details as a bottom sheet.
Future<void> showSessionDetails(BuildContext context, AdminSession session) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _SessionDetails(session: session),
  );
}

class _SessionDetails extends StatelessWidget {
  const _SessionDetails({required this.session});

  final AdminSession session;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final t = session.transcoding;
    final method = session.playMethod;

    Widget row(String label, String value) {
      if (value.isEmpty) return const SizedBox.shrink();
      return ListTile(
        dense: true,
        title: Text(label),
        trailing: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.55,
          ),
          child: Text(value, textAlign: TextAlign.end),
        ),
      );
    }

    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.95,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: EdgeInsets.only(bottom: spacing.lg),
          children: <Widget>[
            ListTile(
              title: Text(
                session.username.isEmpty
                    ? session.deviceName
                    : session.username,
                style: context.texts.titleMedium,
              ),
              subtitle: Text(session.nowPlaying ?? l10n.adminIdleSession),
              trailing: method == null ? null : PlayMethodChip(method: method),
            ),
            const Divider(),
            row(l10n.adminSessionDevice, session.deviceName),
            row(
              l10n.adminSessionClient,
              <String>[
                session.client,
                session.clientVersion,
              ].where((s) => s.isNotEmpty).join(' '),
            ),
            row(l10n.adminSessionAddress, session.remoteAddress),
            if (t != null) ...<Widget>[
              const Divider(),
              if (t.reasons.isNotEmpty) ...<Widget>[
                ListTile(dense: true, title: Text(l10n.adminTranscodeReasons)),
                for (final String reason in t.reasons)
                  ListTile(
                    dense: true,
                    leading: Icon(
                      Icons.info_outline_rounded,
                      color: context.semantic.warning,
                    ),
                    title: Text(transcodeReasonLabel(reason, l10n)),
                  ),
              ],
              row(
                l10n.adminTranscodeVideo,
                t.isVideoDirect
                    ? l10n.adminTranscodeCopied
                    : <String>[
                        t.videoCodec.toUpperCase(),
                        if (t.width != null && t.height != null)
                          '${t.width}×${t.height}',
                        if (t.framerate != null)
                          '${t.framerate!.toStringAsFixed(t.framerate! % 1 == 0 ? 0 : 2)} fps',
                      ].where((s) => s.isNotEmpty).join(' · '),
              ),
              row(
                l10n.adminTranscodeAudio,
                t.isAudioDirect
                    ? l10n.adminTranscodeCopied
                    : <String>[
                        t.audioCodec.toUpperCase(),
                        if (t.audioChannels != null) '${t.audioChannels} ch',
                      ].where((s) => s.isNotEmpty).join(' · '),
              ),
              row(l10n.adminTranscodeContainer, t.container.toUpperCase()),
              row(
                l10n.adminTranscodeBitrate,
                t.bitrate == null ? '' : formatBitrate(t.bitrate!),
              ),
              row(
                l10n.adminTranscodeHardware,
                t.isVideoDirect
                    ? ''
                    : t.hardwareAcceleration.isEmpty
                    ? l10n.adminTranscodeSoftware
                    : t.hardwareAcceleration.toUpperCase(),
              ),
              if (t.completion case final double done when done > 0)
                row(l10n.adminTranscodeAhead, '${done.round()}%'),
            ],
          ],
        ),
      ),
    );
  }
}

/// "8.4 Mbps", "640 kbps".
String formatBitrate(int bitsPerSecond) {
  if (bitsPerSecond >= 1000000) {
    final mbps = bitsPerSecond / 1000000;
    return '${mbps.toStringAsFixed(mbps >= 100 ? 0 : 1)} Mbps';
  }
  return '${(bitsPerSecond / 1000).round()} kbps';
}

/// A transcode reason in words, for the ones worth wording; the rest are
/// split out of their CamelCase so they still read as something.
String transcodeReasonLabel(String reason, AppLocalizations l10n) {
  return switch (reason) {
    'ContainerNotSupported' => l10n.adminReasonContainer,
    'VideoCodecNotSupported' => l10n.adminReasonVideoCodec,
    'AudioCodecNotSupported' => l10n.adminReasonAudioCodec,
    'SubtitleCodecNotSupported' => l10n.adminReasonSubtitle,
    'VideoResolutionNotSupported' => l10n.adminReasonResolution,
    'VideoBitrateNotSupported' ||
    'AudioBitrateNotSupported' ||
    'ContainerBitrateExceedsLimit' => l10n.adminReasonBitrate,
    'AudioChannelsNotSupported' => l10n.adminReasonChannels,
    'VideoRangeTypeNotSupported' => l10n.adminReasonRange,
    'VideoProfileNotSupported' ||
    'VideoLevelNotSupported' ||
    'VideoBitDepthNotSupported' => l10n.adminReasonProfile,
    _ => reason.replaceAllMapped(RegExp(r'(?<=[a-z])(?=[A-Z])'), (_) => ' '),
  };
}
