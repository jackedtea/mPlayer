// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import 'app/app.dart';
import 'features/player/incoming_media.dart';

/// [args] carries a file named on the command line. The Windows and Linux
/// runners already forward it as the Dart entrypoint arguments, so this is
/// all that "open with mPlayer" and `mPlayer video.mkv` need on desktop;
/// Android hands its files over through an intent channel instead.
void main(List<String> args) {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  _registerBundledFontLicenses();
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
