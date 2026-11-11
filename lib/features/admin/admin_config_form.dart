// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

/// A page of server settings, described rather than hand-built.
///
/// Every settings page under Libraries and Playback is the same thing — some
/// fields of a configuration object, a draft, one Save — so each is a list of
/// [ConfigField]s and this file draws and saves all of them. A page adding a
/// field adds a line, not a widget and a save path.
///
/// What is saved is **only what was changed**, laid over the configuration
/// read fresh at that moment (`updateConfiguration`). The objects behind these
/// pages hold dozens of fields this app never shows, and every one of them
/// survives a save from here.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../servers/server_admin.dart';
import '../../widgets/section_header.dart';
import 'admin_folder_picker.dart';
import 'admin_providers.dart';
import 'admin_widgets.dart';

/// Where a field lives: a named configuration ([key], null for the main one)
/// and the path of keys down to it.
@immutable
class ConfigPath {
  const ConfigPath(this.path, {this.key});

  final String? key;
  final List<String> path;

  Object? readFrom(Map<String, dynamic> config) {
    Object? at = config;
    for (final String k in path) {
      if (at is! Map) return null;
      at = at[k];
    }
    return at;
  }

  @override
  bool operator ==(Object other) =>
      other is ConfigPath &&
      other.key == key &&
      other.path.join('.') == path.join('.');

  @override
  int get hashCode => Object.hash(key, path.join('.'));
}

/// One setting on a page.
sealed class ConfigField {
  const ConfigField({required this.at, required this.label, this.help});

  final ConfigPath at;
  final String label;
  final String? help;
}

class SwitchConfig extends ConfigField {
  const SwitchConfig({required super.at, required super.label, super.help});
}

/// A whole number, typed, kept within [min]..[max].
class NumberConfig extends ConfigField {
  const NumberConfig({
    required super.at,
    required super.label,
    super.help,
    this.min,
    this.max,
    this.unit = '',
  });

  final int? min;
  final int? max;

  /// Drawn after the value: "%", "s", "ms".
  final String unit;
}

/// One of a fixed list. The value stored is [ConfigOption.value]; a server
/// holding a value not in the list keeps it, shown as it is.
class ChoiceConfig extends ConfigField {
  const ChoiceConfig({
    required super.at,
    required super.label,
    super.help,
    this.options = const <ConfigOption>[],
    this.load,
    this.numeric = false,
    this.allowNone = false,
    this.noneLabel = '',
  });

  final List<ConfigOption> options;

  /// Options the server supplies (languages, accounts) instead of [options].
  final FutureProvider<List<ConfigOption>>? load;

  /// Store the value as an int rather than a string.
  final bool numeric;

  /// Offer "none", which writes null.
  final bool allowNone;
  final String noneLabel;
}

/// Any of a fixed list, stored as a list of strings.
class MultiChoiceConfig extends ConfigField {
  const MultiChoiceConfig({
    required super.at,
    required super.label,
    required this.options,
    super.help,
  });

  final List<ConfigOption> options;
}

/// Free text; or, typed comma-separated, a list of whole numbers
/// ([intList]) or of strings ([stringList]).
class TextConfig extends ConfigField {
  const TextConfig({
    required super.at,
    required super.label,
    super.help,
    this.intList = false,
    this.stringList = false,
  });

  final bool intList;
  final bool stringList;
}

/// A folder on the server's disk, picked by browsing it.
class FolderConfig extends ConfigField {
  const FolderConfig({required super.at, required super.label, super.help});
}

/// A heading and the fields under it.
@immutable
class ConfigSection {
  const ConfigSection(this.title, this.fields);

  final String? title;
  final List<ConfigField> fields;
}

/// A page of [sections], with Save at its foot.
class AdminConfigPage extends ConsumerStatefulWidget {
  const AdminConfigPage({
    super.key,
    required this.title,
    required this.sections,
    this.intro,
  });

  final String title;

  /// A sentence over the fields, for a page whose purpose is not obvious.
  final String? intro;
  final List<ConfigSection> Function(AppLocalizations l10n) sections;

  @override
  ConsumerState<AdminConfigPage> createState() => _AdminConfigPageState();
}

