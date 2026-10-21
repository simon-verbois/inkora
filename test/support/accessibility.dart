import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Android 48 dp targets and labelled targets on the current frame, plus
/// WCAG text contrast unless [contrast] is false (it samples rendered pixels,
/// so pages showing generated cover art may opt out for that frame).
///
/// Call after the screen has settled; semantics are enabled here for the
/// checks and released afterwards.
Future<void> expectAccessibilityGuidelines(
  WidgetTester tester, {
  bool contrast = true,
}) async {
  final semantics = tester.binding.ensureSemantics();
  try {
    await tester.pump();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    if (contrast) {
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    }
  } finally {
    semantics.dispose();
  }
}

/// Merged semantics of the node at [finder] (label, flags, actions).
SemanticsData semanticsDataOf(WidgetTester tester, Finder finder) =>
    tester.getSemantics(finder).getSemanticsData();
