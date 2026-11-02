// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../remote/remote_protocol.dart';
import '../../remote/remote_server.dart';
import 'remote_receiver.dart';
import 'remote_session.dart';

/// Where the remote meets the screen, both ends of it.
///
/// Wrapped once around the navigator in `app.dart`'s builder, for three
/// reasons that each need that spot:
///
/// - the receiver's PIN has to show **over whatever is up** — the player
///   included — without being a route that would push the film aside;
/// - the receiver needs the app's router to open and leave the player;
/// - a phone's refusals arrive whichever screen it is on, and are shown once
///   from here rather than by every screen that can send a command.
class RemoteHost extends ConsumerStatefulWidget {
  const RemoteHost({super.key, required this.router, required this.child});

  final GoRouter router;
  final Widget child;

  @override
  ConsumerState<RemoteHost> createState() => _RemoteHostState();
}

class _RemoteHostState extends ConsumerState<RemoteHost> {
  @override
  Widget build(BuildContext context) {
    ref.read(remoteReceiverProvider.notifier).router = widget.router;
    final pairing = ref.watch(remoteReceiverProvider.select((r) => r.pairing));

    ref.listen<List<String>>(
      remoteReceiverProvider.select((r) => r.controllers),
      (before, now) {
        final joined = now.where((n) => !(before ?? const <String>[]).contains(n));
        for (final String name in joined) {
          _say(AppLocalizations.of(context).remoteControlledBy(name));
        }
      },
    );
    ref.listen<int>(
      remoteSessionProvider.select((s) => s.failureCount),
      (_, _) => _showFailure(),
    );

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        widget.child,
        if (pairing != null) _PairingCard(pairing: pairing),
      ],
    );
  }

  void _say(String text) {
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(text)));
  }

  void _showFailure() {
    final state = ref.read(remoteSessionProvider);
    final failure = state.failure;
    if (failure == null) return;
    final l10n = AppLocalizations.of(context);
    final name = state.device?.name ?? '';
    _say(switch (failure.code) {
      RemoteErrorCode.wrongServer => l10n.remoteWrongServer(name),
      RemoteErrorCode.locked => l10n.remoteLocked(name),
      RemoteErrorCode.version => l10n.remoteVersion(name),
      RemoteErrorCode.playFailed =>
        failure.message ?? l10n.remotePlayFailed(name),
    });
  }
}

/// The PIN, large enough to read across a room.
class _PairingCard extends StatelessWidget {
  const _PairingCard({required this.pairing});

  final RemotePairing pairing;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final scheme = context.colors;
    final text = Theme.of(context).textTheme;

    return Positioned(
      top: context.systemTopInset + spacing.lg,
      left: spacing.lg,
      right: spacing.lg,
      child: Center(
        child: Card(
          color: scheme.primaryContainer,
          child: Padding(
            padding: EdgeInsets.all(spacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.settings_remote_rounded,
                  color: scheme.onPrimaryContainer,
                ),
                SizedBox(height: spacing.sm),
                Text(
                  l10n.remotePairingTitle(pairing.phoneName),
                  style: text.titleMedium
                      ?.copyWith(color: scheme.onPrimaryContainer),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: spacing.md),
                Text(
                  pairing.pin,
                  style: text.displayMedium?.copyWith(
                    color: scheme.onPrimaryContainer,
                    letterSpacing: spacing.sm,
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
                SizedBox(height: spacing.sm),
                Text(
                  l10n.remotePairingBody,
                  style: text.bodyMedium
                      ?.copyWith(color: scheme.onPrimaryContainer),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
