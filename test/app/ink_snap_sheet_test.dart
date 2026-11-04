import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/l10n/app_strings.dart';
import 'package:inkora/app/theme/inkora_theme.dart';
import 'package:inkora/app/widgets/inkora_widgets.dart';

import '../support/onboarding_visuals.dart';

void main() {
  for (final size in [
    const Size(390, 844),
    const Size(1280, 800),
    const Size(844, 390),
  ]) {
    for (final reduced in [false, true]) {
      testWidgets(
        'full-width popup snaps without recreating content at $size/reduced=$reduced',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          tester.view.padding = FakeViewPadding(top: 24, bottom: 24);
          tester.view.viewPadding = FakeViewPadding(top: 24, bottom: 24);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPadding);
          addTearDown(tester.view.resetViewPadding);
          await tester.runAsync(loadOnboardingFonts);
          final scroll = ScrollController();
          addTearDown(scroll.dispose);
          var builds = 0;
          late BuildContext owner;
          const capture = Key('snap-sheet-capture');
          await tester.pumpWidget(
            RepaintBoundary(
              key: capture,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                locale: const Locale('fr'),
                supportedLocales: AppStrings.supportedLocales,
                localizationsDelegates: const [
                  AppStrings.delegate,
                  ...GlobalMaterialLocalizations.delegates,
                ],
                theme: InkoraTheme.dark(),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(disableAnimations: reduced),
                  child: child!,
                ),
                home: Builder(
                  builder: (context) {
                    owner = context;
                    return const Scaffold(
                      body: Center(child: Text('Underlying page')),
                    );
                  },
                ),
              ),
            ),
          );
          final completion = showInkPopup<String>(
            context: owner,
            title: 'Filters',
            child: Builder(
              builder: (_) {
                builds++;
                return Column(
                  children: [
                    const TextField(key: Key('snap-draft')),
                    Expanded(
                      child: ListView(
                        controller: scroll,
                        children: [
                          for (var i = 0; i < 80; i++)
                            ListTile(title: Text('Option $i')),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          );
          await tester.pumpAndSettle();
          final surface = find.byKey(const Key('ink-sheet-surface'));
          final handle = find.byKey(const Key('ink-sheet-handle'));
          final first = tester.getRect(surface);
          expect(first.left, 0);
          expect(first.right, size.width);
          expect(first.bottom, size.height);
          expect(tester.getSize(handle).height, greaterThanOrEqualTo(48));
          await tester.enterText(
            find.byKey(const Key('snap-draft')),
            'Retained draft',
          );
          final field = tester.element(find.byKey(const Key('snap-draft')));
          if (size.width == 390) {
            tester.view.viewInsets = FakeViewPadding(bottom: 260);
            addTearDown(tester.view.resetViewInsets);
            await tester.pumpAndSettle();
            expect(
              tester.getRect(surface).bottom,
              closeTo(size.height - 260, 1),
            );
            expect(find.text('Retained draft'), findsOneWidget);
            tester.view.resetViewInsets();
            await tester.pumpAndSettle();
          }
          scroll.jumpTo(150);
          await tester.pumpAndSettle();
          if (size.height > 480 && !reduced) {
            await captureOnboarding(
              tester,
              find.byKey(capture),
              'popup-medium-${size.width.toInt()}-fr',
            );
          }
          await tester.drag(handle, Offset(0, -size.height * .55));
          await tester.pumpAndSettle();
          final full = tester.getRect(surface);
          expect(full.top, closeTo(24, 1));
          expect(full.bottom, size.height);
          expect(builds, 1);
          expect(
            tester.element(find.byKey(const Key('snap-draft'))),
            same(field),
          );
          expect(find.text('Retained draft'), findsOneWidget);
          expect(scroll.offset, 150);
          if (size.height > 480 && !reduced) {
            await captureOnboarding(
              tester,
              find.byKey(capture),
              'popup-full-${size.width.toInt()}-fr',
            );
          }
          // Tap is an accessible alternative to dragging the grip.
          await tester.tap(handle);
          await tester.pumpAndSettle();
          if (size.height > 480) {
            expect(tester.getRect(surface).top, closeTo(first.top, 1));
          } else {
            expect(tester.getRect(surface).top, greaterThan(first.top));
          }
          expect(builds, 1);
          final semantics = tester.ensureSemantics();
          tester.semantics.increase(
            find.semantics.byLabel(AppStrings('fr').text('Show more')),
          );
          await tester.pumpAndSettle();
          expect(tester.getRect(surface).top, closeTo(24, 1));
          tester.semantics.decrease(
            find.semantics.byLabel(AppStrings('fr').text('Show less')),
          );
          await tester.pumpAndSettle();
          expect(tester.getRect(surface).top, greaterThan(24));
          semantics.dispose();
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(await completion, isNull);
          expect(surface, findsNothing);
          expect(tester.binding.transientCallbackCount, 0);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
