// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:convert';
import 'dart:typed_data' show Uint8List;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mplayer/app/app.dart';
import 'package:mplayer/servers/jellyfin_source.dart';
import 'package:mplayer/servers/server_registry.dart';

/// A Jellyfin that answers the probe and Quick Connect, and never approves.
class _Server implements HttpClientAdapter {
  _Server({required this.quickConnect});

  final bool quickConnect;
  final List<String> paths = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.uri.path);
    final Object body = switch (options.uri.path) {
      '/System/Info/Public' => <String, dynamic>{
          'ServerName': 'Living room',
          'Version': '10.10.7',
          'Id': 'srv',
          'ProductName': 'Jellyfin Server',
        },
      '/QuickConnect/Enabled' => quickConnect,
      '/QuickConnect/Initiate' => <String, dynamic>{
          'Code': '123456',
          'Secret': 'sec',
        },
      '/QuickConnect/Connect' => <String, dynamic>{'Authenticated': false},
      _ => <String, dynamic>{},
    };
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// No servers yet, and sign-in through [server] instead of the network.
class _EmptyRegistry extends ServerRegistry {
  _EmptyRegistry(this.server);

  final _Server server;

  @override
  ServerRegistryState build() => const ServerRegistryState(loading: false);

  @override
  Future<JellyfinAuth> auth() async => JellyfinAuth(
        identity: const ClientIdentity(deviceId: 'dev', deviceName: 'Test'),
        client: Dio(BaseOptions(validateStatus: (_) => true))
          ..httpClientAdapter = server,
      );
}

Future<void> _openSheet(WidgetTester tester, _Server server) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(400, 1000);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        serverRegistryProvider.overrideWith(() => _EmptyRegistry(server)),
      ],
      child: const MPlayerApp(),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.text('Add Jellyfin server'));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.widgetWithText(TextField, 'Server address'),
    'media.home.lan',
  );
  // Past the probe's debounce.
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a code is shown, counted down, and can be backed out of',
      (tester) async {
    final server = _Server(quickConnect: true);
    await _openSheet(tester, server);

    await tester.tap(find.text('Quick Connect'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Get a code'));
    // Not pumpAndSettle: the countdown redraws every second while waiting.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('123456'), findsOneWidget);
    expect(find.textContaining('Waiting for approval'), findsOneWidget);
    expect(find.byTooltip('Copy code'), findsOneWidget);
    expect(server.paths, contains('/QuickConnect/Connect'));

    // Cancel goes back to the form, not out of the sheet.
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pump();
    expect(find.text('123456'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Get a code'), findsOneWidget);

    // And the abandoned code is not asked about again.
    final asked = server.paths.where((p) => p == '/QuickConnect/Connect').length;
    await tester.pump(const Duration(seconds: 10));
    expect(
      server.paths.where((p) => p == '/QuickConnect/Connect').length,
      asked,
    );
  });

  testWidgets('a server with it switched off says so rather than hiding it',
      (tester) async {
    await _openSheet(tester, _Server(quickConnect: false));

    final segment = find.ancestor(
      of: find.text('Quick Connect'),
      matching: find.byType(SegmentedButton<bool>),
    );
    expect(segment, findsOneWidget);
    expect(find.textContaining('turned off on this server'), findsOneWidget);

    // Greyed, so a tap leaves the password form where it is.
    await tester.tap(find.text('Quick Connect'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Password'), findsOneWidget);
  });
}
