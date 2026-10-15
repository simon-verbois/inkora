import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../domain/content_key.dart';
import '../domain/reader_trace.dart';
import '../domain/page_source.dart';

/// Cache identity does not retain encoded bytes and includes codec dimensions.
@immutable
final class ReaderImageKey {
  const ReaderImageKey(this.content, this.width, this.height);
  final ContentKey content;
  final int width;
  final int height;
  @override
  bool operator ==(Object other) =>
      other is ReaderImageKey &&
      content == other.content &&
      width == other.width &&
      height == other.height;
  @override
  int get hashCode => Object.hash(content, width, height);
}

/// Uses Flutter's bounded LRU for decoded RGBA; registry enables explicit
/// account/revision invalidation without flushing unrelated app imagery.
final class ReaderDecodedCache {
  static final _keys = <ReaderImageKey>{};
  static void register(ReaderImageKey key) {
    final cache = PaintingBinding.instance.imageCache;
    _keys.remove(key);
    _keys.add(key);
    while (_keys.length > 128) {
      cache.evict(_keys.first);
      _keys.remove(_keys.first);
    }
  }

  static void invalidate(ContentKey content) {
    for (final key in _keys.where((key) => key.content == content).toList()) {
      evict(key);
    }
  }

  static void evict(ReaderImageKey key) {
    PaintingBinding.instance.imageCache.evict(key);
    _keys.remove(key);
  }

  static void retainRevision(String account, String book, String revision) {
    for (final key
        in _keys
            .where(
              (k) =>
                  k.content.accountId == account &&
                  k.content.bookId == book &&
                  k.content.revision != revision,
            )
            .toList()) {
      evict(key);
    }
  }

  static void clearAccount(String account) {
    for (final key
        in _keys.where((k) => k.content.accountId == account).toList()) {
      evict(key);
    }
  }
}

final class ReaderImageProvider extends ImageProvider<ReaderImageKey> {
  ReaderImageProvider(this.page, this.width, this.height, {this.onDecoded});
  final EncodedPage page;
  final int width;
  final int height;
  final void Function(Duration)? onDecoded;
  ReaderImageKey get imageKey => ReaderImageKey(page.key, width, height);
  @override
  Future<ReaderImageKey> obtainKey(ImageConfiguration configuration) {
    ReaderTrace.sink?.call('resolve-key', page.key.pageIndex, {
      'key': imageKey.hashCode,
      'width': width,
      'height': height,
    });
    ReaderDecodedCache.register(imageKey);
    return SynchronousFuture(imageKey);
  }

  /// Value identity: rebuilding a page widget with an equivalent provider
  /// must not re-resolve the image stream or touch the decoded-key registry.
  @override
  bool operator ==(Object other) =>
      other is ReaderImageProvider && other.imageKey == imageKey;
  @override
  int get hashCode => imageKey.hashCode;

  @override
  ImageStreamCompleter loadImage(
    ReaderImageKey key,
    ImageDecoderCallback decode,
  ) {
    ReaderTrace.sink?.call('codec-request', page.key.pageIndex, {
      'width': width,
      'height': height,
    });
    final watch = Stopwatch()..start();
    final completer = MultiFrameImageStreamCompleter(
      codec: _codec(decode),
      scale: 1,
    );
    final onDecoded = this.onDecoded;
    if (onDecoded != null || ReaderTrace.sink != null) {
      // The codec future completes after header parsing; pixels are decoded
      // by getNextFrame. Report the duration until the first frame exists.
      late final ImageStreamListener listener;
      listener = ImageStreamListener((info, _) {
        try {
          ReaderTrace.sink?.call('decoded', page.key.pageIndex, {
            'micros': watch.elapsedMicroseconds,
            'frame': identityHashCode(info.image),
            'actualWidth': info.image.width,
            'actualHeight': info.image.height,
            'width': width,
            'height': height,
          });
          onDecoded?.call(watch.elapsed);
        } finally {
          // Each listener owns its ImageInfo clone, independently of the
          // displayed frame and ImageCache. Readiness retains no native handle.
          info.dispose();
          completer.removeListener(listener);
        }
      }, onError: (_, _) => completer.removeListener(listener));
      completer.addListener(listener);
    }
    return completer;
  }

  Future<ui.Codec> _codec(ImageDecoderCallback decode) async {
    final codec = await decode(
      await ui.ImmutableBuffer.fromUint8List(page.bytes),
      getTargetSize: (_, _) => ui.TargetImageSize(width: width, height: height),
    );
    ReaderTrace.sink?.call('codec-created', page.key.pageIndex, {
      'codec': identityHashCode(codec),
    });
    return codec;
  }
}
