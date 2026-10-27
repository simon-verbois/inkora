import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'ebook_presentation.dart';

/// The optional native tile has one stable content identity in ImageCache.
/// Scale is supplied at paint time, so rotation/DPR/color changes reuse pixels.
final class EbookPaperImage extends ImageProvider<EbookPaperImage> {
  const EbookPaperImage({this.version = 3});
  final int version;

  @override
  Future<EbookPaperImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  bool operator ==(Object other) =>
      other is EbookPaperImage && other.version == version;
  @override
  int get hashCode => Object.hash(runtimeType, version);

  @override
  ImageStreamCompleter loadImage(
    EbookPaperImage key,
    ImageDecoderCallback decode,
  ) => MultiFrameImageStreamCompleter(codec: _codec(decode), scale: 1);

  Future<ui.Codec> _codec(ImageDecoderCallback decode) async => decode(
    await ui.ImmutableBuffer.fromUint8List(await EbookPresentation.paperTile()),
    getTargetSize: (width, height) => ui.TargetImageSize(
      width: width.clamp(1, 512),
      height: height.clamp(1, 512),
    ),
  );
}

/// Paint under the retained publication AND its outer/safe-area padding.
class EbookPaperBackground extends StatelessWidget {
  const EbookPaperBackground({
    super.key,
    required this.color,
    required this.enabled,
    required this.child,
  });
  final Color color;
  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    key: const Key('ebook-full-background'),
    decoration: BoxDecoration(
      color: color,
      image: enabled && EbookPresentation.supported
          ? DecorationImage(
              image: const EbookPaperImage(),
              repeat: ImageRepeat.repeat,
              alignment: Alignment.topLeft,
              fit: BoxFit.none,
              scale: MediaQuery.devicePixelRatioOf(context),
              filterQuality: FilterQuality.none,
              onError: (error, stack) =>
                  debugPrint('Paper background unavailable: $error'),
            )
          : null,
    ),
    child: child,
  );
}
