import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/theme/inkora_theme.dart';
import 'package:inkora/app/widgets/ink_surface.dart';
import 'package:inkora/app/widgets/inkora_widgets.dart';

Future<Object?> _backEvent(WidgetTester tester, String method) async {
  final channel = SystemChannels.backGesture;
  final response = await tester.binding.defaultBinaryMessenger
      .handlePlatformMessage(
        channel.name,
        channel.codec.encodeMethodCall(
          MethodCall(method, {
            'touchOffset': [0.0, 300.0],
            'progress': method == 'updateBackGestureProgress' ? .4 : 0.0,
            'swipeEdge': 0,
          }),
        ),
        null,
      );
  return response == null ? null : channel.codec.decodeEnvelope(response);
}

Future<BuildContext> _pump(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  late BuildContext captured;
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: InkoraTheme.forest(),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              captured = context;
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    ),
  );
  return captured;
}

void main() {
  for (final size in [const Size(390, 844), const Size(1280, 800)]) {
    testWidgets('one sheet presentation with title, action, footer at $size', (
      tester,
    ) async {
      final context = await _pump(tester, size);
      showInkSheet<void>(
        context: context,
        title: 'Reading progress',
        action: TextButton(onPressed: () {}, child: const Text('Reset')),
        footer: FilledButton(onPressed: () {}, child: const Text('Apply')),
        scrollable: true,
        child: Column(children: [for (var i = 0; i < 60; i++) Text('Row $i')]),
      );
      await tester.pumpAndSettle();
      expect(find.byType(InkSheetHeader), findsOneWidget);
      // Header and footer stay visible while the long body scrolls.
      expect(find.text('Reading progress').hitTestable(), findsOneWidget);
      expect(find.text('Apply').hitTestable(), findsOneWidget);
      expect(
        tester.getSize(find.byType(InkOverlaySurface)).height,
        lessThanOrEqualTo(size.height * .85),
      );
      // Predictive back (start, update, commit) closes the sheet. When the
      // framework declines the gesture, Android delivers a system back.
      final accepted = await _backEvent(tester, 'startBackGesture');
      if (accepted == true) {
        await _backEvent(tester, 'updateBackGestureProgress');
        await tester.pump();
        await _backEvent(tester, 'commitBackGesture');
      } else {
        await tester.binding.handlePopRoute();
      }
      await tester.pumpAndSettle();
      expect(find.byType(InkSheetHeader), findsNothing);

      showInkSheet<void>(
        context: context,
        heightFactor: .5,
        child: const Text('Fixed'),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(InkOverlaySurface)).height,
        moreOrLessEquals(size.height * .5),
      );
      final handle = find.byKey(const Key('ink-sheet-handle'));
      expect(handle.hitTestable(), findsOneWidget);
      await tester.fling(handle, Offset(0, size.height * .7), 1500);
      await tester.pumpAndSettle();
      expect(find.text('Fixed'), findsNothing);
    });

    testWidgets('confirmInk and notifyInk at $size', (tester) async {
      final context = await _pump(tester, size);
      var result = confirmInk(
        context,
        title: 'Clear history?',
        message: 'Books opened on this device are removed from this list. Reading progress and bookmarks are kept, and books with reading progress on Komga stay listed.',
        confirmLabel: 'Clear history',
        destructive: true,
      );
      await tester.pumpAndSettle();
      expect(find.byType(InkDialog), findsOneWidget);
      final accept = tester.widget<FilledButton>(
        find.byKey(const Key('ink-confirm-accept')),
      );
      expect(
        accept.style?.backgroundColor?.resolve({}),
        InkoraColors.of(context).danger,
      );
      await tester.tap(find.byKey(const Key('ink-confirm-accept')));
      await tester.pumpAndSettle();
      expect(await result, isTrue);

      result = confirmInk(
        context,
        title: 'Clear history?',
        message: 'Books opened on this device are removed from this list. Reading progress and bookmarks are kept, and books with reading progress on Komga stay listed.',
        confirmLabel: 'Clear history',
      );
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(await result, isFalse);

      var retried = false;
      notifyInk(
        context,
        'Unable to clear history.',
        actionLabel: 'Retry',
        onAction: () => retried = true,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Unable to clear history.'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(retried, isTrue);
    });
  }
}
