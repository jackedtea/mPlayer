// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../servers/media_library_source.dart';
import '../../widgets/gradient_art.dart';
import '../../widgets/poster_tile.dart';
import '../../widgets/remote_art.dart';
import 'detail_sections.dart';
import 'library_view_settings.dart';
import 'server_library.dart';

/// A person: their photo, when and where they were born, a biography and
/// links elsewhere, then the films and the shows they appear in.
///
/// Reached by tapping a face in a cast strip. The person is an item on the
/// server like any other, so the details are the ordinary item fetch; the
/// credits are a second request. Films and series only — an actor credited
/// on forty episodes of one show should read as that one show, not as forty
/// rows of it, and that filtering happens in the request rather than here.
class PersonPage extends ConsumerStatefulWidget {
  const PersonPage({super.key, this.personId, this.name = ''});

  /// Null when the route was opened directly rather than from a face.
  final String? personId;

  /// What the app bar says before the person's own record arrives.
  final String name;

  @override
  ConsumerState<PersonPage> createState() => _PersonPageState();
}

class _PersonPageState extends ConsumerState<PersonPage> {
  bool _bioExpanded = false;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final l10n = AppLocalizations.of(context);
    final id = widget.personId;

    final person = id == null ? null : ref.watch(serverItemProvider(id)).value;
    final request = id == null
        ? const AsyncValue<List<ServerItem>>.data(<ServerItem>[])
        : ref.watch(personItemsProvider(id));
    final items = request.value ?? const <ServerItem>[];

    final movies = <ServerItem>[
      for (final ServerItem i in items)
        if (i.kind != ServerItemKind.series) i,
    ];
    final shows = <ServerItem>[
      for (final ServerItem i in items)
        if (i.kind == ServerItemKind.series) i,
    ];

    final name = person?.title ?? widget.name;
    final edge = spacing.screenHorizontal(context.windowSize);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: context.colors.surfaceContainerHigh,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(name.isEmpty ? l10n.cast : name),
      ),
      body: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(edge, spacing.lg, edge, 0),
              child: _PersonHeader(
                name: name,
                person: person,
                photoUrl: person == null
                    ? null
                    : artUrlFor(ref, person, maxWidth: 600),
                bioExpanded: _bioExpanded,
                onToggleBio: () => setState(() => _bioExpanded = !_bioExpanded),
              ),
            ),
          ),
          if (request.isLoading && items.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else if (items.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(spacing.xl),
                child: Text(
                  l10n.nothingHere,
                  textAlign: TextAlign.center,
                  style: context.texts.bodyMedium?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ..._section(context, l10n.searchMovies, movies),
          ..._section(context, l10n.searchShows, shows),
          SliverToBoxAdapter(
            child: SizedBox(height: spacing.xl + context.systemBottomInset),
          ),
        ],
      ),
    );
  }

  /// A heading with the count, and a grid of posters under it. Nothing at
  /// all for an empty one: a heading over no posters reads as a failure.
  List<Widget> _section(
    BuildContext context,
    String title,
    List<ServerItem> items,
  ) {
    if (items.isEmpty) return const <Widget>[];
    final spacing = context.spacing;
    final edge = spacing.screenHorizontal(context.windowSize);
    final columns = columnsForWidth(
      ref.watch(libraryColumnsProvider),
      MediaQuery.sizeOf(context).width,
    );
    final gutter = (edge - spacing.hitInset).clamp(0.0, double.infinity);

    return <Widget>[
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(edge, spacing.xl, edge, spacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Text(title, style: context.texts.titleLarge),
              SizedBox(width: spacing.sm),
              Text(
                '${items.length}',
                style: context.texts.bodyMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
      SliverLayoutBuilder(
        builder: (context, constraints) {
          final cell = (constraints.crossAxisExtent - gutter * 2) / columns;
          final posterWidth = (cell - spacing.hitInset * 2).clamp(48.0, 400.0);
          final posterHeight = posterWidth * 142 / 108;

          return SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: gutter),
            sliver: SliverGrid.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: spacing.sm,
                crossAxisSpacing: 0,
                mainAxisExtent: PosterTile.outerHeight(context, posterHeight),
              ),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final entry = items[i];
                return PosterTile(
                  item: libraryItemFrom(entry),
                  artUrl: artUrlFor(ref, entry, maxWidth: 300),
                  width: posterWidth,
                  posterHeight: posterHeight,
                  onTap: () => openServerItem(context, entry),
                );
              },
            ),
          );
        },
      ),
    ];
  }
}