class _AdminConfigPageState extends ConsumerState<AdminConfigPage> {
  /// What was changed and not yet saved.
  final Map<ConfigPath, Object?> _draft = <ConfigPath, Object?>{};
  bool _saving = false;

  Set<String> _keys(List<ConfigSection> sections) => <String>{
    for (final ConfigSection s in sections)
      for (final ConfigField f in s.fields) f.at.key ?? '',
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final sections = widget.sections(l10n);
    final keys = _keys(sections);

    final configs = <String, AsyncValue<Map<String, dynamic>?>>{
      for (final String k in keys) k: ref.watch(adminConfigProvider(k)),
    };
    final error = configs.values
        .map((c) => c.error)
        .firstWhere((e) => e != null, orElse: () => null);
    final loaded = configs.values.every((c) => c.value != null);

    Object? valueOf(ConfigField f) {
      if (_draft.containsKey(f.at)) return _draft[f.at];
      final config = configs[f.at.key ?? '']?.value;
      return config == null ? null : f.at.readFrom(config);
    }

    void set(ConfigField f, Object? value) => setState(() {
      final config = configs[f.at.key ?? '']?.value;
      final original = config == null ? null : f.at.readFrom(config);
      if (_sameValue(original, value)) {
        _draft.remove(f.at);
      } else {
        _draft[f.at] = value;
      }
    });

    final dirty = _draft.isNotEmpty;

    return PopScope(
      canPop: !dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        final leave = await confirmAdminAction(
          context,
          title: l10n.adminDiscardQuestion,
          body: l10n.adminDiscardBody,
          confirmLabel: l10n.adminDiscard,
        );
        if (!leave || !mounted) return;
        setState(_draft.clear);
        navigator.pop();
      },
      child: AdminScaffold(
        title: widget.title,
        onRefresh: () async {
          for (final String k in keys) {
            ref.invalidate(adminConfigProvider(k));
          }
          setState(_draft.clear);
        },
        bottomBar: loaded ? _saveBar(context, l10n, keys) : null,
        child: switch ((error, loaded)) {
          (final Object e?, _) => AdminList(
            emptyText: '$e',
            children: const <Widget>[],
          ),
          (_, false) => const Center(child: CircularProgressIndicator()),
          _ => AdminList(
            children: <Widget>[
              if (widget.intro case final String intro)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    spacing.screenHorizontal(context.windowSize),
                    spacing.md,
                    spacing.screenHorizontal(context.windowSize),
                    spacing.sm,
                  ),
                  child: Text(
                    intro,
                    style: context.texts.bodyMedium?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ),
              for (final ConfigSection section in sections) ...<Widget>[
                if (section.title case final String t) SectionHeader(title: t),
                for (final ConfigField f in section.fields)
                  _ConfigRow(
                    field: f,
                    value: valueOf(f),
                    changed: _draft.containsKey(f.at),
                    onChanged: (v) => set(f, v),
                  ),
                SizedBox(height: spacing.md),
              ],
            ],
          ),
        },
      ),
    );
  }

  Widget _saveBar(
    BuildContext context,
    AppLocalizations l10n,
    Set<String> keys,
  ) {
    final spacing = context.spacing;
    final dirty = _draft.isNotEmpty;

    return Material(
      color: context.colors.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: spacing.screenHorizontal(context.windowSize),
            vertical: spacing.sm,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: dirty && !_saving
                      ? () => setState(_draft.clear)
                      : null,
                  child: Text(l10n.actionCancel),
                ),
              ),
              SizedBox(width: spacing.md),
              Expanded(
                child: FilledButton(
                  onPressed: dirty && !_saving ? () => _save(keys) : null,
                  child: _saving
                      ? SizedBox.square(
                          dimension: spacing.lg,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : Text(l10n.actionSave),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save(Set<String> keys) async {
    final l10n = AppLocalizations.of(context);
    final changes = changesByKey(_draft);
    setState(() => _saving = true);

    final saved = await runAdminAction(
      context,
      ref,
      action: (admin) async {
        for (final MapEntry<String?, Map<String, dynamic>> c
            in changes.entries) {
          await admin.updateConfiguration(c.value, c.key);
        }
      },
      success: l10n.adminSettingsSaved,
      refresh: () {
        for (final String k in keys) {
          ref.invalidate(adminConfigProvider(k));
        }
        // A setting can change what the server says about itself — a
        // pending restart, for one.
        ref.invalidate(systemInfoProvider);
      },
    );

    if (!mounted) return;
    setState(() {
      _saving = false;
      if (saved) _draft.clear();
    });
  }
}

/// The draft as one nested change map per configuration key.
Map<String?, Map<String, dynamic>> changesByKey(
  Map<ConfigPath, Object?> draft,
) {
  final out = <String?, Map<String, dynamic>>{};
  for (final MapEntry<ConfigPath, Object?> e in draft.entries) {
    var at = out.putIfAbsent(e.key.key, () => <String, dynamic>{});
    final path = e.key.path;
    for (final String k in path.take(path.length - 1)) {
      at = (at[k] ??= <String, dynamic>{}) as Map<String, dynamic>;
    }
    at[path.last] = e.value;
  }
  return out;
}

bool _sameValue(Object? a, Object? b) {
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if ('${a[i]}' != '${b[i]}') return false;
    }
    return true;
  }
  if (a is num && b is num) return a == b;
  return a == b;
}

