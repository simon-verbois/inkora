import 'dart:typed_data';
import 'dart:async';

import 'package:flutter/painting.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/features/library/presentation/book_cover.dart';
import 'package:inkora/reader/domain/page_source.dart';
import 'package:inkora/reader/presentation/reader_image_provider.dart';

import '../../support/reader_fakes.dart';

void main() {
  testWidgets('first-frame telemetry releases its image handle', (
    tester,
  ) async {
    Future<int> handles(int index, bool observed) async {
      final page = EncodedPage(
        key: readerManifest(book: 'image-handles').key(index),
        bytes: fixtureRaster,
        mediaType: 'image/png',
      );
      final provider = ReaderImageProvider(
        page,
        100,
        150,
        onDecoded: observed ? (_) {} : null,
      );
      final stream = provider.resolve(ImageConfiguration.empty);
      final ready = Completer<ImageInfo>();
      final listener = ImageStreamListener((info, _) => ready.complete(info));
      stream.addListener(listener);
      for (var attempt = 0; attempt < 100 && !ready.isCompleted; attempt++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      expect(ready.isCompleted, isTrue);
      final info = await ready.future;
      stream.removeListener(listener);
      final count = info.image.debugGetOpenHandleStackTraces()!.length;
      info.dispose();
      ReaderDecodedCache.evict(provider.imageKey);
      return count;
    }

    final plain = await handles(0, false);
    final observed = await handles(1, true);
    expect(
      observed,
      plain,
      reason:
          'Observing readiness must not retain an extra native image handle',
    );
  });

  test('reader image providers compare by decoded identity, not instance', () {
    final key = readerManifest().key(0);
    final page = EncodedPage(
      key: key,
      bytes: fixtureRaster,
      mediaType: 'image/png',
    );
    final copy = EncodedPage(
      key: key,
      bytes: Uint8List.fromList(fixtureRaster),
      mediaType: 'image/png',
    );
    expect(
      ReaderImageProvider(page, 100, 150, onDecoded: (_) {}),
      ReaderImageProvider(copy, 100, 150, onDecoded: (_) {}),
    );
    expect(
      ReaderImageProvider(page, 100, 150),
      isNot(ReaderImageProvider(page, 200, 300)),
    );
  });

  test(
    'cover image keys exclude bytes and change only with content version',
    () {
      const cover = (kind: 'book', id: 'b', modified: 1);
      final a = CoverImageProvider(
        const CoverImageKey('account', cover, 0, 128, 192),
        Uint8List.fromList([1, 2, 3]),
      );
      final reloaded = CoverImageProvider(
        const CoverImageKey('account', cover, 0, 128, 192),
        Uint8List.fromList([1, 2, 3]),
      );
      expect(a, reloaded);
      expect(
        a,
        isNot(
          CoverImageProvider(
            const CoverImageKey('account', cover, 1, 128, 192),
            Uint8List.fromList([4]),
          ),
        ),
      );
      expect(
        a,
        isNot(
          CoverImageProvider(
            const CoverImageKey('other', cover, 0, 128, 192),
            Uint8List.fromList([1, 2, 3]),
          ),
        ),
      );
    },
  );
}
