// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mplayer/app/theme.dart';
import 'package:mplayer/core/install_source.dart';
import 'package:mplayer/core/update_check.dart';
import 'package:mplayer/core/updater.dart';
import 'package:mplayer/features/settings/update_dialog.dart';
import 'package:mplayer/l10n/app_localizations.dart';

ReleaseAsset _asset(String name) =>
    ReleaseAsset(name: name, url: 'https://dl/$name', size: 50 * 1024 * 1024);

final _release = ReleaseInfo(
  version: '1.3.0',
  tag: 'v1.3.0',
  url: 'https://github.com/jackedtea/mPlayer/releases/tag/v1.3.0',
  notes: '## What changed\n- **Faster** home\n\n| File | For |\n|---|---|',
  assets: <ReleaseAsset>[
    _asset('mPlayer-1.3.0-android-arm64-v8a.apk'),
    _asset('mPlayer-1.3.0-android-armeabi-v7a.apk'),
    _asset('mPlayer-1.3.0-android-x86_64.apk'),
    _asset('mPlayer-1.3.0-windows-x64-setup.exe'),
    _asset('mPlayer-1.3.0-linux-x64.deb'),
  ],
);

/// Downloads nothing and installs nothing; says what it was asked.
class _Installer extends UpdateInstaller {
  _Installer({this.outcome = InstallOutcome.started, this.abis = const <String>['arm64-v8a']});

  final InstallOutcome outcome;
  final List<String> abis;
  final List<String> downloaded = <String>[];

  @override
  Future<List<String>> androidAbis() async => abis;

  @override
  Future<File> download(
    ReleaseAsset asset, {
    required void Function(double? progress) onProgress,
    CancelToken? cancel,
  }) async {
    downloaded.add(asset.name);
    onProgress(0.5);
    onProgress(1);
    return File(asset.name);
  }

  @override
  Future<InstallOutcome> apply(File file, UpdatePlatform platform) async =>
      outcome;
}

