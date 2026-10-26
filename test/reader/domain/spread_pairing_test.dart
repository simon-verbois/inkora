import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/reader/domain/paged_layout.dart';
import 'package:inkora/reader/domain/reader_manifest.dart';
import 'package:inkora/reader/domain/reading_settings.dart';

void main() {
  final portrait = PageDimensions(700, 1000);
  final wide = PageDimensions(1400, 1000);
  test('cover plus merged spread continues with the next complete pair', () {
    final pages = [
      portrait,
      portrait,
      portrait,
      portrait,
      portrait,
      wide,
      portrait,
      portrait,
      portrait,
      portrait,
    ];
    expect(PagedLayout(pages, doublePages: true, offset: 1).groups, [
      [0],
      [1, 2],
      [3, 4],
      [5],
      [6, 7],
      [8, 9],
    ]);
    expect(SpreadPairingAnalyzer.dimensions(pages), isTrue);
    expect(
      SpreadPairingAnalyzer.dimensions([wide, portrait, portrait]),
      isFalse,
    );
  });
  test(
    'inconsistent anchors and square pictures do not guess cover placement',
    () {
      expect(SpreadPairingAnalyzer.dimensions([portrait, portrait]), isNull);
      expect(
        SpreadPairingAnalyzer.dimensions([
          PageDimensions(1000, 1000),
          portrait,
        ]),
        isNull,
      );
      expect(SpreadPairingAnalyzer.dimensions([wide, portrait, wide]), isNull);
    },
  );
  test(
    'legacy booleans stay explicit and child Auto overrides forced parents',
    () {
      for (final shifted in [true, false]) {
        final legacy = ReadingOverrides.fromJson({'spreadOffset': shifted});
        final mode = shifted ? SpreadPairing.shifted : SpreadPairing.unshifted;
        expect(ReadingSettings.resolve([legacy]).spreadPairing, mode);
        expect(
          ReadingSettings.resolve([
            legacy,
          ], automaticSpreadOffset: !shifted).spreadOffset,
          shifted,
        );
        final auto = ReadingSettings.resolve([
          legacy,
          const ReadingOverrides(spreadPairing: SpreadPairing.automatic),
        ], automaticSpreadOffset: !shifted);
        expect(auto.spreadPairing, SpreadPairing.automatic);
        expect(auto.spreadOffset, !shifted);
      }
    },
  );
  for (final shifted in [false, true]) {
    for (final rtl in [false, true]) {
      test(
        'visual joins support shifted=$shifted rtl=$rtl with several pairs',
        () {
          Uint8List pattern(bool flip) => Uint8List.fromList([
            for (var y = 0; y < 64; y++) (y.isEven != flip) ? 32 : 224,
          ]);
          final samples = <int, PageEdgeSample>{};
          for (var i = 0; i < 8; i++) {
            final joiningFirst = i.isOdd == shifted;
            var left = pattern(false), right = pattern(!joiningFirst);
            if (rtl) (left, right) = (right, left);
            samples[i] = PageEdgeSample(left, right);
          }
          expect(
            SpreadPairingAnalyzer.visual(samples, rightToLeft: rtl),
            shifted,
          );
        },
      );
    }
  }
  test(
    'blank margins and one coincidentally similar join are inconclusive',
    () {
      final blank = Uint8List.fromList(List.filled(64, 255));
      expect(
        SpreadPairingAnalyzer.visual({
          for (var i = 0; i < 8; i++) i: PageEdgeSample(blank, blank),
        }, rightToLeft: true),
        isNull,
      );
    },
  );
}
