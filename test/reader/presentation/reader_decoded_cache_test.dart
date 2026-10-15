import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/reader/presentation/reader_image_provider.dart';
import 'package:inkora/reader/domain/page_source.dart';

import '../../support/reader_fakes.dart';

void main() {
  testWidgets(
    'decoded cache reuses content across new buffers, separates size/account/revision and evicts explicitly',
    (tester) async {
      final manifest = readerManifest();
      EncodedPage page() => EncodedPage(
        key: manifest.key(0),
        bytes: fixtureRaster.sublist(0),
        mediaType: 'image/png',
      );
      var decodes = 0;
      final first = ReaderImageProvider(
        page(),
        1,
        1,
        onDecoded: (_) => decodes++,
      );
      await tester.pumpWidget(MaterialApp(home: Image(image: first)));
      await tester.runAsync(() async {
        await precacheImage(first, tester.element(find.byType(Image)));
      });
      await tester.pumpAndSettle();
      final second = ReaderImageProvider(
        page(),
        1,
        1,
        onDecoded: (_) => decodes++,
      );
      await tester.pumpWidget(MaterialApp(home: Image(image: second)));
      await tester.pumpAndSettle();
      expect(decodes, 1);
      expect(first.imageKey, second.imageKey);
      expect(ReaderImageKey(manifest.key(0), 2, 1), isNot(first.imageKey));
      expect(
        ReaderImageKey(readerManifest(account: 'other').key(0), 1, 1),
        isNot(first.imageKey),
      );
      expect(
        ReaderImageKey(readerManifest(revision: 'new').key(0), 1, 1),
        isNot(first.imageKey),
      );
      ReaderDecodedCache.retainRevision(
        manifest.accountId,
        manifest.bookId,
        'new',
      );
      expect(
        PaintingBinding.instance.imageCache.containsKey(first.imageKey),
        false,
      );
      await tester.pumpWidget(const SizedBox());
      ReaderDecodedCache.clearAccount(manifest.accountId);
      expect(
        PaintingBinding.instance.imageCache.currentSizeBytes,
        lessThanOrEqualTo(48 * 1024 * 1024),
      );
    },
  );
}
