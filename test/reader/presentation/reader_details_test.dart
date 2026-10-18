import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:inkora/reader/domain/reader_manifest.dart';
import 'package:inkora/reader/presentation/reader_details.dart';
import 'package:inkora/features/library/presentation/catalogue_detail_widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../support/reader_fakes.dart';
import '../../support/ui_harness.dart';

void main() {
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
                  Scaffold(body: ReaderDetailsButton(manifest: manifest)),
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
                      Scaffold(body: ReaderDetailsButton(manifest: manifest)),
                ),
              ],
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
        await tester.tap(find.byKey(const Key('reader-details')));
        await tester.pumpAndSettle();
        expect(find.text('Series page'), findsOneWidget);
        router.pop();
        await tester.pumpAndSettle();
        expect(find.text('Home'), findsOneWidget);
        expect(find.byType(ReaderDetailsButton), findsNothing);
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
      expect(find.byType(CatalogueDetailHeader), findsNothing);
      expect(tester.takeException(), isNull);
      await harness.close(tester);
    });
  }
}
