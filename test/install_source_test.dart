// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter_test/flutter_test.dart';

import 'package:mplayer/core/install_source.dart';

void main() {
  group('Android', () {
    test('a store installer is a store, with its page', () {
      final source = androidInstallSource(
        installer: 'com.android.vending',
        package: 'dev.icedtea.mplayer',
      );
      expect(source.fromStore, isTrue);
      expect(source.store, 'Google Play');
      expect(source.storeUri.toString(),
          'market://details?id=dev.icedtea.mplayer');
    });

    test('an APK opened by hand updates itself', () {
      for (final installer in <String?>[
        null, // adb
        'com.google.android.packageinstaller',
        'com.android.packageinstaller',
        'dev.imranr.obtainium',
        'com.android.chrome',
      ]) {
        expect(androidInstallSource(installer: installer).fromStore, isFalse,
            reason: '$installer');
      }
    });
  });

  group('Linux', () {
    test('Flatpak and Snap are stores', () {
      expect(linuxInstallSource(const {}, flatpakInfo: true).store, 'Flatpak');
      expect(linuxInstallSource(const {'FLATPAK_ID': 'dev.icedtea.mplayer'})
          .store, 'Flatpak');
      expect(linuxInstallSource(const {'SNAP': '/snap/mplayer/1'}).store,
          'Snap Store');
    });

    test('the .deb updates itself', () {
      expect(linuxInstallSource(const {'HOME': '/home/nam', 'SNAP': ''})
          .fromStore, isFalse);
    });
  });

  test('detection never throws, and the test host is no store', () async {
    // flutter test runs unpackaged on Windows and outside any sandbox on
    // Linux, so this also exercises the Windows FFI call for real there.
    expect((await detectInstallSource()).fromStore, isFalse);
  });
}
