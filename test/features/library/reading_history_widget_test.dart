import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:inkora/app/l10n/app_strings.dart';
import 'package:inkora/core/storage/app_database.dart';
import 'package:inkora/features/connection/application/session_controller.dart';
import 'package:inkora/features/library/application/catalogue_providers.dart';
import 'package:inkora/features/library/application/cover_providers.dart';
import 'package:inkora/features/library/application/reading_history_providers.dart';
import 'package:inkora/features/library/data/catalogue_store.dart';
import 'package:inkora/features/library/data/reading_history_repository.dart';
import 'package:inkora/features/library/domain/catalogue_filters.dart';
import 'package:inkora/features/library/domain/reading_history.dart';
import 'package:inkora/features/library/presentation/reading_history_screen.dart';

import '../../support/accessibility.dart';
import 'reading_history_test.dart' show FakeHistoryServer, opened;

HistoryEntry _server(String id, DateTime at, {bool read = false}) =>
    HistoryEntry(
      bookId: id,
      title: 'Server book $id with a long descriptive title',
      at: at.toUtc(),
      source: HistorySource.server,
      seriesId: 'series-$id',
      seriesTitle: 'Series $id',
      number: 1,
      pageCount: 100,
      status: read ? ReadingStatus.completed : ReadingStatus.inProgress,
      ratio: read ? 1 : .29,
    );

Future<void> _mount(
  WidgetTester tester, {
  required List<List<HistoryEntry>> pages,
  List<(String, Duration)> device = const [],
  Size size = const Size(390, 844),
  double scale = 1,
  String locale = 'en',
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final database = AppDatabase(NativeDatabase.memory());
  final now = DateTime.now();
  await tester.runAsync(() async {
    for (final (id, age) in device) {
      await opened(
        database,
        'account',
        id,
        now.subtract(age),
        title: 'Device $id',
      );
    }
  });
  final repository = ReadingHistoryRepository(
    CatalogueStore(database, 'account'),
    fetch: FakeHistoryServer(pages).call,
    isCurrent: () => true,
  );
  await tester.runAsync(repository.refresh);
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const ReadingHistoryScreen()),
      GoRoute(
        name: 'reader',
        path: '/reader/:id',
        builder: (_, state) =>
            Scaffold(body: Text('Reader ${state.pathParameters['id']}')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(Future.value(database)),
        coverRepositoryProvider.overrideWith((ref) async => null),
        resumeEntriesProvider.overrideWith((ref) => Stream.value(const [])),
        readingHistoryRepositoryProvider.overrideWith(
          (ref) async => repository,
        ),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: AppStrings.localeFor(locale),
        supportedLocales: AppStrings.supportedLocales,
        localizationsDelegates: const [
          AppStrings.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
      ),
    ),
  );
  for (var turn = 0; turn < 4; turn++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
  addTearDown(() async {
    repository.close();
    await tester.runAsync(database.close);
  });
}

/// Unmounts inside the test body so drift's stream-closing timers run before
/// the binding verifies that no timer is pending.
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 20));
}

IconButton _clear(WidgetTester tester) =>
    tester.widget<IconButton>(find.byKey(const Key('history-clear')));

void main() {
  final now = DateTime.now();
  for (final size in const [Size(390, 844), Size(1280, 800), Size(800, 1280)]) {
    for (final scale in const [1.0, 2.0]) {
      testWidgets('history groups by day and loads more at $size/$scale', (
        tester,
      ) async {
        await _mount(
          tester,
          size: size,
          scale: scale,
          device: const [
            ('local-today', Duration.zero),
            ('local-old', Duration(days: 20)),
          ],
          pages: [
            [
              _server('yesterday', now.subtract(const Duration(days: 1))),
              _server(
                'week',
                now.subtract(const Duration(days: 3)),
                read: true,
              ),
            ],
            [_server('older', now.subtract(const Duration(days: 30)))],
          ],
        );
        expect(find.text('Today'), findsOneWidget);
        expect(find.text('Yesterday'), findsOneWidget);
        expect(find.text('Device local-today'), findsOneWidget);
        expect(find.text('Series yesterday'), findsOneWidget);
        expect(
          find.textContaining(
            'Server book yesterday with a long descriptive title · 29 % · ',
          ),
          findsOneWidget,
        );
        expect(_clear(tester).onPressed, isNotNull);
        await expectAccessibilityGuidelines(tester, contrast: false);
        final list = find.byKey(const Key('history-list'));
        await tester.scrollUntilVisible(
          find.byKey(const Key('history-load-more')),
          200,
          scrollable: find
              .descendant(of: list, matching: find.byType(Scrollable))
              .first,
        );
        expect(find.text('This week'), findsOneWidget);
        expect(
          find.textContaining(
            'Server book week with a long descriptive title · Read · ',
          ),
          findsOneWidget,
        );
        expect(find.text('Earlier'), findsOneWidget);
        await tester.ensureVisible(find.byKey(const Key('history-load-more')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('history-load-more')));
        for (var turn = 0; turn < 4; turn++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump();
        }
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Series older'),
          200,
          scrollable: find
              .descendant(of: list, matching: find.byType(Scrollable))
              .first,
        );
        expect(find.byKey(const Key('history-load-more')), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Series older'));
        await tester.pumpAndSettle();
        expect(find.text('Reader older'), findsOneWidget);
        await _unmount(tester);
      });
    }
  }

  testWidgets('server-only history keeps Clear disabled', (tester) async {
    await _mount(
      tester,
      pages: [
        [_server('remote', now)],
      ],
    );
    expect(find.text('Series remote'), findsOneWidget);
    expect(_clear(tester).onPressed, isNull);
    await _unmount(tester);
  });

  testWidgets('empty history explains its sources and offers browsing', (
    tester,
  ) async {
    await _mount(tester, pages: [const []], scale: 2);
    expect(find.byKey(const Key('history-empty')), findsOneWidget);
    expect(find.textContaining('reading progress on Komga'), findsOneWidget);
    expect(find.text('Browse catalogue'), findsOneWidget);
    expect(_clear(tester).onPressed, isNull);
    expect(tester.takeException(), isNull);
    await _unmount(tester);
  });

  for (final locale in AppStrings.supportedLocales) {
    testWidgets('history fits ${locale.languageCode} at 390x844/200%', (
      tester,
    ) async {
      await _mount(
        tester,
        scale: 2,
        locale: locale.languageCode,
        device: const [('local', Duration.zero)],
        pages: [
          [
            _server('a', now.subtract(const Duration(days: 2)), read: true),
            _server('b', now.subtract(const Duration(days: 12))),
          ],
          const [],
        ],
      );
      expect(tester.takeException(), isNull);
      await _unmount(tester);
    });
  }
}
