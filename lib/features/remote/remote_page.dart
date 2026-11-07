// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../remote/remote_protocol.dart';
import '../player/playback_state.dart' show formatDuration;
import 'remote_session.dart';

/// The phone remote: the receivers on this network, then the one chosen.
///
/// One route with three faces — list, PIN, controls — rather than three
/// routes, because the session decides which is showing and a receiver that
/// goes away mid-film should drop the user back on the list, not leave them
/// on a dead control screen with a back stack to unwind.
class RemotePage extends ConsumerStatefulWidget {
  const RemotePage({super.key});

  @override
  ConsumerState<RemotePage> createState() => _RemotePageState();
}

class _RemotePageState extends ConsumerState<RemotePage> {
  late final RemoteSession _session = ref.read(remoteSessionProvider.notifier);

  @override
  void initState() {
    super.initState();
    // After the frame: this mutates a provider, which a build must not do.
    WidgetsBinding.instance.addPostFrameCallback((_) => _session.startSearching());
  }

  @override
  void dispose() {
    // The connection outlives this screen; the search for others does not.
    _session.stopSearching();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(remoteSessionProvider);
    ref.listen<bool>(
      remoteSessionProvider.select((s) => s.unreachable),
      (_, unreachable) {
        if (!unreachable) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.remoteUnreachable)),
        );
      },
    );

    final device = session.device;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          session.connected && device != null ? device.name : l10n.remoteTitle,
        ),
        actions: <Widget>[
          if (device != null)
            IconButton(
              tooltip: l10n.remoteDisconnect,
              icon: const Icon(Icons.link_off_rounded),
              onPressed: _session.disconnect,
            ),
        ],
      ),
      body: SafeArea(
        child: switch (session.phase) {
          RemotePhase.idle => _DeviceList(session: session),
          RemotePhase.connecting => _Connecting(name: device?.name ?? ''),
          RemotePhase.pin => _PinEntry(
              name: device?.name ?? '',
              triesLeft: session.triesLeft,
            ),
          RemotePhase.connected => _Controls(
              name: device?.name ?? '',
              snapshot: session.snapshot,
            ),
        },
      ),
    );
  }
}

class _DeviceList extends ConsumerWidget {
  const _DeviceList({required this.session});

  final RemoteSessionState session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final scheme = context.colors;
    final padding = spacing.screenPadding(context.windowSize);

    return ListView(
      padding: EdgeInsets.symmetric(vertical: spacing.sm),
      children: <Widget>[
        for (final RemoteDevice d in session.devices)
          ListTile(
            contentPadding: padding,
            leading: Icon(
              d.kind == RemoteDeviceKind.television
                  ? Icons.tv_rounded
                  : Icons.desktop_windows_rounded,
            ),
            title: Text(d.name),
            subtitle: Text(d.host),
            trailing: Icon(Icons.chevron_right_rounded, color: scheme.outline),
            onTap: () => ref.read(remoteSessionProvider.notifier).connect(d),
          ),
        if (session.devices.isEmpty)
          Padding(
            padding: padding.add(EdgeInsets.symmetric(vertical: spacing.lg)),
            child: Column(
              children: <Widget>[
                if (session.searching) ...<Widget>[
                  const CircularProgressIndicator(),
                  SizedBox(height: spacing.md),
                  Text(
                    l10n.remoteSearching,
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: spacing.sm),
                ],
                Text(
                  l10n.remoteNoDevices,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        Padding(
          padding: padding,
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              icon: const Icon(Icons.lan_rounded),
              label: Text(l10n.remoteConnectByAddress),
              onPressed: () => _askForAddress(context, ref),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _askForAddress(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController();
    final address = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.remoteConnectByAddress),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(
            labelText: l10n.remoteAddressLabel,
            hintText: '192.168.1.20',
          ),
          onSubmitted: (v) => Navigator.of(dialogContext).pop(v),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: Text(l10n.connect),
          ),
        ],
      ),
    );
    controller.dispose();
    if (address == null || address.trim().isEmpty) return;
    await ref.read(remoteSessionProvider.notifier).connectToAddress(address);
  }
}

class _Connecting extends StatelessWidget {
  const _Connecting({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const CircularProgressIndicator(),
          SizedBox(height: spacing.md),
          Text(AppLocalizations.of(context).remoteConnecting(name)),
        ],
      ),
    );
  }
}

class _PinEntry extends ConsumerStatefulWidget {
  const _PinEntry({required this.name, required this.triesLeft});

  final String name;
  final int? triesLeft;

  @override
  ConsumerState<_PinEntry> createState() => _PinEntryState();
}

class _PinEntryState extends ConsumerState<_PinEntry> {
  final TextEditingController _pin = TextEditingController();

