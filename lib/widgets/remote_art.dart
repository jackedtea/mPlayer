// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Artwork fetched from a server, over whatever is already drawn.
///
/// Deliberately draws **nothing** while it loads and nothing if it fails:
/// this sits on top of `GradientArt`, which is already a complete picture. A
/// spinner or a broken-image glyph over a poster that looks finished is worse
/// than the poster simply staying as it is.
///
/// Cached on disk rather than in memory alone. A library grid re-fetching
/// forty posters on every scroll is the difference between a client that
/// feels local and one that does not.
class RemoteArt extends StatelessWidget {
  const RemoteArt({super.key, required this.url, this.fit = BoxFit.cover});

  /// Null when the item has no artwork, which is the common case for an
  /// unmatched file.
  final Uri? url;

  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final source = url;
    if (source == null) return const SizedBox.shrink();

    return CachedNetworkImage(
      imageUrl: source.toString(),
      fit: fit,
      // Fades in over the gradient rather than replacing it abruptly, which
      // on a fast connection reads as a flicker.
      fadeInDuration: const Duration(milliseconds: 180),
      placeholder: (_, _) => const SizedBox.shrink(),
      errorWidget: (_, _, _) => const SizedBox.shrink(),
    );
  }
}
