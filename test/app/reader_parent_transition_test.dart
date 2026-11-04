import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/router.dart';
import 'package:inkora/features/library/presentation/catalogue_detail_screen.dart';
import 'package:inkora/features/settings/domain/ui_preferences.dart';
import 'package:inkora/reader/data/reader_repository.dart';
import 'package:inkora/reader/domain/reader_manifest.dart';
import 'package:inkora/reader/presentation/reader_system_ui.dart';
import 'package:inkora/reader/presentation/reader_viewport.dart';

import '../support/ui_harness.dart';
import '../support/catalogue_fakes.dart';
import '../support/reader_fakes.dart';
import '../support/reader_widget_support.dart';

void main() {
  for (final size in [const Size(390, 844), const Size(1280, 800)]) {
    for (final document in [false, true]) {
      for (final reduced in [false, true]) {
        testWidgets(
          'parent window updates wait for the route, document=$document/reduced=$reduced/size=$size',
          (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final calls = <bool>[];
            tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
              ReaderSystemUi.channel,
              (call) async {
                calls.add(call.arguments as bool);
                return true;
              },
            );
            addTearDown(
              () => tester.binding.defaultBinaryMessenger
                  .setMockMethodCallHandler(ReaderSystemUi.channel, null),
            );
            final reader = OpenReader(
              ReaderManifest(
                accountId: 'fixture',
                bookId: 'book-a',
                revision: 'one',
                title: 'Book',
                seriesId: 'series-a',
                libraryId: 'library-a',
                documentType: document ? 'application/epub+zip' : null,
                pages: readerManifest(count: 8).pages,
              ),
              FixturePageSource(),
              ReaderLocator(1, .2),
            );
            final harness = await UiHarness.create(
              tester,
              openedReader: reader,
              preferences: UiPreferences(reduceMotion: reduced),
            );
            addTearDown(() => harness.close(tester));
            await harness.mount(tester);
            final router = harness.container.read(routerProvider);
            router.push<void>('/reader/book-a');
            await settleReaderImages(tester);
            await tester.tapAt(Offset(size.width / 2, size.height / 2));
            await settleReaderImages(tester);
            final viewport = find.byType(ReaderViewport);
            final state = tester.state(viewport);
            final geometry = tester.getRect(viewport);
            final pages = tester
                .widget<PageView>(find.byKey(const Key('paged-reader')))
                .controller!;
            final currentPage = pages.page;
            final remote = harness.repository.remote as FakeCatalogueRemote;
            final requests = remote.calls;
            final transform = tester
                .widget<InteractiveViewer>(find.byType(InteractiveViewer).first)
                .transformationController!;
            transform.value = Matrix4.diagonal3Values(2, 2, 1);
            await tester.pump();
            expect(calls.last, document);
            calls.clear();
            final open = tester
                .widget<TextButton>(find.byKey(const Key('reader-series')))
                .onPressed!;
            open();
            open(); // Repeated activation in the same frame must push only once.
            await tester.pump();
            if (!reduced) {
              await tester.pump(const Duration(milliseconds: 32));
              expect(
                calls,
                isEmpty,
                reason: 'No native window update during the opening transition',
              );
            }
            await tester.pumpAndSettle();
            expect(
              tester
                  .widget<ReaderViewport>(
                    find.byType(ReaderViewport, skipOffstage: false),
                  )
                  .active,
              isFalse,
            );
            expect(find.byType(CatalogueDetailScreen), findsOneWidget);
            expect(
              tester.state(find.byType(ReaderViewport, skipOffstage: false)),
              same(state),
            );
            expect(calls, document ? [false] : isEmpty);
            calls.clear();
            router.pop();
            await tester.pump();
            if (!reduced) {
              await tester.pump(const Duration(milliseconds: 32));
              expect(
                calls,
                isEmpty,
                reason: 'No native window update during the closing transition',
              );
            }
            await tester.pumpAndSettle();
            expect(calls, document ? [true] : isEmpty);
            expect(tester.state(viewport), same(state));
            expect(tester.getRect(viewport), geometry);
            expect(tester.widget<ReaderViewport>(viewport).active, isTrue);
            expect(transform.value.getMaxScaleOnAxis(), 2);
            expect(
              tester
                  .widget<PageView>(find.byKey(const Key('paged-reader')))
                  .controller,
              same(pages),
            );
            expect(pages.page, currentPage);
            expect(remote.calls, requests);
            expect(tester.takeException(), isNull);
            await harness.close(tester);
          },
        );
      }
    }
  }
}
