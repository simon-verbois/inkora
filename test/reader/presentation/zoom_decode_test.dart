import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/reader/domain/reader_manifest.dart';
import 'package:inkora/reader/presentation/reader_page_image.dart';

void main() {
  test('pinch scales settle into coarse decode steps', () {
    expect(zoomDecodeStep(1), 1);
    expect(zoomDecodeStep(1.4), 1);
    expect(zoomDecodeStep(1.6), 2);
    expect(zoomDecodeStep(2.4), 2);
    expect(zoomDecodeStep(3.6), 4);
    expect(zoomDecodeStep(6), 4);
  });

  test(
    'zoomed decodes add detail up to the source within their own budget',
    () {
      final page = PageDimensions(1600, 2400);
      // Phone fit: 400 logical px at 3x.
      final fit = readerDecodeSize(page, 1200);
      final zoomed = readerDecodeSize(
        page,
        1200 * 2,
        budgetBytes: zoomDecodeBudget,
        maximumWidth: 4096,
      );
      expect(zoomed.width, greaterThan(fit.width));
      expect(zoomed.width, lessThanOrEqualTo(page.width));
      expect(
        zoomed.width * zoomed.height * 4,
        lessThanOrEqualTo(zoomDecodeBudget),
      );
      final max = readerDecodeSize(
        page,
        1200 * 4,
        budgetBytes: zoomDecodeBudget,
        maximumWidth: 4096,
      );
      expect(max.width, page.width, reason: 'never upscales beyond the source');
    },
  );
}
