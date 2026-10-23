import '../support/home_navigation.dart';
import 'home_navigation_widget_test.dart' show backEvent;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:inkora/features/library/domain/catalogue.dart';
import 'package:inkora/features/library/domain/catalogue_metadata.dart';
import 'package:inkora/features/library/presentation/catalogue_presentation.dart';

import '../support/catalogue_fakes.dart';

import 'package:inkora/app/router.dart';
import 'package:inkora/features/library/presentation/catalogue_detail_screen.dart';
import 'package:inkora/reader/domain/reader_manifest.dart';
import 'package:inkora/reader/presentation/reader_details.dart';
import 'package:inkora/reader/presentation/reader_screen.dart';

import '../support/ui_harness.dart';

void main() {
  for (final sameBook in [true, false]) {
    testWidgets(
      'reader parent read action returns or replaces a single reader (same $sameBook)',
      (tester) async {
        CatalogueItem book(String id) => CatalogueItem(
          kind: CatalogueKind.book,
          id: id,
          title: id,
          libraryId: 'library-a',
          seriesId: 'author',
          metadata: const CatalogueMetadata(mediaType: 'application/epub+zip'),
        );
        final harness = await UiHarness.create(
          tester,
          resumeEntries: const [],
          catalogue: [
            entry('library-a', kind: CatalogueKind.library),
            entry('author', kind: CatalogueKind.series),
            book('current'),
            book('next'),
          ],
        );
        addTearDown(() => harness.close(tester));
        await harness.mount(tester);
        final router = harness.container.read(routerProvider);
        unawaited(router.push<void>('/reader/current'));
        await tester.pumpAndSettle();
        final original = tester.state(find.byType(ReaderScreen));
        unawaited(
          openReaderSeries(
            tester.element(find.byType(ReaderScreen)),
            ReaderManifest(
              accountId: 'fixture',
              bookId: 'current',
              seriesId: 'author',
              revision: 'one',
              title: 'Book',
              documentType: 'application/epub+zip',
              pages: [PageDimensions(1, 1)],
            ),
          ),
        );
        await tester.pumpAndSettle();
        final parent = find.byType(CatalogueDetailScreen);
        expect(parent, findsOneWidget);
        openBookReader(
          tester.element(parent),
          book(sameBook ? 'current' : 'next'),
        );
        await tester.pumpAndSettle();
        expect(parent, findsNothing);
        expect(find.byType(ReaderScreen, skipOffstage: false), findsOneWidget);
        expect(
          tester.widget<ReaderScreen>(find.byType(ReaderScreen)).bookId,
          sameBook ? 'current' : 'next',
        );
        if (sameBook) {
          expect(tester.state(find.byType(ReaderScreen)), same(original));
        } else {
          expect(original.mounted, isFalse);
        }
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(ReaderScreen), findsNothing);
        expect(find.byKey(const Key('home-header')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await harness.close(tester);
      },
    );
  }

  for (final size in [const Size(390, 844), const Size(1024, 768)]) {
    for (final backFirst in [false, true]) {
      testWidgets(
        'reader series shortcut keeps shell usable at $size (Back $backFirst)',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final harness = await UiHarness.create(tester);
          addTearDown(() => harness.close(tester));
          await harness.mount(tester);
          final router = harness.container.read(routerProvider);
          // Visit nested settings before opening the root reader from Home.
          router.go('/settings/appearance');
          await tester.pumpAndSettle();
          router.go('/');
          await tester.pumpAndSettle();
          unawaited(router.push<void>('/reader/book-a'));
          await tester.pumpAndSettle();
          final retained = tester.state(find.byType(ReaderScreen));
          unawaited(
            openReaderSeries(
              tester.element(find.byType(ReaderScreen)),
              ReaderManifest(
                accountId: 'fixture',
                bookId: 'book-a',
                seriesId: 'series-a',
                revision: 'one',
                title: 'Fixture',
                pages: [PageDimensions(1, 1)],
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(CatalogueDetailScreen), findsOneWidget);
          expect(
            find.byType(ReaderScreen, skipOffstage: false),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          if (backFirst) {
            expect(await backEvent(tester, 'startBackGesture'), isTrue);
            await backEvent(tester, 'updateBackGestureProgress');
            await tester.pump();
            await backEvent(tester, 'cancelBackGesture');
            await tester.pumpAndSettle();
            expect(find.byType(CatalogueDetailScreen), findsOneWidget);
            expect(await backEvent(tester, 'startBackGesture'), isTrue);
            await backEvent(tester, 'updateBackGestureProgress');
            await tester.pump();
            await backEvent(tester, 'commitBackGesture');
            await tester.pumpAndSettle();
            expect(tester.state(find.byType(ReaderScreen)), same(retained));
            expect(
              GoRouterState.of(tester.element(find.byType(ReaderScreen))).name,
              'reader',
            );
            await tester.binding.handlePopRoute();
            await tester.pumpAndSettle();
            expect(find.byType(CatalogueDetailScreen), findsNothing);
            expect(router.routeInformationProvider.value.uri.path, '/');
            expect(router.canPop(), isFalse);
          }
          for (final branch in [
            'downloads',
            'libraries',
            'settings',
            'libraries',
            'downloads',
          ]) {
            await openHomeDestination(tester, branch);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: branch);
            expect(
              router.routeInformationProvider.value.uri.path,
              switch (branch) {
                'libraries' => '/',
                'settings' => '/settings',
                _ => '/$branch',
              },
            );
          }
          await harness.close(tester);
        },
      );
    }
  }
}
