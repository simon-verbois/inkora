import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/core/storage/app_database.dart';
import 'package:inkora/reader/data/reader_store.dart';
import 'package:inkora/reader/domain/reading_settings.dart';
import 'package:inkora/reader/presentation/reader_settings_sheet.dart';

import '../../support/reader_fakes.dart';

void main() {
  for (final (size, scale) in [
    (const Size(390, 844), 1.0),
    (const Size(1024, 768), 1.0),
    (const Size(320, 640), 2.0),
  ]) {
    testWidgets(
      'library apply button saves edited values and replaces book tuning at $size/$scale',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final database = AppDatabase(NativeDatabase.memory());
        addTearDown(database.close);
        final store = ReaderStore(database, 'reader-account');
        final manifest = readerManifest();
        await tester.runAsync(() async {
          await store.saveManifest(manifest);
          await store.saveOverrides(
            SettingsScope.book,
            manifest.bookId,
            const ReadingOverrides(mode: ReadingMode.manga),
          );
        });
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => ReaderSettingsSheet(
                        store: store,
                        libraryId: 'library',
                      ),
                    ),
                    child: const Text('Preferences'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Preferences'));
        await tester.pumpAndSettle();
        final mode = find.byWidgetPredicate(
          (w) =>
              w is DropdownButtonFormField<String> &&
              w.decoration.labelText == 'Mode',
        );
        await tester.ensureVisible(mode);
        await tester.pumpAndSettle();
        await tester.tap(mode);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Webtoon').last);
        await tester.pumpAndSettle();
        expect(find.text('Direction'), findsNothing);
        expect(find.text('Page layout'), findsNothing);
        expect(find.text('Comfortable width'), findsOneWidget);
        final apply = find.byKey(const Key('apply-library-defaults'));
        await tester.ensureVisible(apply);
        await tester.pumpAndSettle();
        await tester.tap(apply);
        await tester.pumpAndSettle();
        final settings = await tester.runAsync(
          () => store.settings(manifest).first,
        );
        expect(settings!.mode, ReadingMode.webtoon);
        expect(settings.fit, ReadingFit.comfort);
        expect(find.byType(ReaderSettingsSheet), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
