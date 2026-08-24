// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

/// Asking GitHub whether a newer release exists.
///
/// The releases API and nothing else: there is no update *server*, no device
/// identifier and no payload — the check is one anonymous GET against a public
/// endpoint, and it only happens when the user presses the row. An app that
/// phones home on launch is exactly what the privacy page promises this is not.
library;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

const repositoryUrl = 'https://github.com/jackedtea/mPlayer';
const releasesUrl = '$repositoryUrl/releases';
const _latestReleaseApi =
    'https://api.github.com/repos/jackedtea/mPlayer/releases/latest';

@immutable
class ReleaseInfo {
  const ReleaseInfo({required this.version, required this.url});

  /// The tag with any leading `v` removed.
  final String version;

  /// Where to read about it.
  final String url;
}

/// Compares two dotted versions, ignoring anything that is not a number.
///
/// Returns true when [latest] is ahead of [current]. Both sides are cleaned
/// first: a tag is `v1.2.0`, a `pubspec` version is `1.2.0+14`, and a dev
/// build carries `-dev-a1b2c3d` — none of which are part of the comparison.
bool isNewerVersion(String latest, String current) {
  final a = _parts(latest);
  final b = _parts(current);
  if (a.isEmpty || b.isEmpty) return false;

  for (var i = 0; i < (a.length > b.length ? a.length : b.length); i++) {
    // A missing segment is zero: 1.2 and 1.2.0 are the same release.
    final left = i < a.length ? a[i] : 0;
    final right = i < b.length ? b[i] : 0;
    if (left != right) return left > right;
  }
  return false;
}

List<int> _parts(String version) {
  final trimmed = version.trim().toLowerCase();
  final core = trimmed
      .replaceFirst(RegExp(r'^v'), '')
      // Drop the build number and any pre-release suffix.
      .split(RegExp(r'[+\-_ ]'))
      .first;

  return core
      .split('.')
      .map((p) => int.tryParse(p))
      .whereType<int>()
      .toList();
}

/// The newest published release, or null when GitHub cannot be reached.
///
/// Null rather than an exception: failing to reach GitHub is not an error the
/// user did anything about, and the page says "could not check" either way.
Future<ReleaseInfo?> latestRelease({Dio? client}) async {
  final dio = client ??
      Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );

  try {
    final response = await dio.get<Map<String, dynamic>>(_latestReleaseApi);
    final body = response.data;
    if (body == null) return null;

    final tag = body['tag_name'] as String?;
    if (tag == null || tag.isEmpty) return null;

    return ReleaseInfo(
      version: tag.replaceFirst(RegExp(r'^v'), ''),
      url: body['html_url'] as String? ?? releasesUrl,
    );
  } catch (e) {
    debugPrint('Update check failed: $e');
    return null;
  }
}
