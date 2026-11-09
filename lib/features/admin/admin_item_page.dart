// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../servers/server_admin.dart';
import 'admin_providers.dart';
import 'admin_widgets.dart';

/// Edits one item's title, year, overview, certificate, genres and tags.
///
/// A page rather than a dialog: the overview is paragraphs long and the
/// keyboard takes half a phone, which leaves a dialog no room for both.
/// Like the account editor it is a draft — one whole-item write on Save —
/// and it pops with `true` once something was saved, so the screen it came
/// from knows to ask the server again.
class AdminItemPage extends ConsumerStatefulWidget {
  const AdminItemPage({super.key, required this.itemId, this.title = ''});

  final String itemId;

  /// What the opener called it, for the app bar before the item loads.
  final String title;

  @override
  ConsumerState<AdminItemPage> createState() => _AdminItemPageState();
}

class _AdminItemPageState extends ConsumerState<AdminItemPage> {
  ItemMetadata? _source;
  bool _saving = false;

  final _name = TextEditingController();
  final _originalTitle = TextEditingController();
  final _sortName = TextEditingController();
  final _year = TextEditingController();
  final _overview = TextEditingController();
  final _rating = TextEditingController();
  final _genres = TextEditingController();
  final _tags = TextEditingController();
  bool _locked = false;

  List<TextEditingController> get _fields => <TextEditingController>[
    _name,
    _originalTitle,
    _sortName,
    _year,
    _overview,
    _rating,
    _genres,
    _tags,
  ];

  @override
  void initState() {
    super.initState();
    // Listened, not read in build: filling the controllers notifies the
    // fields, which may not rebuild while this widget is building.
    ref.listenManual<AsyncValue<ItemMetadata?>>(
      adminItemMetadataProvider(widget.itemId),
      (_, next) {
        final loaded = next.value;
        if (loaded == null || identical(loaded, _source) || !mounted) return;
        setState(() => _load(loaded));
      },
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    for (final TextEditingController c in _fields) {
      c.dispose();
    }
    super.dispose();
  }

  void _load(ItemMetadata m) {
    _source = m;
    _name.text = m.name;
    _originalTitle.text = m.originalTitle;
    _sortName.text = m.sortName;
    _year.text = m.year?.toString() ?? '';
    _overview.text = m.overview;
    _rating.text = m.officialRating;
    _genres.text = m.genres.join(', ');
    _tags.text = m.tags.join(', ');
    _locked = m.locked;
  }

  /// The form as metadata. Genres and tags are typed comma-separated: one
  /// field each is what a phone keyboard can do in one pass, where a chip
  /// editor would be a tap per value.
  ItemMetadata get _draft => ItemMetadata(
    name: _name.text.trim(),
    originalTitle: _originalTitle.text.trim(),
    sortName: _sortName.text.trim(),
    year: int.tryParse(_year.text.trim()),
    overview: _overview.text.trim(),
    officialRating: _rating.text.trim(),
    genres: splitList(_genres.text),
    tags: splitList(_tags.text),
    locked: _locked,
  );

  bool get _dirty => _source != null && _draft != _source;

  /// A year the field holds that is not one: refused rather than silently
  /// saved as "no year".
  bool get _yearInvalid {
    final text = _year.text.trim();
    if (text.isEmpty) return false;
    final year = int.tryParse(text);
    return year == null || year < 1800 || year > 2200;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final metadata = ref.watch(adminItemMetadataProvider(widget.itemId));

    final title = _source?.name ?? widget.title;

    return PopScope(
      canPop: !_dirty,
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
        setState(() => _load(_source!));
        navigator.pop();
      },
      child: AdminScaffold(
        title: title.isEmpty ? l10n.adminEditMetadata : title,
        onRefresh: () async {
          ref.invalidate(adminItemMetadataProvider(widget.itemId));
          await ref.read(adminItemMetadataProvider(widget.itemId).future);
        },
        bottomBar: _source == null ? null : _saveBar(context, l10n),
        child: switch (metadata) {
          AsyncError(:final error) => AdminList(
            emptyText: '$error',
            children: const <Widget>[],
          ),
          _ when _source == null => AdminList(
            loading: metadata.isLoading,
            emptyText: l10n.adminItemNotFound,
            children: const <Widget>[],
          ),
          _ => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: spacing.screenHorizontal(context.windowSize),
              vertical: spacing.md,
            ),
            children: <Widget>[
              _field(_name, l10n.adminFieldTitle),
              _field(_originalTitle, l10n.adminFieldOriginalTitle),
              _field(
                _sortName,
                l10n.adminFieldSortName,
                helper: l10n.adminFieldSortNameHint,
              ),
              _field(
                _year,
                l10n.adminFieldYear,
                keyboard: TextInputType.number,
                error: _yearInvalid ? l10n.adminFieldYearInvalid : null,
              ),
              _field(_rating, l10n.adminFieldRating),
              _field(_overview, l10n.adminFieldOverview, lines: 6),
              _field(
                _genres,
                l10n.adminFieldGenres,
                helper: l10n.adminFieldListHint,
              ),
              _field(
                _tags,
                l10n.adminFieldTags,
                helper: l10n.adminFieldListHint,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.adminFieldLock),
                subtitle: Text(l10n.adminFieldLockBody),
                value: _locked,
                onChanged: (v) => setState(() => _locked = v),
              ),
            ],
          ),
        },
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    String? helper,
    String? error,
    int lines = 1,
    TextInputType? keyboard,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.spacing.md),
      child: TextField(
        controller: controller,
        minLines: lines == 1 ? 1 : 3,
        maxLines: lines,
        keyboardType:
            keyboard ??
            (lines > 1 ? TextInputType.multiline : TextInputType.text),
        decoration: InputDecoration(
          labelText: label,
          helperText: helper,
          errorText: error,
          border: const OutlineInputBorder(),
        ),
        // Every keystroke can change whether there is anything to save.
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _saveBar(BuildContext context, AppLocalizations l10n) {
    final spacing = context.spacing;
    final canSave =
        _dirty && !_saving && !_yearInvalid && _name.text.trim().isNotEmpty;

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
                  onPressed: _dirty && !_saving
                      ? () => setState(() => _load(_source!))
                      : null,
                  child: Text(l10n.actionCancel),
                ),
              ),
              SizedBox(width: spacing.md),
              Expanded(
                child: FilledButton(
                  onPressed: canSave ? _save : null,
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

  Future<void> _save() async {
    final draft = _draft;
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    setState(() => _saving = true);

    final saved = await runAdminAction(
      context,
      ref,
      action: (admin) => admin.setItemMetadata(widget.itemId, draft),
      success: l10n.adminMetadataSaved(draft.name),
    );

    if (!mounted) return;
    setState(() => _saving = false);
    if (!saved) return;
    // What was saved is now the server's copy; nothing is left to discard.
    _source = draft;
    navigator.pop(true);
  }
}

/// "Drama, Science Fiction ,, Thriller" → three genres, no blanks, no repeats.
List<String> splitList(String text) {
  final seen = <String>{};
  return <String>[
    for (final String part in text.split(','))
      if (part.trim() case final String v
          when v.isNotEmpty && seen.add(v.toLowerCase()))
        v,
  ];
}
