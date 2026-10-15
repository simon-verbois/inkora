import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/reader/domain/reader_manifest.dart';
import 'package:inkora/reader/domain/webtoon_layout.dart';
import 'package:inkora/reader/presentation/reader_page_image.dart';

void main() {
  test('comfortable width keeps portrait width and reduces landscape magnification', () {
    expect(WebtoonLayout.readingWidth(768, 1024), 768);
    expect(WebtoonLayout.readingWidth(1280, 800), 680);
    expect(WebtoonLayout.readingWidth(1280, 800, fullWidth: true), 1280);
  });
  test(
    'viewport-relative demand handles mixed heights and reverse movement',
    () {
      final pages = [
        PageDimensions(100, 50),
        PageDimensions(100, 1000),
        PageDimensions(100, 100),
      ];
      final layout = WebtoonLayout(pages, 200, 8);
      expect(layout.height(0), 100);
      expect(layout.visible(0, 300), [0, 1]);
      expect(layout.visible(1900, 400), [1, 2]);
      expect(layout.visible(50, 300), [0, 1]);
      expect(layout.locate(-30).pageIndex, 0);
      expect(layout.locate(100000).pageIndex, 2);
    },
  );
  test(
    'page plus normalized offset is stable through width and spacing changes',
    () {
      final pages = [PageDimensions(100, 50), PageDimensions(100, 1000)];
      final phone = WebtoonLayout(pages, 200, 8);
      final tablet = WebtoonLayout(pages, 600, 24);
      final locator = phone.locate(608);
      expect(locator.pageIndex, 1);
      expect(locator.fraction, .25);
      final restored = tablet.locate(tablet.offsetFor(locator));
      expect(restored.pageIndex, locator.pageIndex);
      expect(restored.fraction, locator.fraction);
    },
  );
  test('extreme aspect ratio codec dimensions remain within the decoded byte budget', () {
    for (final dimensions in [
      PageDimensions(100, 100000),
      PageDimensions(100000, 100),
      PageDimensions(4000, 6000),
    ]) {
      final decode = readerDecodeSize(dimensions, 3000);
      expect(
        decode.width * decode.height * 4,
        lessThanOrEqualTo(8 * 1024 * 1024),
      );
      expect(decode.width, greaterThan(0));
      expect(decode.height, greaterThan(0));
    }
  });

  test(
    'short strips bound the mounted cache window and share decoded bytes',
    () {
      final layout = WebtoonLayout(
        List.generate(1000, (_) => PageDimensions(100, 10)),
        100,
        0,
      );
      const offset = 5000.0;
      const viewport = 200.0;
      final extent = layout.cacheExtent(offset, viewport);
      final visible = layout.visible(offset, viewport);
      final prepared = layout.visible(offset - extent, viewport + extent * 2);
      expect(prepared.length, lessThanOrEqualTo(visible.length + 8));
      expect(extent, greaterThan(0));
      expect(
        prepared.fold(
          0,
          (int bytes, index) => bytes + layout.decodeBudget(index, viewport),
        ),
        lessThanOrEqualTo(44 * 1024 * 1024),
      );
    },
  );
}
