// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

/// Checking for an update on its own, and installing one.
///
/// [update_check.dart] answers "is there a newer build, and which file is
/// mine"; this decides when to ask, remembers what the user said, and gets the
/// file onto the device:
///
/// - **Android** — the APK for the device's ABI is downloaded into the cache
///   and handed to the system installer, which asks the user to confirm and
///   refuses anything not signed like the installed app.
/// - **Windows / Linux** — the installer (a per-user Inno Setup `.exe`, or a
///   `.deb`) is downloaded, and a small script started beside the app waits
///   for it to exit, installs it — silently on Windows, through `pkexec dpkg`
///   on Linux — and starts it again. On Windows a folder this user cannot
///   write to is not attempted: the release page is the honest answer there.
/// - **Anywhere else** — the release page.
///
/// None of it runs for a copy a store installed ([installSourceProvider]):
/// the store updates that one, and Settings says so.
library;

import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'install_source.dart';
import 'update_check.dart';

// ------------------------------------------------------------------ settings

@immutable
class UpdateSettings {
  const UpdateSettings({
    this.autoCheck = true,
    this.everyLaunch = false,
    this.lastCheck,
    this.skippedTag,
  });

  /// Whether a launch checks on its own, at most once a day.
  final bool autoCheck;

  /// Whether that check runs on every launch rather than once a day.
  final bool everyLaunch;

  final DateTime? lastCheck;

  /// A release the user said not to be told about again. Only the automatic
  /// check honours it; pressing the button always says what is there.
  final String? skippedTag;

  UpdateSettings copyWith({
    bool? autoCheck,
    bool? everyLaunch,
    DateTime? lastCheck,
    String? skippedTag,
  }) {
    return UpdateSettings(
      autoCheck: autoCheck ?? this.autoCheck,
      everyLaunch: everyLaunch ?? this.everyLaunch,
      lastCheck: lastCheck ?? this.lastCheck,
      skippedTag: skippedTag ?? this.skippedTag,
    );
  }
}

final updateSettingsProvider =
    AsyncNotifierProvider<UpdateSettingsController, UpdateSettings>(
  UpdateSettingsController.new,
);

class UpdateSettingsController extends AsyncNotifier<UpdateSettings> {
  static const _autoKey = 'update_auto_check';
  static const _launchKey = 'update_every_launch';
  static const _lastKey = 'update_last_check';
  static const _skipKey = 'update_skipped_tag';

  @override
  Future<UpdateSettings> build() async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt(_lastKey);
    return UpdateSettings(
      autoCheck: prefs.getBool(_autoKey) ?? true,
      everyLaunch: prefs.getBool(_launchKey) ?? false,
      lastCheck: last == null ? null : DateTime.fromMillisecondsSinceEpoch(last),
      skippedTag: prefs.getString(_skipKey),
    );
  }

  Future<void> setAutoCheck(bool on) async {
    final current = await future;
    state = AsyncValue<UpdateSettings>.data(current.copyWith(autoCheck: on));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoKey, on);
  }

  Future<void> setEveryLaunch(bool on) async {
    final current = await future;
    state = AsyncValue<UpdateSettings>.data(current.copyWith(everyLaunch: on));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_launchKey, on);
  }

  Future<void> markChecked(DateTime when) async {
    final current = await future;
    state = AsyncValue<UpdateSettings>.data(current.copyWith(lastCheck: when));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastKey, when.millisecondsSinceEpoch);
  }

  Future<void> skip(String tag) async {
    final current = await future;
    state = AsyncValue<UpdateSettings>.data(current.copyWith(skippedTag: tag));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_skipKey, tag);
  }
}

// ------------------------------------------------------------ what is here

/// The running build's version name — `1.2.0`, or `1.2.0-dev-a1b2c3d`.
final currentVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return info.version;
});

/// Which file this device installs, or null for none.
final updatePlatformProvider = Provider<UpdatePlatform?>((ref) {
  if (kIsWeb) return null;
  if (Platform.isAndroid) return UpdatePlatform.android;
  if (Platform.isWindows) return UpdatePlatform.windows;
  if (Platform.isLinux) return UpdatePlatform.linux;
  return null;
});

/// How a release is looked up. A seam for tests, which have no network.
final releaseLookupProvider =
    Provider<Future<ReleaseInfo?> Function(UpdateChannel channel)>(
  (ref) => (channel) => latestRelease(channel: channel),
);

final updateInstallerProvider = Provider<UpdateInstaller>(
  (ref) => UpdateInstaller(),
);

/// Whether a launch may check by itself.
///
/// Release builds only. A debug build is someone running the app from source,
/// for whom "a newer release exists" is noise — and it keeps every widget
/// test, which runs in debug, off the network.
final updateAutoCheckAllowedProvider = Provider<bool>((ref) => kReleaseMode);

// ------------------------------------------------------------------ checking

/// What a check found.
sealed class UpdateCheck {
  const UpdateCheck();
}

