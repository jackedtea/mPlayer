// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mplayer/app/theme.dart';
import 'package:mplayer/app/tokens.dart';
import 'package:mplayer/core/models/library_models.dart';
import 'package:mplayer/widgets/gradient_art.dart';
import 'package:mplayer/widgets/poster_tile.dart';

/// Every poster in a grid row has to be the same size.
///
/// The artwork is `Expanded`, so it takes whatever the caption below it does
/// not. A caption left to size itself took one line for a short title and two
/// for a long one, and the poster above grew or shrank to match — so a row
/// with "Date A Live" beside "Easygoing Territory Defense by the Optimistic
/// Lord" came out at two different sizes.
void main() {
  // Genuinely one line at 108pt — "Date A Live" is not, which is how the
  // first version of this test passed against the bug it was written for.
  const short = LibraryItem(id: 'a', title: 'Coco', year: '2017');
  const long = LibraryItem(
    id: 'b',
    title: 'Easygoing Territory Defense by the Optimistic Lord',
    year: '2024',
  );

  testWidgets('a one-line title and a two-line title give the same poster',
      (tester) async {
    late double cellHeight;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.dark),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              cellHeight = PosterTile.outerHeight(context, 142);
              return Row(
                children: <Widget>[
                  for (final LibraryItem item in <LibraryItem>[short, long])
                    SizedBox(
                      width: PosterTile.outerWidth(context, 108),
                      height: cellHeight,
                      child: PosterTile(
                        item: item,
                        width: 108,
                        posterHeight: 142,
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );

    final posters = tester
        .renderObjectList<RenderBox>(find.byType(GradientArt))
        .map((box) => box.size.height)
        .toList();

    expect(posters, hasLength(2));
    expect(
      posters.first,
      posters.last,
      reason: 'the short title left its poster taller than the long one — '
          'measured 158 against 142 when this was broken',
    );
  });

  testWidgets('the reserved caption is the gap plus its lines', (tester) async {
    // `outerHeight` is what a grid passes as `mainAxisExtent`, so it and the
    // box the caption actually occupies have to be derived from one number or
    // the tile overflows by the difference.
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.dark),
        home: Builder(
          builder: (context) {
            expect(
              PosterTile.captionHeight(context, lines: 2),
              PosterTile.titleHeight(context, lines: 2) +
                  context.spacing.sm -
                  2,
            );
            // Two lines is exactly twice one.
            expect(
              PosterTile.titleHeight(context, lines: 2),
              PosterTile.titleHeight(context, lines: 1) * 2,
            );
            return const SizedBox();
          },
        ),
      ),
    );
  });
}
