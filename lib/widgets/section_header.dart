// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';

import '../app/tokens.dart';

/// Section label in primary at titleSmall (14/20, +0.1 tracking), with an
/// optional trailing text action — "Continue watching", "Network · Add".
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.trailing,
    this.bottomPadding,
  }) : assert(
          actionLabel == null || trailing == null,
          'A header carries one action, not two.',
        );

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Replaces the text action when the action is worth keeping but not worth
  /// a word — Continue watching demotes "Clear" to an icon so it stops
  /// competing with the "Add" links further down the screen.
  final Widget? trailing;

  final double? bottomPadding;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final style = context.texts.titleSmall?.copyWith(color: context.colors.primary);
    final hasAction = actionLabel != null || trailing != null;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        spacing.screenHorizontal(context.windowSize),
        0,
        hasAction ? spacing.sm : spacing.screenHorizontal(context.windowSize),
        bottomPadding ?? spacing.sm,
      ),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(title, style: style)),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
          ?trailing,
        ],
      ),
    );
  }
}
