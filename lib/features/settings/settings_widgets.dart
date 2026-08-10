// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/tokens.dart';

/// Scaffold shared by every settings sub-page, so they cannot drift apart.
class SettingsScaffold extends StatelessWidget {
  const SettingsScaffold({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(title),
      ),
      body: ListView(
        padding: EdgeInsets.only(bottom: context.spacing.xl),
        children: children,
      ),
    );
  }
}

/// Group label in primary, above a run of related rows.
class SettingsSection extends StatelessWidget {
  const SettingsSection({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        spacing.screenHorizontal(context.windowSize),
        spacing.xl,
        spacing.screenHorizontal(context.windowSize),
        spacing.sm,
      ),
      child: Text(
        title,
        style: context.texts.titleSmall?.copyWith(color: context.colors.primary),
      ),
    );
  }
}

/// A row whose value opens a picker. Value sits on the right, muted.
class SettingsValueRow extends StatelessWidget {
  const SettingsValueRow({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    this.onTap,
  });

  final String title;
  final String value;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: context.spacing.screenPadding(context.windowSize),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: Text(
        value,
        style: context.texts.bodyMedium
            ?.copyWith(color: context.colors.onSurfaceVariant),
      ),
      onTap: onTap ?? () => notImplemented(context, title),
    );
  }
}

/// A row that toggles. Uses [SwitchListTile] rather than a hand-rolled switch.
class SettingsSwitchRow extends StatelessWidget {
  const SettingsSwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: context.spacing.screenPadding(context.windowSize),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      value: value,
      onChanged: onChanged,
    );
  }
}

/// Labelled slider row — streaming caps, subtitle size, background opacity.
class SettingsSliderRow extends StatelessWidget {
  const SettingsSliderRow({
    super.key,
    required this.title,
    required this.valueLabel,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.divisions,
  });

  final String title;
  final String valueLabel;
  final double value;
  final ValueChanged<double> onChanged;
  final double min;
  final double max;
  final int? divisions;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final padding = spacing.screenHorizontal(context.windowSize);

    return Padding(
      padding: EdgeInsets.fromLTRB(padding, spacing.sm, padding, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Text(title, style: context.texts.bodyLarge)),
              Text(
                valueLabel,
                style: context.texts.bodyMedium
                    ?.copyWith(color: context.colors.onSurfaceVariant),
              ),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

void notImplemented(BuildContext context, String what) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('$what — not implemented yet')),
  );
}
