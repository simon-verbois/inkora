import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/core/storage/app_database.dart';
import 'package:inkora/reader/data/reader_store.dart';
import 'package:inkora/reader/domain/reading_settings.dart';
import 'package:inkora/reader/presentation/reader_settings_sheet.dart';

import '../../support/reader_widget_support.dart';

void main() {
  testWidgets('webtoon quality presets and custom sliders persist', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 2560);
    tester.view.devicePixelRatio = 2.125;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final store = ReaderStore(database, 'reader-account');
    Future<void> settle() async {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await settleReaderImages(tester);
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) =>
                    ReaderSettingsSheet(store: store, qualityOnly: true),
              ),
              child: const Text('Preferences'),
            ),
          ),
        ),
      ),
    );
    Future<void> open() async {
      await tester.tap(find.text('Preferences'));
      await settle();
      await tester.tap(find.text('Preloading'));
      await settle();
    }

    await open();
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const Key('webtoon-quality-sharp')))
          .selected,
      isTrue,
    );
    expect(find.byKey(const Key('webtoon-sharpness')), findsNothing);
    // With no book selected, the estimate reserves long strips at both edges.
    expect(find.textContaining('75 % sharpness'), findsOneWidget);
    expect(find.textContaining('(limited by memory)'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('webtoon-quality-custom')));
    await tester.tap(find.byKey(const Key('webtoon-quality-custom')));
    await settle();
    for (final key in ['sharpness', 'preload', 'memory']) {
      expect(find.byKey(Key('webtoon-$key')), findsOneWidget);
    }
    tester
        .widget<Slider>(find.byKey(const Key('webtoon-sharpness')))
        .onChangeEnd!(.95);
    tester.widget<Slider>(find.byKey(const Key('webtoon-memory'))).onChangeEnd!(
      96,
    );
    await settle();
    expect(find.text('95 %'), findsOneWidget);
    expect(find.text('96 MiB'), findsOneWidget);

    // Live: the slider commits are already stored; closing needs no Save.
    expect(find.text('Save'), findsNothing);
    await tester.binding.handlePopRoute();
    await settle();
    final saved = (await tester.runAsync(
      () => store.preferenceLayers(),
    ))![SettingsScope.global]!;
    expect(saved.webtoonQuality, WebtoonQuality.custom);
    expect(saved.webtoonSharpness, .95);
    expect(saved.webtoonMemoryMiB, 96);

    await open();
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const Key('webtoon-quality-custom')))
          .selected,
      isTrue,
    );
    expect(find.text('95 %'), findsOneWidget);
  });
}
