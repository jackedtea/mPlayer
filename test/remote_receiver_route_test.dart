// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mplayer/app/app.dart';
import 'package:mplayer/app/router.dart';
import 'package:mplayer/core/models/media_models.dart';
import 'package:mplayer/features/player/playback_controller.dart';
import 'package:mplayer/features/player/playback_state.dart';
import 'package:mplayer/features/player/player_page.dart';
import 'package:mplayer/features/remote/remote_receiver.dart';
import 'package:mplayer/remote/remote_protocol.dart';
import 'package:mplayer/sources/media_source.dart';

class _FakePlayback extends PlaybackController {
  @override
  PlaybackState build() => const PlaybackState();

  @override
  Future<void> openResolved(PlayableMedia media, {PlaybackQueue? queue}) async {
    state = state.copyWith(media: media);
  }

  @override
  Future<void> loadSiblingQueue(MediaRef mediaRef) async {}

  @override
  Future<void> stop() async {
    // After a gap, as the real one is: the page calls this from `dispose`.
    await Future<void>.value();
    state = const PlaybackState();
  }
}

void main() {
  testWidgets('a phone stopping a film leaves the player screen', (
    tester,
  ) async {
    // The player is always pushed, and `currentConfiguration.uri` still names
    // the route underneath after a push. Going by that, the receiver never
    // saw its own player: Stop left a dead screen up, and "play this" stacked
    // a second player whose elder's teardown stopped the decoder under it.
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final container = ProviderContainer(
      overrides: [playbackControllerProvider.overrideWith(_FakePlayback.new)],
    );
    addTearDown(container.dispose);

    final router = buildRouter();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MPlayerApp(router: router),
      ),
    );
    await tester.pumpAndSettle();

    router.go('/settings');
    await tester.pumpAndSettle();
    router.push(
      '/player',
      extra: PlayableMedia(
        ref: const MediaRef(sourceId: 'p1', itemId: 'a1', title: 'Dune'),
        uri: Uri.parse('https://media.home.lan/stream'),
        kind: SourceKind.jellyfin,
        capabilities: const SourceCapabilities(),
        sourceLine: 'Jellyfin',
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(PlayerPage), findsOneWidget);

    final receiver = container.read(remoteReceiverProvider.notifier)
      ..router = router;
    await receiver.handle(const RemoteCommand(RemoteCommandKind.stop));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(PlayerPage), findsNothing);
    expect(router.state.uri.path, '/settings');

    // Past the chrome's auto-hide, so no timer outlives the test.
    await tester.pump(const Duration(seconds: 4));
  });
}
