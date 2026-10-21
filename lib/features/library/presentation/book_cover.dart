import '../../../app/l10n/app_strings.dart';
import '../../../app/icons/inkora_icons.dart';

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/inkora_theme.dart';
import '../../../app/widgets/image_enhancement.dart';
import '../application/cover_providers.dart';
import '../data/cover_repository.dart';
import '../domain/catalogue.dart';

class BookCover extends ConsumerWidget {
  const BookCover({
    super.key,
    required this.item,
    this.width,
    this.muted = false,
  });
  static const _frame = 2.0;
  final CatalogueItem item;
  final double? width;

  /// A light page-colored veil for completed volumes; keeps the image identity.
  final bool muted;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supported =
        item.kind == CatalogueKind.book || item.kind == CatalogueKind.series;
    final key = (kind: item.kind.name, id: item.id, modified: item.modified);
    final repository = supported && item.canOpen
        ? ref.watch(coverRepositoryProvider).asData?.value
        : null;
    final bytes = repository == null
        ? null
        : TickerMode.valuesOf(context).enabled
        ? ref.watch(coverProvider(key)).asData?.value ?? repository.peek(key)
        : repository.peek(key);
    final colors = InkoraColors.of(context);
    final placeholder = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.raised, colors.panel],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  item.canOpen ? InkIcons.bookOpen : InkIcons.prohibit,
                  color: Theme.of(context).colorScheme.primary,
                  size: 32,
                ),
                const SizedBox(height: 8),
                LText(
                  item.title.isEmpty
                      ? 'I'
                      : item.title.substring(0, 1).toUpperCase(),
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontFamily: 'LibreBaskerville'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return ExcludeSemantics(
      child: SizedBox(
        width: width,
        child: LayoutBuilder(
          builder: (context, constraints) => AspectRatio(
            aspectRatio: InkoraLayout.coverRatio,
            child: DecoratedBox(
              position: muted
                  ? DecorationPosition.foreground
                  : DecorationPosition.background,
              decoration: BoxDecoration(
                color: muted
                    ? Theme.of(context).scaffoldBackgroundColor
                          .withValues(alpha: .24)
                    : null,
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary
                      .withValues(alpha: .8),
                ),
                borderRadius: InkRadius.small,
              ),
              child: Padding(
                padding: const EdgeInsets.all(_frame),
                child: ClipRRect(
                  // Concentric with the small frame radius.
                  borderRadius: const BorderRadius.all(
                    Radius.circular(InkRadius.s - _frame),
                  ),
                  child: bytes == null
                      ? placeholder
                      : Image(
                          key: ValueKey((key, repository!.accountId)),
                          image: coverImage(
                            repository,
                            key,
                            bytes,
                            constraints.maxWidth,
                            MediaQuery.devicePixelRatioOf(context),
                          ),
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.medium,
                          gaplessPlayback: true,
                          excludeFromSemantics: true,
                          frameBuilder: (_, child, _, _) => child is RawImage
                              ? EnhancedRawImage(raw: child)
                              : child,
                          errorBuilder: (_, _, _) => placeholder,
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared dimensions for visible and prefetched codecs; buckets keep cache
/// identity stable across small width changes without oversizing phone artwork.
ImageProvider coverImage(
  CoverRepository repository,
  CoverKey key,
  Uint8List bytes,
  double width,
  double pixelRatio,
) {
  final pixels = ((width * pixelRatio / 64).ceil() * 64).clamp(64, 480);
  return CoverImageProvider(
    CoverImageKey(
      repository.accountId,
      key,
      repository.version(key),
      pixels,
      (pixels / InkoraLayout.coverRatio).ceil().clamp(96, 720),
    ),
    bytes,
  );
}

/// Decoded-cover identity without the encoded bytes: ImageCache entries no
/// longer retain encoded artwork outside the repository's memory budget, and
/// identical bytes reloaded from disk hit the existing decoded image.
@immutable
final class CoverImageKey {
  const CoverImageKey(
    this.accountId,
    this.cover,
    this.version,
    this.width,
    this.height,
  );
  final String accountId;
  final CoverKey cover;
  final int version, width, height;
  @override
  bool operator ==(Object other) =>
      other is CoverImageKey &&
      other.accountId == accountId &&
      other.cover == cover &&
      other.version == version &&
      other.width == width &&
      other.height == height;
  @override
  int get hashCode => Object.hash(accountId, cover, version, width, height);
}

final class CoverImageProvider extends ImageProvider<CoverImageKey> {
  const CoverImageProvider(this.key, this.bytes);
  final CoverImageKey key;
  final Uint8List bytes;

  @override
  Future<CoverImageKey> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(key);

  @override
  ImageStreamCompleter loadImage(
    CoverImageKey key,
    ImageDecoderCallback decode,
  ) => MultiFrameImageStreamCompleter(codec: _decode(key, decode), scale: 1);

  Future<ui.Codec> _decode(
    CoverImageKey key,
    ImageDecoderCallback decode,
  ) async => decode(
    await ui.ImmutableBuffer.fromUint8List(bytes),
    // Same contract as ResizeImagePolicy.fit without upscaling.
    getTargetSize: (width, height) {
      if (width <= key.width && height <= key.height) {
        return const ui.TargetImageSize();
      }
      final scale = math.min(key.width / width, key.height / height);
      return ui.TargetImageSize(
        width: math.max(1, (width * scale).round()),
        height: math.max(1, (height * scale).round()),
      );
    },
  );

  @override
  bool operator ==(Object other) =>
      other is CoverImageProvider && other.key == key;
  @override
  int get hashCode => key.hashCode;
}
