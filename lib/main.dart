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

/// No arguments are read any more.
///
/// `main` used to take the file named on the command line and hand it to the
/// player, which is what made `mPlayer video.mkv` and "open with mPlayer"
/// work on desktop. There is no local source left to open one with — mPlayer
/// plays what a media server gives it — so nothing names a file here.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Before anything else on desktop: a second launch raises the window that
  // is already up rather than opening one of its own.
  if (!await claimSingleInstance()) {
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

  runApp(const ProviderScope(child: MPlayerApp()));
}

/// Roboto ships inside the app, so its OFL notice has to ship with it — this
/// puts it in the list `showLicensePage` renders from the About page.
void _registerBundledFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString('assets/fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(<String>['Roboto'], license);
  });
}
