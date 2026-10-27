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

Finder readerSheetHandle(WidgetTester tester) {
  final context = tester.element(find.byType(BottomSheet).last);
  final label = MaterialLocalizations.of(context).modalBarrierDismissLabel;
  return find
      .byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.button == true &&
            widget.properties.label == label &&
            widget.properties.onTap != null,
      )
      .last;
}

void registerReaderSheetGestureTests() {
  for (final size in [const Size(390, 844), const Size(1280, 800)]) {
    testWidgets(
      'reader sheet dismisses only from its handle and keeps Back at $size',
      (tester) async {
        final context = await _pump(tester, size);
        var scrolls = 0;
        var sliderValue = .5;
        var sliderChanges = 0;
        showInkSheet<void>(
          context: context,
          title: 'Reading preferences',
          heightFactor: .65,
          child: NotificationListener<ScrollNotification>(
            onNotification: (_) {
              scrolls++;
              return false;
            },
            child: ListView(
              children: [
                StatefulBuilder(
                  builder: (_, update) => Slider(
                    key: const Key('sheet-slider-fixture'),
                    value: sliderValue,
                    onChanged: (value) => update(() {
                      sliderValue = value;
                      sliderChanges++;
                    }),
                  ),
                ),
                for (var i = 0; i < 60; i++)
                  SizedBox(height: 48, child: Text('Option $i')),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();
        final panel = find.byType(InkOverlaySurface);
        final original = tester.getRect(panel);
        await tester.drag(
          find.byKey(const Key('sheet-slider-fixture')),
          const Offset(60, 0),
        );
        await tester.pumpAndSettle();
        expect(sliderChanges, greaterThan(0));
        await tester.fling(
          find.byKey(const Key('sheet-slider-fixture')),
          const Offset(0, 150),
          1200,
        );
        await tester.pumpAndSettle();
        expect(tester.getRect(panel), original);
        await tester.fling(
          find.text('Reading preferences'),
          Offset(0, size.height * .6),
          1500,
        );
        await tester.pumpAndSettle();
        expect(tester.getRect(panel), original);
        await tester.fling(find.byType(ListView), const Offset(0, -220), 1200);
        await tester.pumpAndSettle();
        expect(scrolls, greaterThan(0));
        await tester.fling(find.byType(ListView), const Offset(0, 800), 1500);
        await tester.pumpAndSettle();
        expect(tester.getRect(panel), original);
        await tester.tapAt(const Offset(4, 4));
        await tester.pumpAndSettle();
        expect(panel, findsOneWidget);
        final handle = readerSheetHandle(tester);
        expect(tester.getSize(handle).width, greaterThanOrEqualTo(48));
        expect(tester.getSize(handle).height, greaterThanOrEqualTo(48));
        // A cancelled handle pull settles back rather than closing the route.
        final gesture = await tester.startGesture(tester.getCenter(handle));
        await gesture.moveBy(const Offset(0, 30));
        await tester.pump(const Duration(milliseconds: 100));
        await gesture.moveBy(const Offset(0, 30));
        await tester.pump();
        expect(tester.getRect(panel).top, greaterThan(original.top));
        await gesture.cancel();
        await tester.pumpAndSettle();
        expect(panel, findsOneWidget);
        expect(tester.getRect(panel).top, closeTo(original.top, 1));
        await tester.fling(
          readerSheetHandle(tester),
          Offset(0, size.height * .7),
          1500,
        );
        await tester.pumpAndSettle();
        expect(panel, findsNothing);
        showInkSheet<void>(context: context, child: const Text('Back fixture'));
        await tester.pumpAndSettle();
        final accepted = await _backEvent(tester, 'startBackGesture');
        if (accepted == true) {
          await _backEvent(tester, 'updateBackGestureProgress');
          await _backEvent(tester, 'cancelBackGesture');
          await tester.pumpAndSettle();
          expect(find.text('Back fixture'), findsOneWidget);
          await _backEvent(tester, 'startBackGesture');
          await _backEvent(tester, 'updateBackGestureProgress');
          await _backEvent(tester, 'commitBackGesture');
        } else {
          await tester.binding.handlePopRoute();
        }
        await tester.pumpAndSettle();
        expect(find.text('Back fixture'), findsNothing);
      },
    );
  }
}

void main() {
  registerReaderSheetGestureTests();
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
      final handle = readerSheetHandle(tester);
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
