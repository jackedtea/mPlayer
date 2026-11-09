// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

/// Asking GitHub whether a newer release exists, and which of its files this
/// device would install.
///
/// The releases API and nothing else: there is no update *server*, no device
/// identifier and no payload — a check is one anonymous GET against a public
/// endpoint. It runs when the user presses the row, and on its own at most
/// once a day while the automatic check is on (Settings → General).
library;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

const repositoryUrl = 'https://github.com/jackedtea/mPlayer';
const releasesUrl = '$repositoryUrl/releases';
const _api = 'https://api.github.com/repos/jackedtea/mPlayer/releases';

/// Which stream of builds this installation follows.
///
/// CI publishes both from one repository: `main` as ordinary releases tagged
/// `v1.2.0`, and every `dev` push as a **prerelease** tagged `dev-<sha>`,
/// built with a `.canary` application id and a version name ending
/// `-dev-<sha>`. GitHub's "latest" never points at a prerelease, so a dev
/// build asking it would never hear of the next dev build — it asks the
/// rolling release tagged `dev` instead, which CI moves to every new dev
/// build, and nothing else.
enum UpdateChannel {
  stable,
  dev;

  /// Read off the running build's version name.
  static UpdateChannel of(String version) =>
      _devSha(version) == null ? UpdateChannel.stable : UpdateChannel.dev;
}

/// The commit a dev build was made from, or null for a release build.
String? _devSha(String version) {
  final match = RegExp(r'-dev[-.]([0-9a-f]{7,40})', caseSensitive: false)
      .firstMatch(version);
  return match?.group(1)?.toLowerCase();
}

@immutable
class ReleaseAsset {
  const ReleaseAsset({
    required this.name,
    required this.url,
    required this.size,
  });

  final String name;

  /// The direct download, not the page about it.
  final String url;

  /// Bytes, or 0 when GitHub did not say.
  final int size;
}

@immutable
class ReleaseInfo {
  const ReleaseInfo({
    required this.version,
    required this.url,
    this.tag = '',
    this.notes = '',
    this.assets = const <ReleaseAsset>[],
  });

  /// The tag with any leading `v` removed.
  final String version;

  /// Where to read about it.
  final String url;

  final String tag;

  /// The release body, as written; Markdown.
  final String notes;

