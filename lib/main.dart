// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:io' show exit;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import 'app/app.dart';
import 'app/desktop_window.dart';
import 'app/system_ui.dart';
import 'features/player/incoming_media.dart';

/// [args] carries a file named on the command line. The Windows and Linux
/// runners already forward it as the Dart entrypoint arguments, so this is
/// all that "open with mPlayer" and `mPlayer video.mkv` need on desktop;
/// Android hands its files over through an intent channel instead.
Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Before anything else on desktop: a second launch hands its file to the
  // instance already running and stops here, rather than opening a second
  // player to fight the first over the audio device.
  if (!await claimSingleInstance(args)) {
    exit(0);
  }

  MediaKit.ensureInitialized();
  _registerBundledFontLicenses();

  await applyBaselineSystemUi();

  // `waitUntilReadyToShow` keeps the window hidden while the saved size and
  // position are applied, so the user does not watch it appear at the default
  // size and then jump.
  await restoreWindow();
  await watchWindowBounds();

  runApp(
    ProviderScope(
      overrides: [startupArgumentsProvider.overrideWithValue(args)],
      child: const MPlayerApp(),
    ),
  );
}

/// Roboto ships inside the app, so its OFL notice has to ship with it — this
/// puts it in the list `showLicensePage` renders from the About page.
void _registerBundledFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString('assets/fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(<String>['Roboto'], license);
  });
}
