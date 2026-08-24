// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter_test/flutter_test.dart';

import 'package:mplayer/core/update_check.dart';

void main() {
  group('isNewerVersion', () {
    test('compares numerically, not as text', () {
      // The trap: "1.10.0" sorts before "1.9.0" as a string.
      expect(isNewerVersion('1.10.0', '1.9.0'), isTrue);
      expect(isNewerVersion('1.9.0', '1.10.0'), isFalse);
      expect(isNewerVersion('2.0.0', '1.99.99'), isTrue);
    });

    test('the same release is not an update', () {
      expect(isNewerVersion('1.0.0', '1.0.0'), isFalse);
      // A missing segment is zero.
      expect(isNewerVersion('1.2', '1.2.0'), isFalse);
      expect(isNewerVersion('1.2.0', '1.2'), isFalse);
    });

    test('strips the tag prefix CI writes', () {
      // Releases are tagged `v1.2.0`; the running build reports `1.2.0`.
      expect(isNewerVersion('v1.3.0', '1.2.0'), isTrue);
      expect(isNewerVersion('V1.2.0', '1.2.0'), isFalse);
    });

    test('ignores the build number and a dev suffix', () {
      // `pubspec` carries `1.0.0+1`, and a dev build's version name ends in
      // `-dev-<sha>`. Neither is part of which release is newer.
      expect(isNewerVersion('1.0.0', '1.0.0+42'), isFalse);
      expect(isNewerVersion('1.1.0', '1.0.0-dev-a1b2c3d'), isTrue);
      expect(isNewerVersion('1.0.0', '1.0.0-dev-a1b2c3d'), isFalse);
    });

    test('nonsense on either side is never an update', () {
      // Prompting someone to upgrade to a version that does not parse is
      // worse than staying quiet.
      expect(isNewerVersion('', '1.0.0'), isFalse);
      expect(isNewerVersion('latest', '1.0.0'), isFalse);
      expect(isNewerVersion('1.0.0', ''), isFalse);
      expect(isNewerVersion('1.0.0', '-'), isFalse);
    });
  });

  group('links', () {
    test('point at the repository CI publishes to', () {
      expect(repositoryUrl, 'https://github.com/jackedtea/mPlayer');
      expect(releasesUrl, startsWith(repositoryUrl));
      expect(releasesUrl, endsWith('/releases'));
    });
  });
}