class UpdateUpToDate extends UpdateCheck {
  const UpdateUpToDate(this.version);
  final String version;
}

class UpdateFailed extends UpdateCheck {
  const UpdateFailed();
}

class UpdateAvailable extends UpdateCheck {
  const UpdateAvailable({required this.release, this.asset});

  final ReleaseInfo release;

  /// Null when the release has nothing this device can install in place.
  final ReleaseAsset? asset;
}

final updaterProvider = Provider<Updater>(Updater.new);

class Updater {
  Updater(this._ref);

  final Ref _ref;

  /// How long an automatic check waits after the last one.
  ///
  /// "Once a day", with slack: someone who opens the app at about the same
  /// time each evening would, against a full 24 h, find it 23 h 50 m since
  /// the last check and be skipped — and checked a day late, every other day.
  static const interval = Duration(hours: 20);

  /// Asks GitHub now, as the button does.
  Future<UpdateCheck> check() async {
    final version = await _ref.read(currentVersionProvider.future);
    final release = await _ref.read(releaseLookupProvider)(
      UpdateChannel.of(version),
    );
    await _ref
        .read(updateSettingsProvider.notifier)
        .markChecked(DateTime.now());

    if (release == null) return const UpdateFailed();
    if (!isUpdate(release, version)) return UpdateUpToDate(version);

    return UpdateAvailable(release: release, asset: await _assetFor(release));
  }

  /// The launch's own check: only in a release build, only for a copy that
  /// did not come from a store, only while switched on, at most once per
  /// [interval] unless the user asked for every launch, and silent unless there is something the user has not
  /// already said to skip. Null means say nothing.
  Future<UpdateAvailable?> checkAutomatically({DateTime? now}) async {
    if (!_ref.read(updateAutoCheckAllowedProvider)) return null;
    if ((await _ref.read(installSourceProvider.future)).fromStore) return null;

    final settings = await _ref.read(updateSettingsProvider.future);
    if (!settings.autoCheck) return null;

    final last = settings.lastCheck;
    final at = now ?? DateTime.now();
    if (!settings.everyLaunch &&
        last != null &&
        at.difference(last) < interval) {
      return null;
    }

    final found = await check();
    if (found is! UpdateAvailable) return null;
    if (found.release.tag == settings.skippedTag) return null;
    return found;
  }

  Future<ReleaseAsset?> _assetFor(ReleaseInfo release) async {
    final platform = _ref.read(updatePlatformProvider);
    if (platform == null) return null;

    final abis = platform == UpdatePlatform.android
        ? await _ref.read(updateInstallerProvider).androidAbis()
        : const <String>[];
    return assetFor(release, platform, abis: abis);
  }
}

// ---------------------------------------------------------------- installing

/// How an install attempt ended, short of the app restarting.
enum InstallOutcome {
  /// The system installer is up (Android); the user takes it from here.
  started,

  /// Android has not been allowed to install from mPlayer; its settings page
  /// for that has been opened.
  needsPermission,

  /// The install folder cannot be written by this user.
  notWritable,

  failed,
}

/// The platform half of an update: download the file, then hand it over.
class UpdateInstaller {
  UpdateInstaller({Dio? client})
      : _dio = client ??
            Dio(BaseOptions(connectTimeout: const Duration(seconds: 10)));

  final Dio _dio;

  static const _channel = MethodChannel('dev.icedtea.mplayer/update');

  /// Android's ABIs, most preferred first; empty anywhere else.
  Future<List<String>> androidAbis() async {
    if (kIsWeb || !Platform.isAndroid) return const <String>[];
    try {
      final abis = await _channel.invokeListMethod<String>('supportedAbis');
      return abis ?? const <String>[];
    } on PlatformException catch (e) {
      debugPrint('Could not read the ABIs: $e');
      return const <String>[];
    }
  }

  /// Downloads [asset] into the cache, reporting progress as a fraction —
  /// or null while the size is unknown.
  ///
  /// The `updates` folder is the one Android's FileProvider shares with the
  /// installer; see `res/xml/update_paths.xml`.
  Future<File> download(
    ReleaseAsset asset, {
    required void Function(double? progress) onProgress,
    CancelToken? cancel,
  }) async {
    final dir = Directory(p.join((await getTemporaryDirectory()).path, 'updates'));
    // An earlier update's file has done its job, and APKs are tens of MB.
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    dir.createSync(recursive: true);

    final file = File(p.join(dir.path, asset.name));
    await _dio.download(
      asset.url,
      file.path,
      cancelToken: cancel,
      onReceiveProgress: (received, total) {
        final size = total > 0 ? total : asset.size;
        onProgress(size > 0 ? received / size : null);
      },
    );
    return file;
  }

  /// Hands [file] over. On Windows and Linux a successful hand-over ends this
  /// process, so the call does not return.
  Future<InstallOutcome> apply(File file, UpdatePlatform platform) async {
    switch (platform) {
      case UpdatePlatform.android:
        return _android(file);
      case UpdatePlatform.windows:
      case UpdatePlatform.linux:
        return _desktop(file, platform);
    }
  }

