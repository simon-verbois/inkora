import 'package:inkora/reader/presentation/ebook_font_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/l10n/app_strings.dart';
import 'package:inkora/reader/domain/ebook_settings.dart';
import 'package:inkora/reader/presentation/ebook_settings_controls.dart';
import 'package:inkora/reader/presentation/ebook_margins_dialog.dart';
import 'package:inkora/reader/presentation/ebook_page_insets.dart';

void main() {
  test('publication bounds land on physical pixels for fractional margins and densities', () {
    for (final ratio in [1.0, 1.25, 1.5, 2.125, 2.75, 3.0]) {
      for (final margin in [1.0, 1.1, 1.3, 1.65]) {
        final settings = EbookSettings(margins: margin);
        final raw = ebookPublicationInsets(
          settings,
          const EdgeInsets.only(top: 23.529),
          const Size(1024, 768),
        );
        final aligned = ebookPublicationInsets(
          settings,
          const EdgeInsets.only(top: 23.529),
          const Size(1024, 768),
          devicePixelRatio: ratio,
        );
        for (final pair in [
          (aligned.left, raw.left),
          (aligned.top, raw.top),
          (aligned.right, raw.right),
          (aligned.bottom, raw.bottom),
        ]) {
          expect(
            pair.$1 * ratio,
            closeTo((pair.$1 * ratio).roundToDouble(), 1e-8),
          );
          expect(pair.$1, greaterThanOrEqualTo(pair.$2 - 1e-8));
          expect(pair.$1 - pair.$2, lessThan(1 / ratio + 1e-8));
        }
      }
    }
  });

  for (final locale in AppStrings.supportedLocales) {
    for (final size in [const Size(320, 640), const Size(1024, 768)]) {
      testWidgets(
        'font dropdown fits and selects all families at $locale/$size/200%',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          var settings = const EbookSettings();
          final changes = <String>[];
          await tester.pumpWidget(
            MaterialApp(
              locale: locale,
              supportedLocales: AppStrings.supportedLocales,
              localizationsDelegates: const [
                AppStrings.delegate,
                ...GlobalMaterialLocalizations.delegates,
              ],
              home: MediaQuery(
                data: MediaQueryData(
                  size: size,
                  textScaler: const TextScaler.linear(2),
                ),
                child: Scaffold(
                  body: StatefulBuilder(
                    builder: (context, setState) => SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: EbookSettingsControls(
                          section: EbookControlsSection.typography,
                          settings: settings,
                          onChanged: (key, value) {
                            expect(key, 'font');
                            changes.add(value as String);
                            setState(
                              () => settings = EbookSettings.fromJson({
                                ...settings.toJson(),
                                key: value,
                              }),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          final dropdown = find.byType(EbookFontPicker);
          for (final font in EbookFont.values) {
            await tester.ensureVisible(dropdown);
            await tester.tap(find.byKey(const Key('ebook-font-picker')));
            await tester.pumpAndSettle();
            final option = find.byKey(ValueKey('ebook-font-option-${font.id}'));
            final menu = tester.getRect(
              find.ancestor(of: option, matching: find.byType(Material)).first,
            );
            expect(menu.width, lessThanOrEqualTo(340));
            expect(menu.height, lessThanOrEqualTo(320));
            await Scrollable.ensureVisible(
              tester.element(option),
              alignment: .5,
            );
            await tester.pumpAndSettle();
            await tester.tap(option);
            await tester.pumpAndSettle();
            expect(settings.fontChoice, font);
            expect(settings.fontSize, 1.0);
            final field = tester.getRect(dropdown);
            final selectedLabel = tester.getRect(
              find
                  .descendant(
                    of: dropdown,
                    matching: find.text(
                      AppStrings(locale.languageCode).text(font.label),
                    ),
                  )
                  .first,
            );
            expect(selectedLabel.top, greaterThanOrEqualTo(field.top));
            expect(selectedLabel.bottom, lessThanOrEqualTo(field.bottom));
            expect(tester.takeException(), isNull);
          }
          expect(
            changes,
            EbookFont.values.skip(1).map((font) => font.id).toList(),
          );
          expect(find.byKey(const ValueKey('ebook-fontSize')), findsNothing);
          // An external template/scope change updates the selected value too.
          final current = tester.widget<EbookFontPicker>(dropdown);
          expect(current.font, EbookFont.ptSerif);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }

  for (final locale in AppStrings.supportedLocales) {
    for (final size in [const Size(320, 640), const Size(1024, 768)]) {
      testWidgets('ebook tap option toggles at $locale/$size/200%', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var settings = const EbookSettings();
        final changes = <(String, Object)>[];
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            supportedLocales: AppStrings.supportedLocales,
            localizationsDelegates: const [
              AppStrings.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: const TextScaler.linear(2),
              ),
              child: Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) => SingleChildScrollView(
                    child: EbookSettingsControls(
                      settings: settings,
                      section: EbookControlsSection.navigation,
                      onChanged: (key, value) {
                        changes.add((key, value));
                        setState(
                          () => settings = EbookSettings.fromJson({
                            ...settings.toJson(),
                            key: value,
                          }),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final label = AppStrings(locale.languageCode).text('Tap to turn pages');
        final text = find.text(label);
        await tester.ensureVisible(text);
        await tester.pumpAndSettle();
        expect(text.hitTestable(), findsOneWidget);
        expect(settings.tapToTurnPages, isFalse);
        await tester.tap(text);
        await tester.pumpAndSettle();
        expect(settings.tapToTurnPages, isTrue);
        await tester.tap(text);
        await tester.pumpAndSettle();
        expect(settings.tapToTurnPages, isFalse);
        expect(changes, [('tapToTurnPages', true), ('tapToTurnPages', false)]);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
  test(
    'legacy spacing, camera safe areas and custom edges survive rotation',
    () {
      final legacy = EbookSettings.fromJson({'margins': 1.5});
      expect(legacy.pageInsets, isNull);
      expect(
        ebookPublicationInsets(
          legacy,
          const EdgeInsets.only(top: 32),
          const Size(390, 844),
        ),
        const EdgeInsets.fromLTRB(0, 68, 0, 36),
      );
      final settings = EbookSettings.fromJson({
        'pageInsets': {'left': 0, 'top': 0, 'right': 160, 'bottom': 160},
      });
      expect(EbookSettings.fromJson(settings.toJson()), settings);
      final insets = ebookPublicationInsets(
        settings,
        const EdgeInsets.only(left: 36, bottom: 24),
        const Size(844, 320),
      );
      expect(insets.left, 36);
      expect(insets.top, 0);
      expect(insets.right, 160);
      expect(insets.bottom, closeTo(112.8, .01));
      expect(
        () => EbookSettings.fromJson({
          'pageInsets': {'left': -1, 'top': 0, 'right': 0, 'bottom': 0},
        }),
        throwsFormatException,
      );
    },
  );

  for (final size in [const Size(320, 640), const Size(1024, 768)]) {
    testWidgets(
      'ebook margins are a cancellable four-edge draft at $size / 200%',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final changes = <(String, Object)>[];
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: const TextScaler.linear(2),
              ),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: EbookSettingsControls(
                      settings: const EbookSettings(),
                      onChanged: (key, value) => changes.add((key, value)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final slider = find.byType(Slider).first;
        await tester.ensureVisible(slider);
        final gesture = await tester.startGesture(tester.getCenter(slider));
        await gesture.moveBy(const Offset(30, 0));
        await tester.pump();
        expect(changes, isEmpty);
        await gesture.up();
        await tester.pump();
        expect(changes.single.$1, 'lineHeight');
        changes.clear();
        final picker = find.byKey(const Key('ebook-margin-picker'));
        await tester.ensureVisible(picker);
        await tester.tap(picker);
        await tester.pumpAndSettle();
        expect(find.byType(EbookMarginsDialog), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('margin-device-true')));
        final preset = find.byKey(const ValueKey('margin-preset-1.5'));
        await tester.ensureVisible(preset);
        await tester.tap(preset);
        await tester.pumpAndSettle();
        expect(changes, isEmpty);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(changes, isEmpty);
        await tester.tap(picker);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('margin-device-false')));
        for (final edge in ['top', 'bottom', 'left', 'right']) {
          final control = find.byKey(ValueKey('ebook-margin-$edge'));
          await tester.ensureVisible(control);
          await tester.pumpAndSettle();
          final slider = tester.widget<Slider>(control);
          slider.onChanged!(37);
          await tester.pump();
          expect(changes, isEmpty);
          slider.onChangeEnd!(37);
          await tester.pump();
        }
        await tester.tap(find.byKey(const Key('ebook-margins-save')));
        await tester.pumpAndSettle();
        expect(changes.single.$1, 'pageInsets');
        expect(changes.single.$2, {
          'left': 37.0,
          'top': 37.0,
          'right': 37.0,
          'bottom': 37.0,
        });
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('margin dialog fits every locale at 200% on a narrow phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final locale in AppStrings.supportedLocales) {
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
              size: Size(320, 640),
              textScaler: TextScaler.linear(2),
            ),
            child: const Scaffold(
              body: EbookMarginsDialog(settings: EbookSettings()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(AppStrings(locale.languageCode).text('Phone')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
  });
}