  @override
  void didUpdateWidget(_PinEntry old) {
    super.didUpdateWidget(old);
    // A wrong code: clear it for the next try rather than leaving six digits
    // to delete one by one.
    if (widget.triesLeft != old.triesLeft) _pin.clear();
  }

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  void _submit() {
    final pin = _pin.text.trim();
    if (pin.length != RemoteProtocol.pinDigits) return;
    ref.read(remoteSessionProvider.notifier).submitPin(pin);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final text = Theme.of(context).textTheme;
    final tries = widget.triesLeft;

    return ListView(
      padding: spacing.screenPadding(context.windowSize)
          .add(EdgeInsets.symmetric(vertical: spacing.lg)),
      children: <Widget>[
        Text(l10n.remotePinTitle(widget.name), style: text.headlineSmall),
        SizedBox(height: spacing.sm),
        Text(l10n.remotePinBody(widget.name), style: text.bodyMedium),
        SizedBox(height: spacing.lg),
        TextField(
          controller: _pin,
          autofocus: true,
          keyboardType: TextInputType.number,
          maxLength: RemoteProtocol.pinDigits,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
          ],
          textAlign: TextAlign.center,
          style: text.headlineMedium,
          decoration: InputDecoration(
            labelText: l10n.remotePinLabel,
            errorText: tries == null ? null : l10n.remotePinWrong(tries),
          ),
          onChanged: (v) {
            if (v.length == RemoteProtocol.pinDigits) _submit();
          },
          onSubmitted: (_) => _submit(),
        ),
        SizedBox(height: spacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            TextButton(
              onPressed: ref.read(remoteSessionProvider.notifier).disconnect,
              child: Text(l10n.cancel),
            ),
            SizedBox(width: spacing.sm),
            FilledButton(onPressed: _submit, child: Text(l10n.connect)),
          ],
        ),
      ],
    );
  }
}

class _Controls extends ConsumerStatefulWidget {
  const _Controls({required this.name, required this.snapshot});

  final String name;
  final RemoteSnapshot snapshot;

  @override
  ConsumerState<_Controls> createState() => _ControlsState();
}

class _ControlsState extends ConsumerState<_Controls> {
  /// Where the thumb is while the scrubber is being dragged. The receiver's
  /// position keeps arriving underneath, and following it would snap the
  /// thumb back out from under the user's finger.
  double? _scrubbing;
  double? _volume;

  void _send(RemoteCommand command) =>
      ref.read(remoteSessionProvider.notifier).send(command);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final scheme = context.colors;
    final text = Theme.of(context).textTheme;
    final s = widget.snapshot;

