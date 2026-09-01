// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

/// The two sheets behind the library grid's chips: what it is ordered by, and
/// what it is leaving out.
///
/// The filter sheet is a **draft**. Nothing is applied while it is open — the
/// grid behind it does not refetch on every checkbox, which on a large
/// library would be a request per tap and a screen rearranging itself under a
/// sheet the user is still reading. It answers with the whole choice, or with
/// null for a dismissal.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../servers/media_library_source.dart';
import 'server_library.dart';

/// What a library grid is ordered by, as one value a sheet can answer with.
///
/// The field and the direction travel together because they are chosen
/// together: answering with a field alone would leave the caller guessing
/// whether the direction beside it had also been touched.
@immutable
class LibraryOrdering {
  const LibraryOrdering(this.sort, [this.order]);

  final ServerSort sort;

  /// Null while the user has not chosen — the sort's own natural direction
  /// then stands, which is what makes "Recently added" newest first without
  /// anybody having said so.
  final SortOrder? order;

  SortOrder get effectiveOrder => order ?? sort.naturalOrder;

  @override
  bool operator ==(Object other) =>
      other is LibraryOrdering && other.sort == sort && other.order == order;

  @override
  int get hashCode => Object.hash(sort, order);
}

/// The sorts on offer in a library of [collectionKind].
///
/// All of them except the episode one, which is about a series' newest
/// episode and says nothing about a film. An entry that cannot mean anything
/// where it is shown is an entry nobody wanted.
List<ServerSort> sortsFor(String collectionKind) {
  return <ServerSort>[
    for (final ServerSort sort in ServerSort.values)
      if (sort != ServerSort.dateEpisodeAdded || collectionKind == 'tvshows')
        sort,
  ];
}

String sortLabel(ServerSort sort, AppLocalizations l10n) {
  return switch (sort) {
    ServerSort.name => l10n.sortName,
    ServerSort.random => l10n.sortRandom,
    ServerSort.communityRating => l10n.sortCommunityRating,
    ServerSort.dateAdded => l10n.sortDateAdded,
    ServerSort.dateEpisodeAdded => l10n.sortEpisodeAdded,
    ServerSort.datePlayed => l10n.sortDatePlayed,
    ServerSort.parentalRating => l10n.sortParentalRating,
    ServerSort.releaseDate => l10n.sortReleaseDate,
  };
}

/// Asks what to order the grid by. Null means the sheet was dismissed.
Future<LibraryOrdering?> showLibrarySortSheet(
  BuildContext context, {
  required LibraryOrdering current,
  required String collectionKind,
}) {
  return showModalBottomSheet<LibraryOrdering>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (_) => _SortSheet(current: current, collectionKind: collectionKind),
  );
}

class _SortSheet extends StatelessWidget {
  const _SortSheet({required this.current, required this.collectionKind});

  final LibraryOrdering current;
  final String collectionKind;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;

