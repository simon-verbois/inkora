import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:inkora/app/l10n/app_strings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:inkora/reader/domain/reader_manifest.dart';
import 'package:inkora/reader/presentation/reader_details.dart';
import 'package:inkora/features/library/presentation/series_header.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../support/reader_fakes.dart';
import '../../support/ui_harness.dart';

void main() {
  for (final locale in languageNames.keys) {
    testWidgets('ebook author label preserves the series shortcut at $locale', (
      tester,
    ) async {
      for (final type in ['application/epub+zip', 'application/pdf', null]) {
        final manifest = ReaderManifest(
          accountId: 'fixture',
          bookId: 'book',
          revision: 'r',
          title: 'Book',
          seriesId: 'author',
          documentType: type,
          pages: [PageDimensions(1, 1)],
        );
        final router = GoRouter(
          initialLocation: '/reader/book',
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => const Scaffold(body: Text('Home')),
            ),
            GoRoute(
              name: 'reader',
              path: '/reader/:id',
              builder: (_, _) =>
                  Scaffold(body: ReaderSeriesButton(manifest: manifest)),
            ),
            GoRoute(
              name: 'reader-parent',
              path: '/reader-parent/:id',
              builder: (_, state) => Scaffold(
                body: Text('Destination: ${state.pathParameters['id']}'),
              ),
            ),
          ],
        );
        await tester.pumpWidget(
          MaterialApp.router(
            routerConfig: router,
            locale: AppStrings.localeFor(locale),
            supportedLocales: AppStrings.supportedLocales,
            localizationsDelegates: const [
              AppStrings.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
          ),
        );
        await tester.pumpAndSettle();
        final label = AppStrings(locale)
            .text(type == null ? 'Series' : 'Author');
        expect(find.text(label), findsOneWidget);
        await tester.tap(find.byKey(const Key('reader-series')));
        await tester.pumpAndSettle();
        expect(find.text('Destination: author'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
        router.dispose();
      }
    });
  }

  for (final coveredSeries in [false, true]) {
    testWidgets(
      'series shortcut preserves route history (covered $coveredSeries)',
      (tester) async {
        final manifest = readerManifest();
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => const Scaffold(body: Text('Home')),
            ),
            GoRoute(
              path: '/reader/:id',
              name: 'reader',
              builder: (_, _) =>
                  Scaffold(body: ReaderSeriesButton(manifest: manifest)),
            ),
            GoRoute(
              path: '/catalogue/:kind/:id',
              name: 'catalogue-detail',
              builder: (_, _) => const Scaffold(body: Text('Series page')),
              routes: [
                GoRoute(
                  path: 'read/:bookId',
                  name: 'series-reader',
                  builder: (_, _) =>
                      Scaffold(body: ReaderSeriesButton(manifest: manifest)),
                ),
              ],
            ),
            GoRoute(
              name: 'reader-parent',
              path: '/reader-parent/:id',
              builder: (_, _) => const Scaffold(body: Text('Parent page')),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        if (coveredSeries) {
          router.push<void>('/catalogue/series/series');
          await tester.pumpAndSettle();
          router.push<void>('/catalogue/series/series/read/reader-book');
        } else {
          router.push<void>('/reader/reader-book');
        }
        await tester.pumpAndSettle();
        final readerElement = tester.element(find.byType(ReaderSeriesButton));
        await tester.tap(find.byKey(const Key('reader-series')));
        await tester.pumpAndSettle();
        expect(find.text('Parent page'), findsOneWidget);
        router.pop();
        await tester.pumpAndSettle();
        expect(
          tester.element(find.byType(ReaderSeriesButton)),
          same(readerElement),
        );
        router.pop();
        await tester.pumpAndSettle();
        if (coveredSeries) {
          expect(find.text('Series page'), findsOneWidget);
          router.pop();
          await tester.pumpAndSettle();
        }
        expect(find.text('Home'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  for (final size in [const Size(320, 640), const Size(1024, 768)]) {
    testWidgets('ebook facts use saved book metadata at $size and 200% text', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final harness = await UiHarness.create(tester);
      addTearDown(() => harness.close(tester));
      final manifest = ReaderManifest(
        accountId: harness.repository.store.accountId,
        bookId: 'book-a',
        revision: 'r1',
        title: 'Fallback title',
        documentType: 'application/epub+zip',
        pages: [PageDimensions(1, 1)],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: harness.container,
          child: MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: const TextScaler.linear(2),
              ),
              child: Scaffold(body: ReaderBookDetails(manifest: manifest)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Book details'), findsOneWidget);
      expect(find.text('Moonlit District · Volume 3'), findsOneWidget);
      expect(find.text('Fallback title'), findsNothing);
      expect(find.byType(SeriesHero), findsNothing);
      expect(tester.takeException(), isNull);
      await harness.close(tester);
    });
  }
}
