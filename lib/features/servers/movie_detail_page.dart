// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/tokens.dart';
import '../../core/models/library_models.dart';
import '../../l10n/app_localizations.dart';
import '../../servers/media_library_source.dart';
import '../../widgets/backdrop_header.dart';
import 'server_library.dart';

/// Screen 1f — movie detail.
class MovieDetailPage extends ConsumerStatefulWidget {
  const MovieDetailPage({super.key, this.itemId});

  /// Null when the route was opened directly rather than from a tile.
  final String? itemId;

  @override
  ConsumerState<MovieDetailPage> createState() => _MovieDetailPageState();
}

class _MovieDetailPageState extends ConsumerState<MovieDetailPage> {
  bool _overviewExpanded = false;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final l10n = AppLocalizations.of(context);
    final itemId = widget.itemId;

    final request = itemId == null
        ? const AsyncValue<ServerItem?>.data(null)
        : ref.watch(serverItemProvider(itemId));

    final item = request.value;
    if (item == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: request.isLoading
              ? const CircularProgressIndicator()
              : Text(l10n.nothingToPlay),
        ),
      );
    }

    final movie = movieDetailFrom(item, l10n);
    final padding = spacing.screenPadding(context.windowSize);

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.only(bottom: spacing.xl * 2),
        children: <Widget>[
          BackdropHeader(
            seed: movie.title,
            artUrl: artUrlFor(ref, item, maxWidth: 900),
            height: 268,
            actions: <Widget>[
              CircleControl(
                icon: Icons.cast_rounded,
                tooltip: 'Cast',
                onPressed: () => _notYet(context, 'Cast'),
              ),
              CircleControl(
                icon: Icons.more_vert_rounded,
                tooltip: 'More',
                onPressed: () => _notYet(context, 'More'),
              ),
            ],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(movie.title, style: context.texts.headlineMedium),
                SizedBox(height: spacing.sm),
                _MetaRow(movie: movie),
              ],
            ),
          ),
          Padding(
            padding: padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _ActionRow(
                  movie: movie,
                  onPlay: () => playServerItem(context, ref, item.id),
                ),
                if (movie.isStarted) ...<Widget>[
                  SizedBox(height: spacing.lg),
                  _ProgressLine(movie: movie),
                ],
                SizedBox(height: spacing.xl),
                _Overview(
                  text: movie.overview,
                  expanded: _overviewExpanded,
                  onToggle: () =>
                      setState(() => _overviewExpanded = !_overviewExpanded),
                ),
                SizedBox(height: spacing.lg),
                Wrap(
                  spacing: spacing.sm,
                  runSpacing: spacing.sm,
                  children: <Widget>[
                    for (final String genre in movie.genres)
                      Chip(label: Text(genre)),
                  ],
                ),
                SizedBox(height: spacing.xl),
                _MediaInfoCard(rows: movie.info),
                SizedBox(height: spacing.xl),
                Text('Cast', style: context.texts.titleMedium),
                SizedBox(height: spacing.md),
              ],
            ),
          ),
          _CastStrip(cast: movie.cast),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.movie});

  final MovieDetail movie;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final spacing = context.spacing;
    final style = context.texts.bodySmall?.copyWith(color: scheme.onSurface);

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: spacing.sm,
      runSpacing: spacing.xs,
      children: <Widget>[
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.star_rounded, size: 15, color: context.semantic.ratingStar),
            const SizedBox(width: 3),
            Text(movie.rating, style: style),
          ],
        ),
        Text('·', style: style),
        Text(movie.year, style: style),
        Text('·', style: style),
        Text(movie.runtime, style: style),
        Text('·', style: style),
        // Certificates are boxed rather than plain text so they cannot be
        // mistaken for part of the runtime.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            border: Border.all(color: scheme.outline),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(movie.certificate, style: style),
        ),
        Text('·', style: style),
        Text(movie.quality, style: style),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.movie, required this.onPlay});

  final MovieDetail movie;

  /// Resolves the item through the server and opens the player.
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final radii = context.radii;

    return Row(
      children: <Widget>[
        Expanded(
          child: SizedBox(
            height: 56,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(radii.action),
                ),
              ),
              onPressed: onPlay,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(movie.resumeLabel ?? AppLocalizations.of(context).play),
            ),
          ),
        ),
        SizedBox(width: spacing.md),
        _SquareAction(
          icon: Icons.download_for_offline_rounded,
          tooltip: 'Download',
          onPressed: () => _notYet(context, 'Download'),
        ),
        SizedBox(width: spacing.md),
        _SquareAction(
          icon: Icons.bookmark_rounded,
          tooltip: 'Bookmark',
          onPressed: () => _notYet(context, 'Bookmark'),
        ),
      ],
    );
  }
}

class _SquareAction extends StatelessWidget {
  const _SquareAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(context.radii.action),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: 56,
            height: 56,
            child: Icon(icon, color: scheme.onPrimaryContainer),
          ),
        ),
      ),
    );
  }
}

class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.movie});

  final MovieDetail movie;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final scheme = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: movie.watchedFraction,
            minHeight: 4,
            backgroundColor: scheme.surfaceContainerHighest,
          ),
        ),
        SizedBox(height: spacing.sm),
        // The same sentence the primary button carries, so the two cannot
        // disagree about where the user got to.
        Text(
          movie.resumeLabel ?? '',
          style: context.texts.bodySmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({
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

    return GestureDetector(
      onTap: onToggle,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            text,
            maxLines: expanded ? null : 3,
            overflow: expanded ? null : TextOverflow.ellipsis,
            style: context.texts.bodyMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          Text(
            expanded ? 'Less' : 'More',
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

class _MediaInfoCard extends StatelessWidget {
  const _MediaInfoCard({required this.rows});

  final List<MediaInfoRow> rows;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final scheme = context.colors;

    return Container(
      padding: EdgeInsets.all(spacing.lg),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: context.radii.cardAll,
      ),
      child: Column(
        children: <Widget>[
          for (final (int i, MediaInfoRow row) in rows.indexed) ...<Widget>[
            if (i > 0) SizedBox(height: spacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  width: 84,
                  child: Text(
                    row.label,
                    style: context.texts.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
                Expanded(
                  child: Text(
                    row.value,
                    style: context.texts.bodySmall?.copyWith(
                      color: row.isSuccess
                          ? context.semantic.success
                          : scheme.onSurface,
                      fontWeight:
                          row.isSuccess ? FontWeight.w500 : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CastStrip extends StatelessWidget {
  const _CastStrip({required this.cast});

  final List<CastMember> cast;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final scheme = context.colors;

    return SizedBox(
      height: 116,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: spacing.screenPadding(context.windowSize),
        itemCount: cast.length,
        separatorBuilder: (_, _) => SizedBox(width: spacing.lg),
        itemBuilder: (context, i) {
          final member = cast[i];
          return SizedBox(
            width: 72,
            child: Column(
              children: <Widget>[
                CircleAvatar(
                  radius: 32,
                  backgroundColor: scheme.surfaceContainerHighest,
                  child: Text(
                    member.name.characters.first,
                    style: TextStyle(
                      fontSize: 22,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                SizedBox(height: spacing.sm - 2),
                Text(
                  member.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
                Text(
                  member.role,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

void _notYet(BuildContext context, String what) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('$what — not implemented yet')),
  );
}