class _ConfigRow extends ConsumerWidget {
  const _ConfigRow({
    required this.field,
    required this.value,
    required this.changed,
    required this.onChanged,
  });

  final ConfigField field;
  final Object? value;

  /// Changed since the page loaded: the label is marked, so a reader can see
  /// what Save is about to write.
  final bool changed;
  final ValueChanged<Object?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = context.colors;
    final title = Text(
      field.label,
      style: changed
          ? TextStyle(color: scheme.primary, fontWeight: FontWeight.w600)
          : null,
    );
    final help = field.help;

    Widget tile(String shown, VoidCallback onTap) => ListTile(
      title: title,
      subtitle: Text(
        help == null ? shown : '$shown\n$help',
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.edit_outlined),
      onTap: onTap,
    );

    return switch (field) {
      SwitchConfig() => SwitchListTile(
        title: title,
        subtitle: help == null ? null : Text(help),
        value: value == true,
        onChanged: onChanged,
      ),
      final NumberConfig f => tile(
        value == null ? '—' : '$value${f.unit}',
        () async {
          final picked = await _askNumber(context, f, value);
          if (picked != null) onChanged(picked);
        },
      ),
      final ChoiceConfig f => _choiceTile(context, ref, f, title, l10n),
      final MultiChoiceConfig f => tile(
        _listOf(value).isEmpty
            ? l10n.adminNoneSelected
            : <String>[
                for (final String v in _listOf(value))
                  f.options.where((o) => o.value == v).firstOrNull?.label ?? v,
              ].join(', '),
        () async {
          final picked = await showDialog<List<String>>(
            context: context,
            builder: (_) => _MultiChoiceDialog(
              title: f.label,
              options: f.options,
              selected: _listOf(value),
            ),
          );
          if (picked != null) onChanged(picked);
        },
      ),
      final TextConfig f => tile(
        _textOf(value).isEmpty ? '—' : _textOf(value),
        () async {
          final typed = await showDialog<String>(
            context: context,
            builder: (_) => _TextDialog(
              title: f.label,
              initial: _textOf(value),
              numbers: f.intList,
            ),
          );
          if (typed == null) return;
          onChanged(
            f.intList
                ? <int>[
                    for (final String p in typed.split(','))
                      if (int.tryParse(p.trim()) case final int n) n,
                  ]
                : f.stringList
                ? <String>[
                    for (final String p in typed.split(','))
                      if (p.trim().isNotEmpty) p.trim(),
                  ]
                : typed.trim(),
          );
        },
      ),
      FolderConfig() => tile(
        _textOf(value).isEmpty ? l10n.adminFolderDefault : _textOf(value),
        () async {
          final path = await pickServerFolder(context);
          if (path != null) onChanged(path);
        },
      ),
    };
  }

  Widget _choiceTile(
    BuildContext context,
    WidgetRef ref,
    ChoiceConfig f,
    Widget title,
    AppLocalizations l10n,
  ) {
    final loader = f.load;
    final options = loader == null
        ? f.options
        : ref.watch(loader).value ?? const <ConfigOption>[];
    final current = value == null ? null : '$value';
    final shown = current == null || current.isEmpty
        ? (f.allowNone ? f.noneLabel : '—')
        : options.where((o) => o.value == current).firstOrNull?.label ??
              current;

    return ListTile(
      title: title,
      subtitle: Text(
        f.help == null ? shown : '$shown\n${f.help}',
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.arrow_drop_down_rounded),
      onTap: () async {
        final picked = await showDialog<_Picked>(
          context: context,
          builder: (dialogContext) => SimpleDialog(
            title: Text(f.label),
            children: <Widget>[
              if (f.allowNone)
                _option(dialogContext, f.noneLabel, null, current == null),
              for (final ConfigOption o in options)
                _option(
                  dialogContext,
                  o.label,
                  f.numeric ? int.tryParse(o.value) : o.value,
                  o.value == current,
                ),
            ],
          ),
        );
        if (picked != null) onChanged(picked.value);
      },
    );
  }

  Widget _option(
    BuildContext context,
    String label,
    Object? value,
    bool selected,
  ) {
    return SimpleDialogOption(
      onPressed: () => Navigator.of(context).pop(_Picked(value)),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label)),
          if (selected)
            Icon(Icons.check_rounded, color: context.colors.primary),
        ],
      ),
    );
  }

  static List<String> _listOf(Object? v) =>
      v is List ? <String>[for (final Object? e in v) '$e'] : const <String>[];

  static String _textOf(Object? v) => switch (v) {
    null => '',
    final List<Object?> l => l.join(', '),
    _ => '$v',
  };

  Future<int?> _askNumber(
    BuildContext context,
    NumberConfig f,
    Object? value,
  ) async {
    final typed = await showDialog<String>(
      context: context,
      builder: (_) => _TextDialog(
        title: f.label,
        initial: value == null ? '' : '$value',
        numbers: true,
        min: f.min,
        max: f.max,
      ),
    );
    return typed == null ? null : int.tryParse(typed.trim());
  }
}

