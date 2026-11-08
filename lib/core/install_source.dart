// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

/// Where this copy of mPlayer was installed from, and so who updates it.
///
/// The in-app updater replaces the app with the build GitHub publishes. That
/// is right for a copy that came from GitHub — an APK opened by hand, the
/// Inno Setup installer, the `.deb` — and wrong for one a store put there:
///
/// - the store signs, packages and updates it itself, and two updaters
///   fighting over one app is how a user ends up on neither's build;
/// - on Android a store build is signed with the store's key (Play App
///   Signing, F-Droid), so the system installer would refuse GitHub's APK
///   anyway — after a download of tens of MB;
/// - an MSIX, a Flatpak or a Snap lives in a folder the Inno installer or
///   dpkg does not own.
///
/// So a store copy never checks GitHub on its own, and Settings says which
/// store updates it instead of offering a button that cannot work.
///
/// **Unknown means GitHub.** Only an installer named below is a store: the
/// system's package installer, `adb`, a file manager, a browser or Obtainium
/// (which fetches the GitHub release itself) all leave self-update on.
library;

import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class InstallSource {
  /// Installed by hand from a GitHub release; mPlayer updates itself.
  const InstallSource.direct()
      : store = null,
        storeUri = null;

  const InstallSource.store(String this.store, {this.storeUri});

  /// The store's name as its users know it, or null for a direct install.
  final String? store;

  /// Where this app's page in that store opens, when there is one.
  final Uri? storeUri;

  bool get fromStore => store != null;

  @override
  bool operator ==(Object other) =>
      other is InstallSource &&
      other.store == store &&
      other.storeUri == storeUri;

  @override
  int get hashCode => Object.hash(store, storeUri);

  @override
  String toString() => fromStore ? 'InstallSource($store)' : 'InstallSource(direct)';
}

/// Android installers that are stores, by package name.
///
/// F-Droid and its clients are here although some repositories ship the
/// developer's own APK: they keep the app up to date themselves, and a
/// second updater only races them.
@visibleForTesting
const androidStores = <String, String>{
  'com.android.vending': 'Google Play',
  'com.google.android.feedback': 'Google Play',
  'com.amazon.venezia': 'Amazon Appstore',
  'com.sec.android.app.samsungapps': 'Galaxy Store',
  'com.huawei.appmarket': 'AppGallery',
  'com.xiaomi.market': 'GetApps',
  'com.xiaomi.mipicks': 'GetApps',
  'com.heytap.market': 'App Market',
  'com.oppo.market': 'App Market',
  'com.bbk.appstore': 'V-Appstore',
  'com.vivo.appstore': 'V-Appstore',
  'org.fdroid.fdroid': 'F-Droid',
  'org.fdroid.basic': 'F-Droid',
  'com.looker.droidify': 'Droid-ify',
  'com.machiav3lli.fdroid': 'Neo Store',
  'com.aurora.store': 'Aurora Store',
};

/// What Android's answer means. Pure, so it is tested without a device.
@visibleForTesting
InstallSource androidInstallSource({String? installer, String? package}) {
  final store = installer == null ? null : androidStores[installer];
  if (store == null) return const InstallSource.direct();
  return InstallSource.store(
    store,
    // Every store above answers `market://` for its own listings.
    storeUri: package == null
        ? null
        : Uri.parse('market://details?id=$package'),
  );
}

/// What Linux's environment means. Pure, for the same reason.
@visibleForTesting
InstallSource linuxInstallSource(
  Map<String, String> environment, {
  bool flatpakInfo = false,
}) {
  if (flatpakInfo || (environment['FLATPAK_ID'] ?? '').isNotEmpty) {
    return const InstallSource.store('Flatpak');
  }
  if ((environment['SNAP'] ?? '').isNotEmpty) {
    return const InstallSource.store('Snap Store');
  }
  return const InstallSource.direct();
}

final installSourceProvider = FutureProvider<InstallSource>(
  (ref) => detectInstallSource(),
);

/// Asks the platform once. Never throws: anything it cannot tell is a
/// direct install, which is what every build CI publishes is.
Future<InstallSource> detectInstallSource() async {
  if (kIsWeb) return const InstallSource.direct();
  try {
    if (Platform.isAndroid) return await _android();
    if (Platform.isWindows) return _windows();
    if (Platform.isLinux) {
      return linuxInstallSource(
        Platform.environment,
        flatpakInfo: File('/.flatpak-info').existsSync(),
      );
    }
    // iOS and macOS have no self-update to switch off: `updatePlatformProvider`
    // is null there, and an App Store build is the only kind there is.
    if (Platform.isIOS || Platform.isMacOS) {
      return const InstallSource.store('App Store');
    }
  } catch (e) {
    debugPrint('Could not tell where mPlayer was installed from: $e');
  }
  return const InstallSource.direct();
}

Future<InstallSource> _android() async {
  const channel = MethodChannel('dev.icedtea.mplayer/update');
  final answer =
      await channel.invokeMapMethod<String, String?>('installSource');
  return androidInstallSource(
    installer: answer?['installer'],
    package: answer?['package'],
  );
}

typedef _PackageNameNative = Int32 Function(Pointer<Uint32>, Pointer<Utf16>);
typedef _PackageNameDart = int Function(Pointer<Uint32>, Pointer<Utf16>);

/// An MSIX — the Microsoft Store's, or one sideloaded — runs with a package
/// identity; the Inno Setup install does not. `GetCurrentPackageFullName`
/// asked with a zero-length buffer answers "too small" (122) for the first
/// and `APPMODEL_ERROR_NO_PACKAGE` (15700) for the second.
InstallSource _windows() {
  const insufficientBuffer = 122;
  final kernel32 = DynamicLibrary.open('kernel32.dll');
  final fullName = kernel32.lookupFunction<_PackageNameNative, _PackageNameDart>(
    'GetCurrentPackageFullName',
  );
  final length = calloc<Uint32>();
  try {
    final result = fullName(length, nullptr);
    if (result != 0 && result != insufficientBuffer) {
      return const InstallSource.direct();
    }
  } finally {
    calloc.free(length);
  }
  return InstallSource.store(
    'Microsoft Store',
    storeUri: Uri.parse('ms-windows-store://downloadsandupdates'),
  );
}
