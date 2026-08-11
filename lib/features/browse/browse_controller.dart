// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/library_models.dart';
import '../../sources/media_source.dart';
import '../../sources/source_registry.dart';

/// Identifies which directory of which source a browser screen is showing.
@immutable
class BrowseLocation {
  const BrowseLocation({required this.sourceId, this.path = ''});

  final String sourceId;
  final String path;

  BrowseLocation child(String childPath) =>
      BrowseLocation(sourceId: sourceId, path: childPath);

  @override
  bool operator ==(Object other) =>
      other is BrowseLocation &&
      other.sourceId == sourceId &&
      other.path == path;

  @override
  int get hashCode => Object.hash(sourceId, path);
}

/// Lists one directory.
///
/// A family so navigating into a folder is a new provider rather than mutable
/// state — going back re-reads from cache instead of re-walking the share.
final directoryListingProvider =
    FutureProvider.family<BrowseListing, BrowseLocation>((ref, location) async {
  final drivers = ref.watch(sourceRegistryProvider).drivers;
  final source = drivers[location.sourceId];

  if (source == null) {
    throw MediaSourceException(
      'That source is not configured, or its driver is not available yet.',
    );
  }
  if (source is! BrowsableSource) {
    throw MediaSourceException('${source.kind.label} cannot be browsed.');
  }

  return source.listDirectory(location.path);
});

/// Splits a source-relative path into breadcrumb segments.
List<String> breadcrumbSegments(String path) =>
    path.split('/').where((s) => s.isNotEmpty).toList();

/// The parent of [path], or null at the root.
String? parentPath(String path) {
  final segments = breadcrumbSegments(path);
  if (segments.isEmpty) return null;
  segments.removeLast();
  return segments.isEmpty ? '' : '/${segments.join('/')}';
}