  Future<InstallOutcome> _android(File apk) async {
    try {
      final allowed = await _channel.invokeMethod<bool>('canInstall') ?? false;
      if (!allowed) {
        await _channel.invokeMethod<void>('openInstallSettings');
        return InstallOutcome.needsPermission;
      }
      final started = await _channel.invokeMethod<bool>(
            'installApk',
            <String, String>{'path': apk.path},
          ) ??
          false;
      return started ? InstallOutcome.started : InstallOutcome.failed;
    } on PlatformException catch (e) {
      debugPrint('Install failed: $e');
      return InstallOutcome.failed;
    }
  }

  /// [package] is the Windows installer or the Linux .deb.
  Future<InstallOutcome> _desktop(File package, UpdatePlatform platform) async {
    final exe = Platform.resolvedExecutable;
    final target = p.dirname(exe);

    final scripts = package.parent;
    final List<String> command;
    if (platform == UpdatePlatform.windows) {
      // The installer is per-user and runs without elevation, so it can only
      // update a folder this user can write — which an install it made always
      // is. A copy somewhere else (Program Files, a read-only share) is told
      // so up front rather than left to fail silently behind a hidden window.
      if (!_writable(target)) return InstallOutcome.notWritable;
      final script = File(p.join(scripts.path, 'apply-update.ps1'))
        ..writeAsStringSync(windowsUpdateScript);
      command = <String>[
        'powershell.exe',
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-WindowStyle',
        'Hidden',
        '-File',
        script.path,
        '-ProcessId',
        '$pid',
        '-Installer',
        package.path,
        '-Target',
        target,
        '-Exe',
        exe,
      ];
    } else {
      // /opt is root's, and is meant to be: dpkg installs it, through
      // pkexec's password prompt. No writability test for that reason.
      final script = File(p.join(scripts.path, 'apply-update.sh'))
        ..writeAsStringSync(linuxUpdateScript);
      command = <String>[
        '/bin/sh',
        script.path,
        '$pid',
        package.path,
        exe,
      ];
    }

    try {
      await Process.start(
        command.first,
        command.sublist(1),
        mode: ProcessStartMode.detached,
      );
    } on ProcessException catch (e) {
      debugPrint('Could not start the updater: $e');
      return InstallOutcome.failed;
    }

    // The script is waiting for this process to go before it installs — a
    // running exe and its DLLs are locked on Windows — and on both, the
    // restart afterwards would otherwise only raise this instance's window
    // through the single-instance socket.
    exit(0);
  }

  /// Whether this user can create files in [dir] — the only test that
  /// answers for ACLs, read-only mounts and Program Files alike.
  static bool _writable(String dir) {
    final probe = File(p.join(dir, '.mplayer-update-probe'));
    try {
      probe.writeAsStringSync('');
      probe.deleteSync();
      return true;
    } on FileSystemException {
      return false;
    }
  }
}

/// Waits for the app to exit, runs the installer silently over the folder it
/// is in and starts it again — the start is in `finally`, so a failed install
/// still leaves the user with the app they had rather than with nothing
/// running. What went wrong is written beside the installer for anyone who
/// goes looking.
///
/// `/DIR` names the folder outright rather than trusting the installer to
/// find the previous install: the exe started afterwards is this one, so this
/// is the folder that has to be the updated one.
@visibleForTesting
const windowsUpdateScript = r'''
param(
  [int]$ProcessId,
  [string]$Installer,
  [string]$Target,
  [string]$Exe
)
$ErrorActionPreference = 'Stop'
try { Wait-Process -Id $ProcessId -Timeout 60 -ErrorAction SilentlyContinue } catch {}
try {
  $setup = Start-Process -FilePath $Installer -Wait -PassThru `
    -ArgumentList "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /DIR=`"$Target`""
  if ($setup.ExitCode -ne 0) { throw "The installer exited with code $($setup.ExitCode)." }
} catch {
  $_ | Out-File -FilePath (Join-Path (Split-Path $Installer) 'update-error.txt')
} finally {
  Start-Process -FilePath $Exe
}
''';

/// The Linux counterpart: `pkexec` puts up the desktop's own password prompt
/// for `dpkg -i`. dpkg rather than apt because two dev builds of one version
/// do not order by commit, and apt refuses what it reads as a downgrade.
/// The dependencies are already there from the first install. dpkg's output
/// lands beside the package, and the restart is unconditional — a cancelled
/// prompt still leaves the old app running.
@visibleForTesting
const linuxUpdateScript = r'''
#!/bin/sh
pid="$1"; package="$2"; exe="$3"
i=0
while kill -0 "$pid" 2>/dev/null && [ "$i" -lt 120 ]; do
  sleep 0.5
  i=$((i + 1))
done
pkexec dpkg -i "$package" > "$(dirname "$package")/update.log" 2>&1
nohup "$exe" >/dev/null 2>&1 &
''';