    if (!s.hasMedia) {
      return Center(
        child: Padding(
          padding: spacing.screenPadding(context.windowSize),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.settings_remote_rounded,
                size: spacing.xl * 2,
                color: scheme.primary,
              ),
              SizedBox(height: spacing.md),
              Text(
                l10n.remoteNothingPlaying(widget.name),
                style: text.titleMedium,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: spacing.sm),
              Text(
                l10n.remoteNothingPlayingHint(widget.name),
                style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final durationMs = s.duration.inMilliseconds.toDouble();
    final positionMs = (_scrubbing ??
            s.position.inMilliseconds.toDouble())
        .clamp(0, durationMs > 0 ? durationMs : 0)
        .toDouble();

    return ListView(
      padding: spacing.screenPadding(context.windowSize)
          .add(EdgeInsets.symmetric(vertical: spacing.lg)),
      children: <Widget>[
        Text(s.title ?? '', style: text.headlineSmall),
        // A song's artist and album say what it is; how it is being streamed
        // is the question for a film.
        if (_creditsOf(s) ?? s.subtitle case final String line) ...<Widget>[
          SizedBox(height: spacing.xs),
          Text(
            line,
            style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
        if (s.queueLength > 1) ...<Widget>[
          SizedBox(height: spacing.xs),
          Text(
            '${s.queueIndex + 1} / ${s.queueLength}',
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
        if (s.error != null) ...<Widget>[
          SizedBox(height: spacing.sm),
          Text(s.error!, style: text.bodyMedium?.copyWith(color: scheme.error)),
        ],
        SizedBox(height: spacing.lg),
        Slider(
          value: positionMs,
          max: durationMs > 0 ? durationMs : 1,
          onChanged: durationMs > 0
              ? (v) => setState(() => _scrubbing = v)
              : null,
          onChangeEnd: (v) {
            setState(() => _scrubbing = null);
            _send(
              RemoteCommand(
                RemoteCommandKind.seek,
                at: Duration(milliseconds: v.round()),
              ),
            );
          },
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing.md),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                formatDuration(Duration(milliseconds: positionMs.round())),
                style: text.labelMedium,
              ),
              Text(formatDuration(s.duration), style: text.labelMedium),
            ],
          ),
        ),
        SizedBox(height: spacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            IconButton(
              tooltip: l10n.remotePrevious,
              icon: const Icon(Icons.skip_previous_rounded),
              onPressed: s.hasPrevious
                  ? () => _send(const RemoteCommand(RemoteCommandKind.previous))
                  : null,
            ),
            IconButton(
              tooltip: l10n.skipBack,
              icon: const Icon(Icons.fast_rewind_rounded),
              onPressed: () => _send(
                RemoteCommand(RemoteCommandKind.skip, at: -s.skipBack),
              ),
            ),
            IconButton.filled(
              tooltip: s.playing ? l10n.pause : l10n.play,
              iconSize: spacing.xl,
              padding: EdgeInsets.all(spacing.md),
              icon: Icon(
                s.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              ),
              onPressed: () =>
                  _send(const RemoteCommand(RemoteCommandKind.playPause)),
            ),
            IconButton(
              tooltip: l10n.skipForward,
              icon: const Icon(Icons.fast_forward_rounded),
              onPressed: () => _send(
                RemoteCommand(RemoteCommandKind.skip, at: s.skipForward),
              ),
            ),
            IconButton(
              tooltip: l10n.nextEpisode,
              icon: const Icon(Icons.skip_next_rounded),
              onPressed: s.hasNext
                  ? () => _send(const RemoteCommand(RemoteCommandKind.next))
                  : null,
            ),
          ],
        ),
        SizedBox(height: spacing.lg),
        Row(
          children: <Widget>[
            Icon(Icons.volume_down_rounded, color: scheme.onSurfaceVariant),
            Expanded(
              child: Slider(
                value: _volume ?? s.volume,
                max: 100,
                label: l10n.remoteVolume,
                onChanged: (v) => setState(() => _volume = v),
                onChangeEnd: (v) {
                  setState(() => _volume = null);
                  _send(RemoteCommand(RemoteCommandKind.volume, volume: v));
                },
              ),
            ),
            Icon(Icons.volume_up_rounded, color: scheme.onSurfaceVariant),
          ],
        ),
        SizedBox(height: spacing.md),
        Wrap(
          spacing: spacing.sm,
          runSpacing: spacing.sm,
          alignment: WrapAlignment.center,
          children: <Widget>[
            OutlinedButton.icon(
              icon: const Icon(Icons.audiotrack_rounded),
              label: Text(l10n.audio),
              onPressed: s.audioTracks.isEmpty
                  ? null
                  : () => _pickTrack(
                        title: l10n.audio,
                        tracks: s.audioTracks,
                        active: s.activeAudio,
                        allowOff: false,
                        onPicked: (id) => _send(
                          RemoteCommand(RemoteCommandKind.audio, trackId: id),
                        ),
                      ),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.subtitles_outlined),
              label: Text(l10n.subtitles),
              onPressed: () => _pickTrack(
                title: l10n.subtitles,
                tracks: s.subtitleTracks,
                active: s.activeSubtitle,
                allowOff: true,
                onPicked: (id) => _send(
                  RemoteCommand(RemoteCommandKind.subtitle, trackId: id),
                ),
              ),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.stop_rounded),
              label: Text(l10n.remoteStop),
              onPressed: () => _send(const RemoteCommand(RemoteCommandKind.stop)),
            ),
          ],
        ),
      ],
    );
  }

  /// [onPicked] gets a track id, or null for subtitles off.
  Future<void> _pickTrack({
    required String title,
    required List<RemoteTrack> tracks,
    required String? active,
    required bool allowOff,
    required ValueChanged<String?> onPicked,
  }) async {
    final l10n = AppLocalizations.of(context);
    const offId = 'no';
    final current = active == null || active == offId ? offId : active;

    final picked = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => RadioGroup<String>(
        groupValue: current,
        onChanged: (id) => Navigator.of(sheetContext).pop(id),
        child: ListView(
          shrinkWrap: true,
          children: <Widget>[
            ListTile(
              title: Text(title, style: Theme.of(sheetContext).textTheme.titleMedium),
            ),
            if (allowOff)
              RadioListTile<String>(value: offId, title: Text(l10n.off)),
            for (final RemoteTrack t in tracks)
              RadioListTile<String>(value: t.id, title: Text(t.label)),
          ],
        ),
      ),
    );
    if (picked == null || picked == current) return;
    onPicked(picked == offId ? null : picked);
  }
}

/// The strip over the navigation bar while this phone controls a receiver:
/// what is playing there, play/pause, and the way back to the full remote.
class RemoteBar extends ConsumerWidget {
  const RemoteBar({super.key, required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(remoteSessionProvider);
    final device = session.device;
    if (!session.connected || device == null) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final scheme = context.colors;
    final s = session.snapshot;

    return Material(
      color: scheme.secondaryContainer,
      child: ListTile(
        onTap: onOpen,
        leading: Icon(
          device.kind == RemoteDeviceKind.television
              ? Icons.tv_rounded
              : Icons.desktop_windows_rounded,
          color: scheme.onSecondaryContainer,
        ),
        title: Text(
          s.title ?? l10n.remoteControlling(device.name),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          s.hasMedia ? l10n.remoteSentTo(device.name) : device.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: s.hasMedia
            ? IconButton(
                tooltip: s.playing ? l10n.pause : l10n.play,
                icon: Icon(
                  s.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                ),
                onPressed: () => ref
                    .read(remoteSessionProvider.notifier)
                    .send(const RemoteCommand(RemoteCommandKind.playPause)),
              )
            : null,
      ),
    );
  }
}

/// "Daft Punk · Discovery" for a song; null for a video.
String? _creditsOf(RemoteSnapshot s) {
  final parts = <String>[?s.artist, ?s.album];
  return parts.isEmpty ? null : parts.join(' · ');
}
