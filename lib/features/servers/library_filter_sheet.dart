// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

/// The dialog behind the library grid's filter button: what the grid is
/// ordered by, and what it is leaving out.
///
/// It is a **draft**. Nothing is applied while it is open — the grid behind
/// it does not refetch on every chip, which on a large library would be a
/// request per tap and a screen rearranging itself under a dialog the user is
/// still reading. It answers with the whole choice, or with null for a
/// dismissal.
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

/// What the sort-and-filter dialog answers with.
typedef LibraryOptions = ({LibraryOrdering ordering, LibraryFilter filter});

/// Asks how to order the grid and what to leave out, in one dialog. Null
/// means it was dismissed, and nothing changes.
///
/// Full screen on a phone, where a dialog this tall would be a box with a
/// scroll bar in it; a centred dialog wherever there is room around one.
Future<LibraryOptions?> showLibraryOptionsDialog(
  BuildContext context, {
  required String? viewId,
  required LibraryOrdering ordering,
  required LibraryFilter filter,
  required String collectionKind,
}) {
  final compact = context.windowSize == WindowSize.compact;

  return showDialog<LibraryOptions>(
    context: context,
    builder: (_) {
      final body = _OptionsDialog(
        viewId: viewId,
        ordering: ordering,
        filter: filter,
        collectionKind: collectionKind,
      );
      if (compact) return Dialog.fullscreen(child: body);

      return Dialog(
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 560,
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: body,
        ),
      );
    },
  );
}

class _OptionsDialog extends ConsumerStatefulWidget {
  const _OptionsDialog({
    required this.viewId,
    required this.ordering,
    required this.filter,
    required this.collectionKind,
  });

  /// Null for a grid with no library behind it, which has sorts to offer but
  /// no filter values to read.
  final String? viewId;
  final LibraryOrdering ordering;
  final LibraryFilter filter;
  final String collectionKind;

  @override
  ConsumerState<_OptionsDialog> createState() => _OptionsDialogState();
}

class _OptionsDialogState extends ConsumerState<_OptionsDialog> {
  late LibraryOrdering _ordering = widget.ordering;
  late LibraryFilter _draft = widget.filter;

  void _edit(LibraryFilter next) => setState(() => _draft = next);

  static const _defaultOrdering = LibraryOrdering(ServerSort.name);

  bool get _isDefault => _draft.isEmpty && _ordering == _defaultOrdering;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final scheme = context.colors;

