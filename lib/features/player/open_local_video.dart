// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../sources/media_source.dart';
import 'playback_controller.dart';

/// Picks a video off the device and opens the player on it.
///
/// Resolution happens here rather than inside the player so a missing or
/// unreadable file reports as a snackbar on the screen the user is already
/// looking at, instead of pushing a black player that then shows an error.
///
/// Shared by the Files FAB and the navigation rail's leading action.
Future<void> openLocalVideo(BuildContext context, WidgetRef ref) async {
  final source = ref.read(localSourceProvider);

  final MediaRef? mediaRef = await source.pickVideo();
  if (mediaRef == null) return; // cancelled
  if (!context.mounted) return;

  try {
    final media = await source.resolve(mediaRef);
    if (!context.mounted) return;
    await context.push('/player', extra: media);
  } on MediaSourceException catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.message)),
    );
  }
}
