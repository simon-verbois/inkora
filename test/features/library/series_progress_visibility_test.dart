import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/router.dart';
import 'package:inkora/features/library/application/catalogue_providers.dart';
import 'package:inkora/core/storage/app_database.dart';
import 'package:inkora/features/settings/domain/ui_preferences.dart';
import 'package:inkora/offline/data/progress_store.dart';
import 'package:inkora/offline/domain/progress.dart';

import '../../support/connection_fakes.dart';
import '../../support/ui_harness.dart';
import 'series_detail_widget_test.dart' show seedSeries;

/// Counts executions of the series device-progress query.
class _ProgressQueries extends QueryInterceptor {
  int count = 0;

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    if (statement.contains('LEFT JOIN progress_heads h')) count++;
    return super.runSelect(executor, statement, args);
  }
}

void main() {
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pumpAndSettle();
    }
  }

  Future<void> mark(UiHarness harness, WidgetTester tester, String book) =>
      tester.runAsync(
        () => ProgressStore(
          harness.database,
          savedSession.accountId,
        ).mark([ProgressMark(bookId: book, pageCount: 30)], read: true),
      );

  testWidgets(
    'a series page covered by the reader does not re-query per progress write',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final queries = _ProgressQueries();
      final harness = await UiHarness.create(
        tester,
        preferences: const UiPreferences(locale: 'en'),
        resumeEntries: const [],
        refreshCatalogue: false,
        databaseOverride: AppDatabase(
          NativeDatabase.memory().interceptWith(queries),
        ),
      );
      addTearDown(() => harness.close(tester));
      await seedSeries(harness, tester);
      await harness.mount(tester);
      final router = harness.container.read(routerProvider);
      router.push('/catalogue/series/series-a');
      await settle(tester);
      expect(
        harness.container
            .read(seriesProgressProvider('series-a'))
            .requireValue
            .readCount,
        2,
      );

      // Visible: a write is reflected through one re-query.
      var before = queries.count;
      await mark(harness, tester, 'v4');
      await settle(tester);
      expect(queries.count, before + 1);
      expect(
        harness.container
            .read(seriesProgressProvider('series-a'))
            .requireValue
            .readCount,
        3,
      );

      // Covered by the root reader: page saves do not wake the query.
      router.push('/catalogue/series/series-a/read/v5');
      await settle(tester);
      before = queries.count;
      await mark(harness, tester, 'v5');
      await settle(tester);
      await mark(harness, tester, 'v6');
      await settle(tester);
      expect(queries.count, before);

      // Revealed: one refresh shows both writes.
      router.pop();
      await settle(tester);
      expect(queries.count, before + 1);
      expect(
        harness.container
            .read(seriesProgressProvider('series-a'))
            .requireValue
            .readCount,
        5,
      );
      await harness.close(tester);
    },
  );
}