    // What the library actually holds. The sort, watch-state and feature
    // sections need nothing from the server, so they draw while this is
    // still in flight rather than behind a spinner covering everything.
    final viewId = widget.viewId;
    final request = viewId == null
        ? const AsyncValue<LibraryFilterOptions>.data(LibraryFilterOptions.empty)
        : ref.watch(libraryFilterOptionsProvider(viewId));
    final options = request.value ?? LibraryFilterOptions.empty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.fromLTRB(spacing.xs, spacing.sm, spacing.lg, 0),
          child: Row(
            children: <Widget>[
              IconButton(
                icon: const Icon(Icons.close_rounded),
                tooltip: l10n.cancel,
                onPressed: () => Navigator.of(context).pop(),
              ),
              SizedBox(width: spacing.xs),
              Expanded(
                child: Text(l10n.sortAndFilter, style: context.texts.titleLarge),
              ),
            ],
          ),
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: EdgeInsets.only(bottom: spacing.md),
            children: <Widget>[
              // ------------------------------------------------ sort
              _Heading(text: l10n.sortBy),
              _ChipWrap(
                children: <Widget>[
                  for (final ServerSort sort in sortsFor(widget.collectionKind))
                    ChoiceChip(
                      label: Text(sortLabel(sort, l10n)),
                      selected: _ordering.sort == sort,
                      // The direction carries over rather than resetting to
                      // the new sort's natural one: a user who chose
                      // Descending meant it.
                      onSelected: (_) => setState(
                        () => _ordering = LibraryOrdering(sort, _ordering.order),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  spacing.lg,
                  spacing.md,
                  spacing.lg,
                  0,
                ),
                child: SegmentedButton<SortOrder>(
                  segments: <ButtonSegment<SortOrder>>[
                    ButtonSegment<SortOrder>(
                      value: SortOrder.ascending,
                      icon: const Icon(Icons.arrow_upward_rounded),
                      label: Text(l10n.sortAscending),
                    ),
                    ButtonSegment<SortOrder>(
                      value: SortOrder.descending,
                      icon: const Icon(Icons.arrow_downward_rounded),
                      label: Text(l10n.sortDescending),
                    ),
                  ],
                  // The effective one, not the stored null: this has to show
                  // which way the grid is actually reading.
                  selected: <SortOrder>{_ordering.effectiveOrder},
                  onSelectionChanged: (v) => setState(
                    () => _ordering = LibraryOrdering(_ordering.sort, v.single),
                  ),
                ),
              ),
              SizedBox(height: spacing.md),
              const Divider(),

              // --------------------------------------------- filters
              _Heading(text: l10n.filters),
              _ChipWrap(
                children: <Widget>[
                  for (final ItemFilter flag in ItemFilter.values)
                    FilterChip(
                      label: Text(flagLabel(flag, l10n)),
                      selected: _draft.flags.contains(flag),
                      onSelected: (on) => _edit(
                        _draft.copyWith(
                          flags: LibraryFilter.toggled(_draft.flags, flag, on),
                        ),
                      ),
                    ),
                ],
              ),
              // A film is neither continuing nor ended, so the section is
              // absent rather than disabled outside a shows library.
              if (widget.collectionKind == 'tvshows') ...<Widget>[
                _Heading(text: l10n.filterStatus),
                _ChipWrap(
                  children: <Widget>[
                    for (final SeriesStatus status in SeriesStatus.values)
                      FilterChip(
                        label: Text(statusLabel(status, l10n)),
                        selected: _draft.status.contains(status),
                        onSelected: (on) => _edit(
                          _draft.copyWith(
                            status:
                                LibraryFilter.toggled(_draft.status, status, on),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              _Heading(text: l10n.filterFeatures),
              _ChipWrap(
                children: <Widget>[
                  for (final ItemFeature feature in ItemFeature.values)
                    FilterChip(
                      label: Text(featureLabel(feature, l10n)),
                      selected: _draft.features.contains(feature),
                      onSelected: (on) => _edit(
                        _draft.copyWith(
                          features:
                              LibraryFilter.toggled(_draft.features, feature, on),
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: spacing.sm),
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
                // Newest first: a library's recent years are the ones anybody
                // opens a filter to pick.
                values: options.years.toList()..sort((a, b) => b.compareTo(a)),
                chosen: _draft.years,
                label: (v) => '$v',
                onToggle: (value, on) => _edit(
                  _draft.copyWith(
                    years: LibraryFilter.toggled(_draft.years, value, on),
                  ),
                ),
              ),
              // Said only once the request has settled: "nothing to filter by"
              // while the lists are still in flight is wrong more often than
              // it is right.
              if (viewId != null && !request.isLoading && options.isEmpty)
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
        SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.all(spacing.md),
            child: Row(
              children: <Widget>[
                TextButton(
                  // Resets the draft rather than applying it, so a reset the
                  // user changes their mind about costs only a dismissal.
                  onPressed: _isDefault
                      ? null
                      : () => setState(() {
                            _draft = LibraryFilter.none;
                            _ordering = _defaultOrdering;
                          }),
                  child: Text(l10n.filterReset),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () => Navigator.of(context)
                      .pop((ordering: _ordering, filter: _draft)),
                  child: Text(l10n.filterApply),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The wording for one watch-state filter.
///
/// Public because the active-filter chips over the grid use the same word the
/// dialog does: two spellings of one filter would read as two filters.
String flagLabel(ItemFilter flag, AppLocalizations l10n) {
  return switch (flag) {
    ItemFilter.played => l10n.filterPlayed,
    ItemFilter.unplayed => l10n.filterUnplayed,
    ItemFilter.favourite => l10n.filterFavourite,
    ItemFilter.resumable => l10n.filterInProgress,
  };
}

String statusLabel(SeriesStatus status, AppLocalizations l10n) {
  return switch (status) {
    SeriesStatus.continuing => l10n.statusContinuing,
    SeriesStatus.ended => l10n.statusEnded,
  };
}

String featureLabel(ItemFeature feature, AppLocalizations l10n) {
  return switch (feature) {
    ItemFeature.subtitles => l10n.subtitles,
    ItemFeature.trailer => l10n.featureTrailer,
    ItemFeature.specialFeature => l10n.featureExtras,
    ItemFeature.themeSong => l10n.featureThemeSong,
    ItemFeature.themeVideo => l10n.featureThemeVideo,
  };
}

/// A section built from what the server said the library holds, collapsed
/// by default — a library's tags alone can run to hundreds.
///
/// The count in the heading is what keeps a collapsed section honest: a shut
/// section hiding three chosen genres is a library that looks half empty
/// with nothing on screen saying why. Absent when the server named nothing.
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

    return ExpansionTile(
      title: Text(title),
      // Open when something in it is already chosen, so the user sees it.
      initiallyExpanded: chosen.isNotEmpty,
      // Stock M3 draws a rounded outline around an expanded tile, which in a
      // stack of four of them is four boxes inside a box.
      shape: const Border(),
      collapsedShape: const Border(),
      trailing: chosen.isEmpty
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  '${chosen.length}',
                  style: context.texts.labelLarge
                      ?.copyWith(color: context.colors.primary),
                ),
                SizedBox(width: context.spacing.sm),
                const Icon(Icons.expand_more_rounded),
              ],
            ),
      children: <Widget>[
        _ChipWrap(
          children: <Widget>[
            for (final T value in values)
              FilterChip(
                label: Text(label(value)),
                selected: chosen.contains(value),
                onSelected: (on) => onToggle(value, on),
              ),
          ],
        ),
        SizedBox(height: context.spacing.sm),
      ],
    );
  }
}

class _ChipWrap extends StatelessWidget {
  const _ChipWrap({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: spacing.lg),
      child: Wrap(spacing: spacing.sm, runSpacing: spacing.sm, children: children),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({required this.text});

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
      child: Text(
        text,
        style: context.texts.titleSmall?.copyWith(color: context.colors.primary),
      ),
    );
  }
}