/// Wraps a pick so that choosing "none" is told apart from dismissing.
class _Picked {
  const _Picked(this.value);
  final Object? value;
}

class _TextDialog extends StatefulWidget {
  const _TextDialog({
    required this.title,
    required this.initial,
    this.numbers = false,
    this.min,
    this.max,
  });

  final String title;
  final String initial;
  final bool numbers;
  final int? min;
  final int? max;

  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  late final TextEditingController _text = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  /// A sentence when the typed number is out of range, else null.
  String? _problem(AppLocalizations l10n) {
    final min = widget.min;
    final max = widget.max;
    if (min == null && max == null) return null;
    final n = int.tryParse(_text.text.trim());
    if (n == null) return l10n.adminNotANumber;
    if ((min != null && n < min) || (max != null && n > max)) {
      return l10n.adminNumberRange(min ?? 0, max ?? n);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final problem = _problem(l10n);

    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _text,
        autofocus: true,
        keyboardType: widget.numbers && widget.min != null
            ? TextInputType.number
            : TextInputType.text,
        decoration: InputDecoration(errorText: problem),
        onChanged: (_) => setState(() {}),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: problem != null
              ? null
              : () => Navigator.of(context).pop(_text.text),
          child: Text(l10n.actionSave),
        ),
      ],
    );
  }
}

class _MultiChoiceDialog extends StatefulWidget {
  const _MultiChoiceDialog({
    required this.title,
    required this.options,
    required this.selected,
  });

  final String title;
  final List<ConfigOption> options;
  final List<String> selected;

  @override
  State<_MultiChoiceDialog> createState() => _MultiChoiceDialogState();
}

class _MultiChoiceDialogState extends State<_MultiChoiceDialog> {
  late final Set<String> _picked = <String>{...widget.selected};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      contentPadding: EdgeInsets.symmetric(vertical: context.spacing.md),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final ConfigOption o in widget.options)
              CheckboxListTile(
                title: Text(o.label),
                value: _picked.contains(o.value),
                onChanged: (v) => setState(() {
                  if (v ?? false) {
                    _picked.add(o.value);
                  } else {
                    _picked.remove(o.value);
                  }
                }),
              ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          // In the options' own order, not the order they were ticked.
          onPressed: () => Navigator.of(context).pop(<String>[
            for (final ConfigOption o in widget.options)
              if (_picked.contains(o.value)) o.value,
          ]),
          child: Text(l10n.actionSave),
        ),
      ],
    );
  }
}
