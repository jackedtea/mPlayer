// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter_test/flutter_test.dart';
import 'package:mplayer/servers/stream_preferences.dart';

List<String> _ids(List<StreamQuality> qs) => qs.map((q) => q.id).toList();

void main() {
  test('a 1080p 2.1 Mbps file keeps the smaller resolutions only', () {
    expect(
      _ids(qualitiesFor(
        sourceBitrate: 2100000,
        sourceWidth: 1920,
        sourceHeight: 1080,
      )),
      <String>['original', 'hd4', 'sd2', 'low'],
    );
  });

  test('a 1080p 15 Mbps file can also drop to 1080p at 10 Mbps', () {
    expect(
      _ids(qualitiesFor(sourceBitrate: 15000000, sourceHeight: 1080)),
      <String>['original', 'fhd10', 'hd4', 'sd2', 'low'],
    );
  });

  test('a 720p file is never offered 1080p', () {
    expect(
      _ids(qualitiesFor(sourceBitrate: 15000000, sourceHeight: 720)),
      <String>['original', 'hd4', 'sd2', 'low'],
    );
  });

  test('a 4K file at 60 Mbps keeps everything under it', () {
    expect(
      _ids(qualitiesFor(
        sourceBitrate: 60000000,
        sourceWidth: 3840,
        sourceHeight: 2160,
      )),
      <String>['original', 'fhd20', 'fhd10', 'hd4', 'sd2', 'low'],
    );
  });

  test('a scope rip counts as the 1080p its width says it is', () {
    expect(
      qualitiesFor(sourceBitrate: 30000000, sourceWidth: 1920, sourceHeight: 800)
          .map((q) => q.id),
      contains('fhd20'),
    );
  });

  test('the rung in force stays, so the sheet can show it selected', () {
    expect(
      qualitiesFor(sourceBitrate: 2100000, sourceHeight: 1080, selected: 'uhd')
          .map((q) => q.id),
      contains('uhd'),
    );
  });

  test('nothing reported hides nothing', () {
    expect(qualitiesFor(), streamQualities);
  });
}
