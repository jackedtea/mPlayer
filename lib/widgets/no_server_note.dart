// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/tokens.dart';
import '../l10n/app_localizations.dart';

/// What a tab shows while Home is still asking which server to open.
class NoServerNote extends StatelessWidget {
  const NoServerNote({super.key});

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final scheme = context.colors;
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Padding(
        padding: EdgeInsets.all(spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.dns_outlined, size: 40, color: scheme.onSurfaceVariant),
            SizedBox(height: spacing.md),
            Text(
              l10n.chooseServerFirst,
              textAlign: TextAlign.center,
              style: context.texts.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            SizedBox(height: spacing.lg),
            FilledButton.tonal(
              onPressed: () => context.go('/home'),
              child: Text(l10n.navHome),
            ),
          ],
        ),
      ),
    );
  }
}
