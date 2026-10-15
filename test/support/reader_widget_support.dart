import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Native codecs need real event-loop time; a fake-clock pumpAndSettle alone
/// cannot finish an animated placeholder awaiting an actual decoded frame.
Future<void> settleReaderImages(WidgetTester tester) async {
  // A prepared sliver can mount another batch after a restored/jumped scroll
  // position settles. Decode offscreen children too, then recheck that batch.
  for (var turn = 0; turn < 6; turn++) {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final imageFinder = find.byType(Image, skipOffstage: false);
    final images = tester.widgetList<Image>(imageFinder).toList();
    if (images.isNotEmpty) {
      final context = tester.element(imageFinder.first);
      await tester.runAsync(() async {
        await Future.wait(
          images.map(
            (image) => precacheImage(image.image, context, onError: (_, _) {}),
          ),
        );
      });
    }
    await tester.pump();
    if (find
        .byType(CircularProgressIndicator, skipOffstage: false)
        .evaluate()
        .isEmpty) {
      break;
    }
  }
  await tester.pumpAndSettle();
}
