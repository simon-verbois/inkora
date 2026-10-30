import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/l10n/app_strings.dart';
import 'package:inkora/reader/domain/reading_settings.dart';
import 'package:inkora/reader/presentation/ebook_page_frame.dart';
import 'package:inkora/reader/presentation/ebook_page_numbers.dart';
import 'package:inkora/reader/presentation/ebook_settings_controls.dart';
import 'package:inkora/reader/presentation/ebook_presentation.dart';

void main() {
  testWidgets(
    'native reflow refreshes only an active footer and releases its handler',
    (tester) async {
      final messenger = tester.binding.defaultBinaryMessenger;
      var snapshots = 0;
      messenger.setMockMethodCallHandler(EbookPresentation.channel, (_) async {
        snapshots++;
        return '{"pages":[1],"total":$snapshots}';
      });
      addTearDown(
        () =>
            messenger.setMockMethodCallHandler(EbookPresentation.channel, null),
      );
      Future<void> reflow() async {
        final done = Completer<void>();
        messenger.handlePlatformMessage(
          EbookPresentation.channel.name,
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('paginationChanged'),
          ),
          (_) => done.complete(),
        );
        await done.future;
        await tester.pump();
      }

      final controller = EbookPageNumbersController();
      await reflow();
      expect(snapshots, 0);
      controller.refresh();
      await tester.pump();
      expect(controller.value!.total, 1);
      await reflow();
      expect(controller.value!.total, 2);
      controller.hide();
      await reflow();
      expect(snapshots, 2);
      controller.dispose();
      await reflow();
      expect(snapshots, 2);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
  test(
    'page numbers default on and explicit scoped choices survive round trips',
    () {
      expect(const EbookSettings().pageNumbers, isTrue);
      expect(EbookSettings.fromJson({}).pageNumbers, isTrue);
      for (final enabled in [false, true]) {
        final settings = ReadingSettings.resolve([
          ReadingOverrides.fromJson({
            'ebook': {'pageNumbers': !enabled, 'font': 'lato'},
          }),
          ReadingOverrides.fromJson({
            'ebook': {'pageNumbers': enabled},
          }),
        ]);
        expect(settings.ebook.pageNumbers, enabled);
        expect(settings.ebook.font, 'lato');
        expect(EbookSettings.fromJson(settings.ebook.toJson()), settings.ebook);
      }
      expect(
        const EbookSettings(),
        isNot(const EbookSettings(pageNumbers: false)),
      );
    },
  );

  test('pagination validates complete book counts rather than guessing', () {
    expect(
      EbookPagination.decode('{"pages":[123,124],"total":456}'),
      const EbookPagination([123, 124], 456),
    );
    for (final raw in [
      'null',
      '{}',
      '{"pages":[0],"total":5}',
      '{"pages":[6],"total":5}',
      '{"pages":[1,2,3],"total":5}',
      '{"pages":[],"total":5}',
      '{"pages":[1],"total":0}',
    ]) {
      expect(() => EbookPagination.decode(raw), throwsFormatException);
    }
  });

  test(
    'snapshots coalesce, suppress duplicates and discard hidden/stale results',
    () async {
      final requests = <Completer<String?>>[];
      final controller = EbookPageNumbersController(
        snapshot: () {
          final request = Completer<String?>();
          requests.add(request);
          return request.future;
        },
      );
      var emissions = 0;
      controller.addListener(() => emissions++);
      controller.refresh();
      for (var i = 0; i < 20; i++) {
        controller.refresh();
      }
      expect(requests.length, 1);
      requests[0].complete('{"pages":[1],"total":12}');
      await Future<void>.delayed(Duration.zero);
      expect(controller.value, isNull);
      expect(requests.length, 2);
      requests[1].complete('{"pages":[8],"total":12}');
      await Future<void>.delayed(Duration.zero);
      expect(controller.value!.pages, [8]);
      expect(emissions, 1);
      controller.refresh();
      requests[2].complete('{"pages":[8],"total":12}');
      await Future<void>.delayed(Duration.zero);
      expect(emissions, 1);
      controller.refresh();
      controller.hide();
      requests[3].complete('{"pages":[9],"total":12}');
      await Future<void>.delayed(Duration.zero);
      expect(controller.value, isNull);
      controller.refresh();
      controller.dispose();
      requests[4].complete('{"pages":[10],"total":12}');
      await Future<void>.delayed(Duration.zero);
      expect(requests.length, 5);
    },
  );

  test('unavailable native metadata never invents a book total', () async {
    for (final result in [
      () async => null,
      () async => '[]',
      () async => throw PlatformException(code: 'closing'),
    ]) {
      final controller = EbookPageNumbersController(snapshot: result);
      controller.refresh();
      await Future<void>.delayed(Duration.zero);
      expect(controller.value, isNull);
      controller.dispose();
    }
  });

  test('secondary ink remains readable on standard and custom paper', () {
    for (final rgb in [
      0,
      0xffffff,
      0xf4ecd8,
      0x777777,
      0x303030,
      0x179c65,
      0x473bab,
    ]) {
      final paper = Color(0xff000000 | rgb);
      final ink = ebookPageNumberInk(paper);
      final a = paper.computeLuminance(), b = ink.computeLuminance();
      expect(
        (math.max(a, b) + .05) / (math.min(a, b) + .05),
        greaterThanOrEqualTo(4.5),
      );
      expect(ink, isNot(paper));
    }
  });

  for (final size in [const Size(320, 640), const Size(1024, 768)]) {
    testWidgets(
      'folios reserve zero-margin space and retain the publication at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final numbers = ValueNotifier<EbookPagination?>(
          const EbookPagination([123, 124], 456),
        );
        addTearDown(numbers.dispose);
        var builds = 0, geometries = 0, taps = 0;
        final surface = Builder(
          builder: (_) {
            builds++;
            return const ColoredBox(
              key: Key('native-surface'),
              color: Colors.amber,
            );
          },
        );
        Future<void> mount({bool enabled = true, bool scroll = false}) =>
            tester.pumpWidget(
              MaterialApp(
                home: MediaQuery(
                  data: MediaQueryData(
                    size: size,
                    viewPadding: const EdgeInsets.only(bottom: 20),
                    textScaler: const TextScaler.linear(2),
                  ),
                  child: GestureDetector(
                    onTap: () => taps++,
                    behavior: HitTestBehavior.opaque,
                    child: EbookPageFrame(
                      settings: EbookSettings(
                        pageNumbers: enabled,
                        scroll: scroll,
                        pageInsets: const EbookPageInsets(
                          left: 0,
                          top: 0,
                          right: 0,
                          bottom: 0,
                        ),
                      ),
                      paper: Colors.white,
                      numbers: numbers,
                      onGeometryChanged: () => geometries++,
                      child: surface,
                    ),
                  ),
                ),
              ),
            );
        await mount();
        await tester.pump();
        final native = tester.getRect(find.byKey(const Key('native-surface')));
        final first = find.byKey(const ValueKey('ebook-page-number-0'));
        final second = find.byKey(const ValueKey('ebook-page-number-1'));
        expect(find.text('123 / 456'), findsOneWidget);
        expect(tester.getCenter(first).dx, closeTo(size.width / 4, 1));
        expect(tester.getCenter(second).dx, closeTo(size.width * 3 / 4, 1));
        expect(tester.getRect(first).top, greaterThanOrEqualTo(native.bottom));
        expect(
          tester.getRect(first).bottom,
          lessThanOrEqualTo(size.height - 20),
        );
        final before = builds, beforeGeometry = geometries;
        numbers.value = const EbookPagination([125, 126], 456);
        await tester.pump();
        expect(builds, before);
        expect(geometries, beforeGeometry);
        expect(find.text('125 / 456'), findsOneWidget);
        await tester.tapAt(tester.getCenter(first));
        expect(taps, 1);
        numbers.value = const EbookPagination([125], 456);
        await tester.pump();
        expect(tester.getCenter(first).dx, closeTo(size.width / 2, 1));
        await mount(enabled: false);
        expect(first, findsNothing);
        expect(
          tester.getRect(find.byKey(const Key('native-surface'))).bottom,
          size.height - 20,
        );
        await mount(scroll: true);
        expect(first, findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final locale in AppStrings.supportedLocales) {
    testWidgets('page number switch toggles at 320 dp/200% in $locale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var settings = const EbookSettings();
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          supportedLocales: AppStrings.supportedLocales,
          localizationsDelegates: const [
            AppStrings.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 800),
              textScaler: TextScaler.linear(2),
            ),
            child: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) => SingleChildScrollView(
                  child: EbookSettingsControls(
                    section: EbookControlsSection.layout,
                    settings: settings,
                    onChanged: (key, value) => setState(
                      () => settings = EbookSettings.fromJson({
                        ...settings.toJson(),
                        key: value,
                      }),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final toggle = find.widgetWithText(
        SwitchListTile,
        AppStrings(locale.languageCode).text('Page numbers'),
      );
      await tester.ensureVisible(toggle);
      expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(settings.pageNumbers, isFalse);
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  }
}