ProviderContainer _container({
  String version = '1.2.0',
  ReleaseInfo? release,
  bool allowed = true,
  UpdatePlatform? platform = UpdatePlatform.android,
  _Installer? installer,
  List<UpdateChannel>? asked,
  InstallSource source = const InstallSource.direct(),
}) {
  final container = ProviderContainer(
    overrides: [
      currentVersionProvider.overrideWith((ref) async => version),
      releaseLookupProvider.overrideWithValue((channel) async {
        asked?.add(channel);
        return release;
      }),
      updateAutoCheckAllowedProvider.overrideWithValue(allowed),
      updatePlatformProvider.overrideWithValue(platform),
      updateInstallerProvider.overrideWithValue(installer ?? _Installer()),
      installSourceProvider.overrideWith((ref) async => source),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  group('channels', () {
    test('a dev build follows dev builds, a release follows releases', () {
      expect(UpdateChannel.of('1.2.0'), UpdateChannel.stable);
      expect(UpdateChannel.of('1.2.0-dev-a1b2c3d'), UpdateChannel.dev);
    });

    test('a dev build updates to a different commit, not a bigger number', () {
      const dev = ReleaseInfo(version: 'dev-b2c3d4e', tag: 'dev-b2c3d4e', url: '');
      expect(isUpdate(dev, '1.2.0-dev-a1b2c3d'), isTrue);
      // The same build, in short and long form.
      const same = ReleaseInfo(version: '', tag: 'dev-a1b2c3d4e5f6', url: '');
      expect(isUpdate(same, '1.2.0-dev-a1b2c3d'), isFalse);
    });

    test('a release build updates to a higher number only', () {
      expect(isUpdate(_release, '1.2.0'), isTrue);
      expect(isUpdate(_release, '1.3.0'), isFalse);
      expect(isUpdate(_release, '1.4.0'), isFalse);
    });

    test('the dev list picks the newest dev prerelease', () async {
      final asked = <UpdateChannel>[];
      final container = _container(
        version: '1.2.0-dev-a1b2c3d',
        release: const ReleaseInfo(version: '', tag: 'dev-ffff000', url: ''),
        asked: asked,
      );

      final found = await container.read(updaterProvider).check();
      expect(asked, <UpdateChannel>[UpdateChannel.dev]);
      expect(found, isA<UpdateAvailable>());
    });

    test('a GitHub release reads its files', () {
      final release = releaseFromJson(<String, dynamic>{
        'tag_name': 'v1.3.0',
        'html_url': 'https://x',
        'body': 'notes',
        'assets': <Object?>[
          <String, dynamic>{
            'name': 'mPlayer-1.3.0-windows-x64-setup.exe',
            'browser_download_url': 'https://dl/win-setup.exe',
            'size': 1234,
          },
          <String, dynamic>{'name': 'broken'},
        ],
      })!;
      expect(release.version, '1.3.0');
      expect(release.assets.single.url, 'https://dl/win-setup.exe');
      expect(release.assets.single.size, 1234);
    });
  });

  group('which file', () {
    test('the most preferred ABI the release has', () {
      expect(
        assetFor(_release, UpdatePlatform.android,
                abis: <String>['arm64-v8a', 'armeabi-v7a'])
            ?.name,
        endsWith('arm64-v8a.apk'),
      );
      // A 32-bit-only device gets the 32-bit build.
      expect(
        assetFor(_release, UpdatePlatform.android,
                abis: <String>['armeabi-v7a'])
            ?.name,
        endsWith('armeabi-v7a.apk'),
      );
      // An ABI CI does not build has nothing to install.
      expect(
        assetFor(_release, UpdatePlatform.android, abis: <String>['mips']),
        isNull,
      );
    });

    test('a universal APK serves every ABI', () {
      final release = ReleaseInfo(
        version: '1.4.0',
        tag: 'v1.4.0',
        url: '',
        assets: <ReleaseAsset>[_asset('mPlayer-1.4.0-android-universal.apk')],
      );
      for (final abi in <String>['arm64-v8a', 'armeabi-v7a', 'x86_64']) {
        expect(
          assetFor(release, UpdatePlatform.android, abis: <String>[abi])?.name,
          'mPlayer-1.4.0-android-universal.apk',
        );
      }
    });

    test('a per-ABI APK wins over a universal one', () {
      final release = ReleaseInfo(
        version: '1.5.0',
        tag: 'v1.5.0',
        url: '',
        assets: <ReleaseAsset>[
          _asset('mPlayer-1.5.0-android-universal.apk'),
          _asset('mPlayer-1.5.0-android-arm64-v8a.apk'),
        ],
      );
      expect(
        assetFor(release, UpdatePlatform.android,
                abis: <String>['arm64-v8a', 'armeabi-v7a'])
            ?.name,
        'mPlayer-1.5.0-android-arm64-v8a.apk',
      );
      // No ABI of its own in the release: the universal one still installs.
      expect(
        assetFor(release, UpdatePlatform.android, abis: <String>['x86_64'])
            ?.name,
        'mPlayer-1.5.0-android-universal.apk',
      );
    });

    test('the archive for each desktop', () {
      expect(assetFor(_release, UpdatePlatform.windows)?.name,
          endsWith('windows-x64-setup.exe'));
      expect(assetFor(_release, UpdatePlatform.linux)?.name,
          endsWith('linux-x64.deb'));
    });
  });

  group('the automatic check', () {
    test('never runs where it is not allowed', () async {
      final asked = <UpdateChannel>[];
      final container =
          _container(release: _release, allowed: false, asked: asked);

      expect(await container.read(updaterProvider).checkAutomatically(), isNull);
      expect(asked, isEmpty);
    });

    test('never runs for a copy a store installed', () async {
      final asked = <UpdateChannel>[];
      final container = _container(
        release: _release,
        asked: asked,
        source: const InstallSource.store('Google Play'),
      );

      expect(await container.read(updaterProvider).checkAutomatically(), isNull);
      expect(asked, isEmpty);
    });

    test('honours the switch', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'update_auto_check': false,
      });
      final asked = <UpdateChannel>[];
      final container = _container(release: _release, asked: asked);

      expect(await container.read(updaterProvider).checkAutomatically(), isNull);
      expect(asked, isEmpty);
    });

    test('waits a day between checks', () async {
      final asked = <UpdateChannel>[];
      final container = _container(release: _release, asked: asked);
      final updater = container.read(updaterProvider);
      final now = DateTime.now();

      expect(await updater.checkAutomatically(now: now), isNotNull);
      expect(
        await updater.checkAutomatically(
          now: now.add(const Duration(hours: 2)),
        ),
        isNull,
      );
      expect(asked, hasLength(1));
      expect(
        await updater.checkAutomatically(now: now.add(const Duration(days: 1))),
        isNotNull,
      );
    });

    test('checks on every launch when asked to', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'update_every_launch': true,
      });
      final asked = <UpdateChannel>[];
      final container = _container(release: _release, asked: asked);
      final updater = container.read(updaterProvider);
      final now = DateTime.now();

      expect(await updater.checkAutomatically(now: now), isNotNull);
      expect(
        await updater.checkAutomatically(
          now: now.add(const Duration(minutes: 1)),
        ),
        isNotNull,
      );
      expect(asked, hasLength(2));
    });

    test('stays quiet about a skipped version', () async {
      final container = _container(release: _release);
      await container.read(updateSettingsProvider.notifier).skip('v1.3.0');

      expect(await container.read(updaterProvider).checkAutomatically(), isNull);
    });

    test('offers the file for this device', () async {
      final container = _container(
        release: _release,
        installer: _Installer(abis: <String>['x86_64']),
      );

      final found = await container.read(updaterProvider).checkAutomatically();
      expect(found?.asset?.name, endsWith('x86_64.apk'));
    });
  });

  group('the dialog', () {
    Future<_Installer> open(
      WidgetTester tester, {
      InstallOutcome outcome = InstallOutcome.started,
      bool automatic = false,
      UpdatePlatform? platform = UpdatePlatform.android,
    }) async {
      final installer = _Installer(outcome: outcome);
      final container = _container(
        release: _release,
        installer: installer,
        platform: platform,
      );
      final found = await container.read(updaterProvider).check() as UpdateAvailable;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: buildTheme(Brightness.light),
            localizationsDelegates: const <LocalizationsDelegate<Object>>[
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: FilledButton(
                  onPressed: () =>
                      showUpdateDialog(context, found, automatic: automatic),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return installer;
    }

    testWidgets('offers the version with readable notes', (tester) async {
      await open(tester);

      expect(find.text('Version 1.3.0 is out'), findsOneWidget);
      expect(find.textContaining('50.0 MB'), findsOneWidget);
      expect(find.textContaining('• Faster home'), findsOneWidget);
      // The file table is for the web page.
      expect(find.textContaining('|'), findsNothing);
      // Skip is only for a prompt nobody asked for.
      expect(find.text('Skip this version'), findsNothing);
    });

    testWidgets('downloads the file for this device and hands it over',
        (tester) async {
      final installer = await open(tester);

      await tester.tap(find.text('Update now'));
      await tester.pumpAndSettle();

      expect(installer.downloaded, <String>['mPlayer-1.3.0-android-arm64-v8a.apk']);
      expect(find.textContaining('installer is open'), findsOneWidget);
    });

    testWidgets('a missing install permission says where to grant it',
        (tester) async {
      await open(tester, outcome: InstallOutcome.needsPermission);

      await tester.tap(find.text('Update now'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Allow mPlayer to install apps'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('skipping is remembered', (tester) async {
      await open(tester, automatic: true);

      await tester.tap(find.text('Skip this version'));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('update_skipped_tag'), 'v1.3.0');
    });

    testWidgets('a platform with nothing to install offers the page',
        (tester) async {
      await open(tester, platform: null);
      expect(find.text('Open release page'), findsOneWidget);
      expect(find.text('Update now'), findsNothing);
    });
  });

  test('the desktop scripts restart the app even after a failed install', () {
    // `finally` on Windows; the restart is unconditional on Linux.
    expect(windowsUpdateScript, contains('finally'));
    expect(
      windowsUpdateScript.indexOf(r'Start-Process -FilePath $Exe'),
      greaterThan(windowsUpdateScript.indexOf('finally')),
    );
    expect(linuxUpdateScript, contains('nohup "\$exe"'));
    expect(linuxUpdateScript, contains('kill -0 "\$pid"'));
  });

  test('the desktop scripts install silently, in place', () {
    // Silent, and into the folder the running exe is in — the one restarted.
    expect(windowsUpdateScript, contains('/VERYSILENT'));
    expect(windowsUpdateScript, contains(r'/DIR=`"$Target`"'));
    // A failing installer is caught, not mistaken for success.
    expect(windowsUpdateScript, contains('ExitCode'));
    // dpkg, not apt: two dev builds of one version do not order.
    expect(linuxUpdateScript, contains('pkexec dpkg -i "\$package"'));
  });
}
