// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/resume_repository.dart';
import '../../sources/media_source.dart';
import 'playback_controller.dart';

/// Resolves [mediaRef] and starts it where the user left off.
///
/// Every entry point into the player goes through here, so resuming is not
/// something one screen remembers to do and another forgets.
Future<PlayableMedia> resolveWithResume(
  WidgetRef ref,
  MediaSource source,
  MediaRef mediaRef,
) async {
  final media = await source.resolve(mediaRef);

  final saved = await ref
      .read(resumeRepositoryProvider)
      .find(mediaRef.sourceId, mediaRef.itemId);
  if (saved == null) return media;

  return PlayableMedia(
    ref: media.ref,
    uri: media.uri,
    kind: media.kind,
    capabilities: media.capabilities,
    sourceLine: media.sourceLine,
    headers: media.headers,
    chapters: media.chapters,
    startPosition: saved.position,
  );
}

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
    final media = await resolveWithResume(ref, source, mediaRef);
    if (!context.mounted) return;
    await context.push('/player', extra: media);
  } on MediaSourceException catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.message)),
    );
  }
}
