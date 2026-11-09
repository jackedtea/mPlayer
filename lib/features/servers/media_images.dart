// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../servers/media_library_source.dart';
import '../../widgets/remote_art.dart';
import 'server_library.dart';

/// Every picture the server holds for an item, in gallery order.
final itemImagesProvider = FutureProvider.autoDispose
    .family<List<ServerImage>, String>((ref, itemId) async {
      final source = ref.watch(activeServerProvider);
      if (source == null) return const <ServerImage>[];
      return source.images(itemId);
    });

/// "Poster", "Backdrop", … for an image type; the server's own word for any
/// type not named here.
String imageTypeLabel(String type, AppLocalizations l10n) => switch (type) {
  'Primary' => l10n.imagePrimary,
  'Backdrop' => l10n.imageBackdrop,
  'Logo' => l10n.imageLogo,
  'Thumb' => l10n.imageThumb,
  'Banner' => l10n.imageBanner,
  'Art' => l10n.imageArt,
  'Disc' => l10n.imageDisc,
  _ => type,
};

/// Types drawn whole on a plain panel rather than filling their tile: a logo
/// and clear art are cut-outs on transparency, a disc is round.
bool _isCutOut(String type) =>
    type == 'Logo' || type == 'Art' || type == 'Disc';

/// The aspect ratio a tile gets when the server did not measure the image.
double _fallbackAspect(String type) => switch (type) {
  'Primary' => 2 / 3,
  'Disc' => 1,
  'Logo' => 2.6,
  'Banner' => 5.4,
  _ => 16 / 9,
};

/// "Images": one row of the item's poster, backdrops, logo and the rest, each
/// at its own shape, and a tap opens them full screen. Draws nothing for an
/// item with a single picture or none — the header already shows that one.
class MediaImagesStrip extends ConsumerWidget {
  const MediaImagesStrip({
    super.key,
    required this.itemId,
    this.padding = EdgeInsets.zero,
  });

  final String itemId;

  /// Around the heading. The row itself runs edge to edge and supplies the
  /// horizontal part of it as its own inset.
  final EdgeInsets padding;

  /// The row's picture height; widths follow each picture's shape.
  static const height = 132.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final images =
        ref.watch(itemImagesProvider(itemId)).value ?? const <ServerImage>[];
    if (images.length < 2) return const SizedBox.shrink();

    final spacing = context.spacing;
    final l10n = AppLocalizations.of(context);
    final source = ref.watch(activeServerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Padding(
          padding: padding.copyWith(bottom: spacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Text(l10n.mediaImages, style: context.texts.titleMedium),
              SizedBox(width: spacing.sm),
              Text(
                '${images.length}',
                style: context.texts.bodyMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: height + spacing.xs + _captionHeight(context),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.only(left: padding.left, right: padding.right),
            itemCount: images.length,
            separatorBuilder: (_, _) => SizedBox(width: spacing.md),
            itemBuilder: (context, i) {
              final image = images[i];
              final aspect = image.aspectRatio ?? _fallbackAspect(image.type);
              final width = (height * aspect).clamp(72.0, 360.0);
              return _ImageTile(
                width: width,
                type: image.type,
                url: source?.itemImageUrl(
                  itemId,
                  image,
                  maxWidth: (width * 2).round(),
                ),
                label: imageTypeLabel(image.type, l10n),
                onTap: () => showImageViewer(
                  context,
                  ref,
                  itemId: itemId,
                  images: images,
                  initial: i,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  static double _captionHeight(BuildContext context) {
    final style = context.texts.bodySmall;
    return (MediaQuery.textScalerOf(context).scale(style?.fontSize ?? 12) *
            (style?.height ?? 16 / 12))
        .ceilToDouble();
  }
}

class _ImageTile extends StatelessWidget {
  const _ImageTile({
    required this.width,
    required this.type,
    required this.url,
    required this.label,
    required this.onTap,
  });

  final double width;
  final String type;
  final Uri? url;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final scheme = context.colors;
    final cutOut = _isCutOut(type);

    // The whole tile, caption included, is the tap target.
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: onTap,
        borderRadius: context.radii.chipAll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              height: MediaImagesStrip.height,
              width: width,
              child: ClipRRect(
                borderRadius: context.radii.chipAll,
                child: ColoredBox(
                  color: scheme.surfaceContainerHighest,
                  child: Padding(
                    padding: EdgeInsets.all(cutOut ? spacing.sm : 0),
                    child: RemoteArt(
                      url: url,
                      fit: cutOut ? BoxFit.contain : BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: spacing.xs),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.texts.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The pictures full screen, one at a time: swipe between them, pinch to
/// look closer.
Future<void> showImageViewer(
  BuildContext context,
  WidgetRef ref, {
  required String itemId,
  required List<ServerImage> images,
  int initial = 0,
}) {
  final source = ref.read(activeServerProvider);
  return showDialog<void>(
    context: context,
    useSafeArea: false,
    barrierColor: Colors.black,
    builder: (context) => _ImageViewer(
      urls: <Uri?>[
        // The original: this is the one place the full picture is wanted.
        for (final ServerImage image in images)
          source?.itemImageUrl(itemId, image),
      ],
      labels: <String>[
        for (final ServerImage image in images)
          imageTypeLabel(image.type, AppLocalizations.of(context)),
      ],
      initial: initial,
    ),
  );
}

class _ImageViewer extends StatefulWidget {
  const _ImageViewer({
    required this.urls,
    required this.labels,
    required this.initial,
  });

  final List<Uri?> urls;
  final List<String> labels;
  final int initial;

  @override
  State<_ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<_ImageViewer> {
  late final _pages = PageController(initialPage: widget.initial);
  late int _index = widget.initial;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _go(int delta) {
    final next = (_index + delta).clamp(0, widget.urls.length - 1);
    _pages.animateToPage(
      next,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final count = widget.urls.length;
    final wide = !context.windowSize.isCompact;

    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: <Widget>[
          PageView.builder(
            controller: _pages,
            itemCount: count,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) => InteractiveViewer(
              maxScale: 5,
              child: Center(
                child: RemoteArt(url: widget.urls[i], fit: BoxFit.contain),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: <Widget>[
                  IconButton(
                    color: Colors.white,
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).closeButtonTooltip,
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${widget.labels[_index]} · '
                      '${l10n.imageOf(_index + 1, count)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.texts.titleMedium?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // A mouse has no swipe; arrows at the sides on anything wider than
          // a phone.
          if (wide && _index > 0)
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                color: Colors.white,
                iconSize: 36,
                tooltip: MaterialLocalizations.of(context).previousPageTooltip,
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: () => _go(-1),
              ),
            ),
          if (wide && _index < count - 1)
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                color: Colors.white,
                iconSize: 36,
                tooltip: MaterialLocalizations.of(context).nextPageTooltip,
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: () => _go(1),
              ),
            ),
        ],
      ),
    );
  }
}
