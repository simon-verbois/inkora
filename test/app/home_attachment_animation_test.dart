import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/theme/inkora_theme.dart';
import 'package:inkora/app/widgets/ink_home_attachment.dart';

void main() {
  for (final reduced in [false, true]) {
    testWidgets(
      'attached background fades without rebuilding content (reduced $reduced)',
      (tester) async {
        final attached = ValueNotifier(false);
        addTearDown(attached.dispose);
        var builds = 0, taps = 0, paints = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: InkoraTheme.forest(),
            home: MediaQuery(
              data: MediaQueryData(disableAnimations: reduced),
              child: InkHomeAttachmentFrame(
                child: Stack(
                  children: [
                    Builder(
                      builder: (context) {
                        builds++;
                        return CustomPaint(
                          painter: _PaintCounter(() => paints++),
                          child: const SizedBox.expand(),
                        );
                      },
                    ),
                    Positioned(
                      left: 80,
                      top: 64,
                      child: ValueListenableBuilder<bool>(
                        valueListenable: attached,
                        builder: (context, value, child) =>
                            InkHomeToolGroup(attached: value, child: child!),
                        child: TextButton(
                          onPressed: () => taps++,
                          child: const Text('Filter'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final initialPaints = paints;
        attached.value = true;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 40));
        expect(
          tester.binding.transientCallbackCount,
          reduced ? 0 : greaterThan(0),
        );
        await tester.tap(find.text('Filter'));
        await tester.pumpAndSettle();
        expect(taps, 1);
        expect(builds, 1);
        expect(paints, initialPaints);
        attached.value = false;
        await tester.pumpAndSettle();
        expect(builds, 1);
        expect(paints, initialPaints);
        expect(tester.binding.transientCallbackCount, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

class _PaintCounter extends CustomPainter {
  _PaintCounter(this.onPaint);
  final VoidCallback onPaint;
  @override
  void paint(Canvas canvas, Size size) => onPaint();
  @override
  bool shouldRepaint(_PaintCounter oldDelegate) => false;
}
