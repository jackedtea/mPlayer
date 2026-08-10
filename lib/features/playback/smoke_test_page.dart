// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Temporary page proving the media_kit pipeline works end to end on each
/// target platform. Replaced by the real player shell in Phase 2 of the plan.
class SmokeTestPage extends StatefulWidget {
  const SmokeTestPage({super.key});

  @override
  State<SmokeTestPage> createState() => _SmokeTestPageState();
}

class _SmokeTestPageState extends State<SmokeTestPage> {
  late final Player _player = Player();
  late final VideoController _controller = VideoController(_player);

  @override
  void initState() {
    super.initState();
    _player.open(
      Media(
        'https://user-images.githubusercontent.com/28951144/229373695-22f88f13-d18f-4288-9bf1-c3e078d83722.mp4',
      ),
    );
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('media_kit smoke test')),
      body: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Video(controller: _controller),
          ),
          const SizedBox(height: 12),
          StreamBuilder<bool>(
            stream: _player.stream.playing,
            initialData: false,
            builder: (context, snapshot) => Text(
              snapshot.data! ? 'playing' : 'paused',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          StreamBuilder<Duration>(
            stream: _player.stream.position,
            initialData: Duration.zero,
            builder: (context, snapshot) => Text('position: ${snapshot.data}'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _player.playOrPause,
        child: const Icon(Icons.play_arrow),
      ),
    );
  }
}
