import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mplayer/app/app.dart';
import 'package:mplayer/app/theme.dart';

void main() {
  testWidgets('app renders a Material shell inside a ProviderScope', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MPlayerApp(home: Scaffold(body: Text('home'))),
      ),
    );

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('home'), findsOneWidget);
  });

  test('theme derives a light and dark scheme from the same seed', () {
    expect(buildTheme(Brightness.light).colorScheme.brightness,
        Brightness.light);
    expect(buildTheme(Brightness.dark).colorScheme.brightness, Brightness.dark);
  });
}
