import '../support/home_navigation.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/router.dart';
import 'package:inkora/features/library/presentation/catalogue_detail_screen.dart';
import 'package:inkora/reader/domain/reader_manifest.dart';
import 'package:inkora/reader/presentation/reader_details.dart';
import 'package:inkora/reader/presentation/reader_screen.dart';

import '../support/ui_harness.dart';

void main() {
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
          unawaited(
            openReaderDetails(
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
          expect(find.byType(ReaderScreen, skipOffstage: false), findsNothing);
          expect(tester.takeException(), isNull);
          if (backFirst) {
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