/// The photo beside the name and the facts, with the biography and the
/// links under them on a phone and beside them on anything wider.
class _PersonHeader extends StatelessWidget {
  const _PersonHeader({
    required this.name,
    required this.person,
    required this.photoUrl,
    required this.bioExpanded,
    required this.onToggleBio,
  });

  final String name;

  /// Null until the person's record arrives, or where the server has none:
  /// the name from the cast strip and a placeholder photo stand in.
  final ServerItem? person;
  final Uri? photoUrl;
  final bool bioExpanded;
  final VoidCallback onToggleBio;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final wide = !context.windowSize.isCompact;
    final photoWidth = wide ? 220.0 : 120.0;

    final photo = ClipRRect(
      borderRadius: context.radii.cardAll,
      child: SizedBox(
        width: photoWidth,
        height: photoWidth * 3 / 2,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            GradientArt(seed: name),
            Center(
              child: Icon(
                Icons.person_rounded,
                size: photoWidth * 0.4,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
            RemoteArt(url: photoUrl),
          ],
        ),
      ),
    );

    final bio = person?.overview?.trim() ?? '';
    final links = person?.links ?? const <ServerLink>[];
    final more = <Widget>[
      if (bio.isNotEmpty)
        _Biography(text: bio, expanded: bioExpanded, onToggle: onToggleBio),
      if (links.isNotEmpty) ...<Widget>[
        if (bio.isNotEmpty) SizedBox(height: spacing.lg),
        ExternalLinks(links: links),
      ],
    ];

    final facts = _Facts(name: name, person: person);

    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          photo,
          SizedBox(width: spacing.xl),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                facts,
                if (more.isNotEmpty) SizedBox(height: spacing.lg),
                ...more,
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            photo,
            SizedBox(width: spacing.lg),
            Expanded(child: facts),
          ],
        ),
        if (more.isNotEmpty) SizedBox(height: spacing.lg),
        ...more,
      ],
    );
  }
}

/// The name, then born (with an age), died, and the birth place — each only
/// where the server knows it.
class _Facts extends StatelessWidget {
  const _Facts({required this.name, required this.person});

  final String name;
  final ServerItem? person;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final format = DateFormat.yMMMd(locale);
    final style = context.texts.bodyMedium?.copyWith(
      color: context.colors.onSurfaceVariant,
    );

    final born = person?.premiereDate?.toLocal();
    final died = person?.endDate?.toLocal();
    final places = person?.productionLocations ?? const <String>[];

    final lines = <String>[
      if (born != null)
        died == null
            ? '${l10n.personBorn(format.format(born))} '
                  '(${l10n.personAge(ageOn(born, DateTime.now()))})'
            : l10n.personBorn(format.format(born)),
      if (died != null)
        born == null
            ? l10n.personDied(format.format(died))
            : '${l10n.personDied(format.format(died))} '
                  '(${l10n.personAge(ageOn(born, died))})',
      if (places.isNotEmpty) l10n.personBirthPlace(places.first),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          name,
          style: context.texts.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        for (final String line in lines) ...<Widget>[
          SizedBox(height: spacing.xs),
          Text(line, style: style),
        ],
      ],
    );
  }
}

/// Whole years from [born] to [on].
int ageOn(DateTime born, DateTime on) {
  var age = on.year - born.year;
  if (on.month < born.month || (on.month == born.month && on.day < born.day)) {
    age--;
  }
  return age;
}

/// The biography, six lines until it is tapped.
class _Biography extends StatelessWidget {
  const _Biography({
    required this.text,
    required this.expanded,
    required this.onToggle,
  });

  final String text;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final l10n = AppLocalizations.of(context);

    return GestureDetector(
      onTap: onToggle,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            text,
            maxLines: expanded ? null : 6,
            overflow: expanded ? null : TextOverflow.ellipsis,
            style: context.texts.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          Text(
            expanded ? l10n.less : l10n.more,
            style: context.texts.bodyMedium?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