  final List<ReleaseAsset> assets;
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

/// Whether [release] is one this build should move to.
///
/// A release build compares numbers. A dev build cannot — every dev build of
/// 1.0.0 says 1.0.0 — so it compares commits instead: the newest dev
/// prerelease being a different commit from the one running is the update.
bool isUpdate(ReleaseInfo release, String currentVersion) {
  final running = _devSha(currentVersion);
  if (running == null) return isNewerVersion(release.version, currentVersion);

  final offered = RegExp(r'^dev-([0-9a-f]{7,40})$', caseSensitive: false)
      .firstMatch(release.tag)
      ?.group(1)
      ?.toLowerCase();
  if (offered == null) return false;
  // Short and long forms of one commit are the same build.
  return !(offered.startsWith(running) || running.startsWith(offered));
}

/// The platforms a release carries a file for.
enum UpdatePlatform { android, windows, linux }

/// The file in [release] this device would install, or null when it has none
/// — an ABI CI does not build, or a platform it does not publish for.
///
/// CI publishes one APK per ABI (`<base>-android-<abi>.apk`), and [abis] —
/// the device's own list, most preferred first, as Android reports it —
/// picks among those: the first one the release has an APK for wins, so a
/// 64-bit phone that can also run 32-bit code still gets the 64-bit build.
/// Releases from 2026-11-02 to 2026-11-08 carry a single universal APK
/// instead; it is the fallback when no ABI matches.
ReleaseAsset? assetFor(
  ReleaseInfo release,
  UpdatePlatform platform, {
  List<String> abis = const <String>[],
}) {
  ReleaseAsset? named(String suffix) {
    for (final ReleaseAsset a in release.assets) {
      if (a.name.toLowerCase().endsWith(suffix)) return a;
    }
    return null;
  }

  switch (platform) {
    case UpdatePlatform.android:
      for (final String abi in abis) {
        final asset = named('-android-${abi.toLowerCase()}.apk');
        if (asset != null) return asset;
      }
      return named('-android-universal.apk');
    case UpdatePlatform.windows:
      return named('-windows-x64-setup.exe');
    case UpdatePlatform.linux:
      return named('-linux-x64.deb');
  }
}

ReleaseInfo? releaseFromJson(Object? json) {
  if (json is! Map) return null;

  final tag = json['tag_name'];
  if (tag is! String || tag.isEmpty) return null;

  return ReleaseInfo(
    version: tag.replaceFirst(RegExp(r'^v'), ''),
    tag: tag,
    url: json['html_url'] as String? ?? releasesUrl,
    notes: json['body'] as String? ?? '',
    assets: <ReleaseAsset>[
      for (final Object? a in json['assets'] as List? ?? const <Object?>[])
        if (a is Map &&
            a['name'] is String &&
            a['browser_download_url'] is String)
          ReleaseAsset(
            name: a['name'] as String,
            url: a['browser_download_url'] as String,
            size: (a['size'] as num?)?.toInt() ?? 0,
          ),
    ],
  );
}

/// The rolling `dev` release, read as the build it holds.
///
/// Its tag is always `dev`, so the commit comes from the title CI gives it
/// (`mPlayer 1.0.0-dev.<sha>`), else from a file name
/// (`mPlayer-1.0.0-dev-<sha>-…`), and the result is tagged `dev-<sha>` —
/// what [isUpdate] compares and what "skip this version" remembers, so
/// skipping one dev build does not silence the next. Null when neither
/// names a commit: an update that cannot say what it is is not offered.
@visibleForTesting
ReleaseInfo? devReleaseFromJson(Object? json) {
  final release = releaseFromJson(json);
  if (release == null || json is! Map) return null;

  final sha = _devSha(json['name'] as String? ?? '') ??
      release.assets.map((a) => _devSha(a.name)).nonNulls.firstOrNull;
  if (sha == null) return null;

  return ReleaseInfo(
    version: release.version,
    tag: 'dev-$sha',
    url: release.url,
    notes: release.notes,
    assets: release.assets,
  );
}

/// The newest `dev-*` prerelease in a `/releases` listing, or null.
///
/// Only a fallback now, for before the rolling `dev` release exists.
///
/// Newest by **publish time**, not by position: the listing is not in
/// order. Several dev builds from one day come back shuffled — on
/// 2026-11-09 the morning's `dev-e8eb495` sat first and that night's
/// `dev-560ac9e` fourth — and taking the first offered a build from hours
/// earlier as the update. `created_at` is no better: it is the tagged
/// commit's time, and an older commit can be released after a newer one.
@visibleForTesting
ReleaseInfo? newestDevRelease(Object? listing) {
  if (listing is! List) return null;

  Map<dynamic, dynamic>? newest;
  DateTime? newestAt;
  for (final Object? entry in listing) {
    if (entry is! Map ||
        entry['prerelease'] != true ||
        entry['draft'] == true ||
        !(entry['tag_name'] as String? ?? '').startsWith('dev-')) {
      continue;
    }
    final at = DateTime.tryParse(
      entry['published_at'] as String? ?? entry['created_at'] as String? ?? '',
    );
    if (at == null) continue;
    if (newestAt == null || at.isAfter(newestAt)) {
      newest = entry;
      newestAt = at;
    }
  }
  return newest == null ? null : releaseFromJson(newest);
}

/// The newest release on [channel], or null when GitHub cannot be reached.
///
/// Null rather than an exception: failing to reach GitHub is not an error the
/// user did anything about, and every caller says "could not check" either
/// way.
Future<ReleaseInfo?> latestRelease({
  UpdateChannel channel = UpdateChannel.stable,
  Dio? client,
}) async {
  final dio = client ??
      Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 8),
          headers: <String, String>{'Accept': 'application/vnd.github+json'},
        ),
      );

  try {
    switch (channel) {
      case UpdateChannel.stable:
        final response = await dio.get<Object?>('$_api/latest');
        return releaseFromJson(response.data);

      case UpdateChannel.dev:
        final response = await dio.get<Object?>(
          '$_api/tags/dev',
          // A 404 is an answer here (see below), not a failure.
          options: Options(validateStatus: (code) => code == 200 || code == 404),
        );
        if (response.statusCode == 200) return devReleaseFromJson(response.data);

        // No rolling release yet: the workflow that keeps it had not run
        // when this build was made. The newest of the per-commit ones, until
        // it has.
        final listing = await dio.get<Object?>(
          _api,
          queryParameters: <String, String>{'per_page': '30'},
        );
        return newestDevRelease(listing.data);
    }
  } catch (e) {
    debugPrint('Update check failed: $e');
    return null;
  }
}