    // Each tap applies and closes, the way the sort menu already did. There
    // is no draft to keep: two radio groups have nothing to reconcile, and an
    // Apply button under them is a second tap for a decision already made.
    void choose(LibraryOrdering next) => Navigator.of(context).pop(next);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: EdgeInsets.only(bottom: spacing.xl),
          children: <Widget>[
            _SheetHeading(text: l10n.sortBy),
            // RadioGroup owns the selection; the per-tile groupValue and
            // onChanged pair is deprecated.
            RadioGroup<ServerSort>(
              groupValue: current.sort,
              // The direction carries over rather than resetting to the new
              // sort's natural one: a user who chose Descending meant it, and
              // having it flip back under them reads as the app forgetting.
              onChanged: (v) =>
                  choose(LibraryOrdering(v ?? current.sort, current.order)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (final ServerSort sort in sortsFor(collectionKind))
                    RadioListTile<ServerSort>(
                      value: sort,
                      title: Text(sortLabel(sort, l10n)),
                    ),
                ],
              ),
            ),
            const Divider(),
            _SheetHeading(text: l10n.sortOrder),
            RadioGroup<SortOrder>(
              // The effective one, not the stored null: the radio has to show
              // which way the grid is actually reading, and "neither" is not
              // one of the two answers.
              groupValue: current.effectiveOrder,
              onChanged: (v) => choose(LibraryOrdering(current.sort, v)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (final SortOrder order in SortOrder.values)
                    RadioListTile<SortOrder>(
                      value: order,
                      title: Text(
                        order == SortOrder.ascending
                            ? l10n.sortAscending
                            : l10n.sortDescending,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Asks what to leave out. Null means the sheet was dismissed unchanged.
Future<LibraryFilter?> showLibraryFilterSheet(
  BuildContext context, {
  required String viewId,
  required LibraryFilter current,
  required String collectionKind,
}) {
  return showModalBottomSheet<LibraryFilter>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (_) => _FilterSheet(
      viewId: viewId,
      current: current,
      collectionKind: collectionKind,
    ),
  );
}

class _FilterSheet extends ConsumerStatefulWidget {
  const _FilterSheet({
    required this.viewId,
    required this.current,
    required this.collectionKind,
  });

  final String viewId;
  final LibraryFilter current;
  final String collectionKind;

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  late LibraryFilter _draft = widget.current;

  void _edit(LibraryFilter next) => setState(() => _draft = next);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final scheme = context.colors;

    // What the library actually holds. The watch-state and feature sections
    // need nothing from the server, so they draw while this is still in
    // flight rather than behind a spinner covering the whole sheet.
    final request = ref.watch(libraryFilterOptionsProvider(widget.viewId));
    final options = request.value ?? LibraryFilterOptions.empty;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.only(bottom: spacing.md),
                children: <Widget>[
                  _Section(
                    title: l10n.filters,
                    // Open by default: this is where nearly every filtering
                    // starts, and a sheet whose every row is collapsed shows
                    // the user seven words and no controls.
                    initiallyExpanded: true,
                    selected: _draft.flags.length,
                    children: <Widget>[
                      for (final ItemFilter flag in ItemFilter.values)
                        CheckboxListTile(
                          value: _draft.flags.contains(flag),
                          title: Text(flagLabel(flag, l10n)),
                          onChanged: (on) => _edit(
                            _draft.copyWith(
                              flags: LibraryFilter.toggled(
                                _draft.flags,
                                flag,
                                on ?? false,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  // A film is neither continuing nor ended, so the section is
                  // absent rather than disabled outside a shows library.
                  if (widget.collectionKind == 'tvshows')
                    _Section(
                      title: l10n.filterStatus,
                      selected: _draft.status.length,
                      children: <Widget>[
                        for (final SeriesStatus status in SeriesStatus.values)
                          CheckboxListTile(
                            value: _draft.status.contains(status),
                            title: Text(_statusLabel(status, l10n)),
                            onChanged: (on) => _edit(
                              _draft.copyWith(
                                status: LibraryFilter.toggled(
                                  _draft.status,
                                  status,
                                  on ?? false,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  _Section(
                    title: l10n.filterFeatures,
                    selected: _draft.features.length,
                    children: <Widget>[
                      for (final ItemFeature feature in ItemFeature.values)
                        CheckboxListTile(
                          value: _draft.features.contains(feature),
                          title: Text(_featureLabel(feature, l10n)),
                          onChanged: (on) => _edit(
                            _draft.copyWith(
                              features: LibraryFilter.toggled(
                                _draft.features,
                                feature,
                                on ?? false,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  _ValueSection<String>(
                    title: l10n.filterGenres,
                    values: options.genres,
                    chosen: _draft.genres,
                    label: (v) => v,
                    onToggle: (value, on) => _edit(
                      _draft.copyWith(
                        genres: LibraryFilter.toggled(_draft.genres, value, on),
                      ),
                    ),
                  ),
                  _ValueSection<String>(
                    title: l10n.filterParentalRatings,
                    values: options.parentalRatings,
                    chosen: _draft.parentalRatings,
                    label: (v) => v,
                    onToggle: (value, on) => _edit(
                      _draft.copyWith(
                        parentalRatings: LibraryFilter.toggled(
                          _draft.parentalRatings,
                          value,
                          on,
                        ),
                      ),
                    ),
                  ),
                  _ValueSection<String>(
                    title: l10n.filterTags,
                    values: options.tags,
                    chosen: _draft.tags,
                    label: (v) => v,
                    onToggle: (value, on) => _edit(
                      _draft.copyWith(
                        tags: LibraryFilter.toggled(_draft.tags, value, on),
                      ),
                    ),
                  ),
                  _ValueSection<int>(
                    title: l10n.filterYears,
                    // Newest first: a library's recent years are the ones
                    // anybody opens a filter sheet to pick.
                    values: options.years.toList()
                      ..sort((a, b) => b.compareTo(a)),
                    chosen: _draft.years,
                    label: (v) => '$v',
                    onToggle: (value, on) => _edit(
                      _draft.copyWith(
                        years: LibraryFilter.toggled(_draft.years, value, on),
                      ),
                    ),
                  ),
                  // Said only once the request has settled: "nothing to filter
                  // by" while the lists are still in flight is wrong more
                  // often than it is right.
                  if (!request.isLoading && options.isEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: spacing.lg,
                        vertical: spacing.md,
                      ),
                      child: Text(
                        l10n.nothingToFilterBy,
                        style: context.texts.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: EdgeInsets.all(spacing.md),
              child: Row(
                children: <Widget>[
                  TextButton(
                    // Clears the draft rather than applying an empty filter,
                    // so a reset the user changes their mind about costs
                    // nothing but a dismissal.
                    onPressed: _draft.isEmpty
                        ? null
                        : () => _edit(LibraryFilter.none),
                    child: Text(l10n.filterReset),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(_draft),
                    child: Text(l10n.filterApply),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The wording for one watch-state filter.
///
/// Public because the chip row uses the same word the sheet does: the
/// Unwatched chip and the Unwatched checkbox are the same filter, and two
/// spellings of it would read as two different ones.
String flagLabel(ItemFilter flag, AppLocalizations l10n) {
  return switch (flag) {
    ItemFilter.played => l10n.filterPlayed,
    ItemFilter.unplayed => l10n.filterUnplayed,
    ItemFilter.favourite => l10n.filterFavourite,
    ItemFilter.resumable => l10n.filterInProgress,
  };
}

String _statusLabel(SeriesStatus status, AppLocalizations l10n) {
  return switch (status) {
    SeriesStatus.continuing => l10n.statusContinuing,
    SeriesStatus.ended => l10n.statusEnded,
  };
}

String _featureLabel(ItemFeature feature, AppLocalizations l10n) {
  return switch (feature) {
    ItemFeature.subtitles => l10n.subtitles,
    ItemFeature.trailer => l10n.featureTrailer,
    ItemFeature.specialFeature => l10n.featureExtras,
    ItemFeature.themeSong => l10n.featureThemeSong,
    ItemFeature.themeVideo => l10n.featureThemeVideo,
  };
}

/// One collapsible group of checkboxes.
///
/// The count in the heading is what makes a collapsed section honest: most of
/// them stay shut, and a shut section hiding three ticked boxes is the reason
/// a library looks half empty with nothing on screen saying why.
class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.children,
    this.selected = 0,
    this.initiallyExpanded = false,
  });

  final String title;
  final List<Widget> children;
  final int selected;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: Text(title),
      initiallyExpanded: initiallyExpanded,
      // Stock M3 draws a rounded outline around an expanded tile, which in a
      // stack of seven of them is seven boxes inside a box.
      shape: const Border(),
      collapsedShape: const Border(),
      trailing: selected == 0
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  '$selected',
                  style: context.texts.labelLarge
                      ?.copyWith(color: context.colors.primary),
                ),
                SizedBox(width: context.spacing.sm),
                const Icon(Icons.expand_more_rounded),
              ],
            ),
      children: children,
    );
  }
}

/// A section built from what the server said the library holds.
///
/// Absent when the server named nothing: an empty "Genres" heading over
/// nothing looks broken rather than honest about a library with no genres on
/// it, and a server that refused the request would draw four of them.
class _ValueSection<T> extends StatelessWidget {
  const _ValueSection({
    required this.title,
    required this.values,
    required this.chosen,
    required this.label,
    required this.onToggle,
  });

  final String title;
  final List<T> values;
  final Set<T> chosen;
  final String Function(T value) label;
  final void Function(T value, bool on) onToggle;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const SizedBox.shrink();

    return _Section(
      title: title,
      selected: chosen.length,
      children: <Widget>[
        for (final T value in values)
          CheckboxListTile(
            value: chosen.contains(value),
            title: Text(label(value)),
            onChanged: (on) => onToggle(value, on ?? false),
          ),
      ],
    );
  }
}

class _SheetHeading extends StatelessWidget {
  const _SheetHeading({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.spacing.lg,
        context.spacing.lg,
        context.spacing.lg,
        context.spacing.sm,
      ),
      child: Text(text, style: context.texts.titleSmall),
    );
  }
}
