import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/features/library/application/cover_providers.dart';
import 'package:inkora/features/library/presentation/catalogue_card.dart';
import 'package:inkora/features/library/presentation/book_cover.dart';
import 'package:inkora/features/settings/domain/ui_preferences.dart';

import '../../support/catalogue_fakes.dart';

void main() {
  for (final size in [
    const Size(390, 844),
    const Size(1024, 768),
    const Size(1280, 800),
  ]) {
    testWidgets(
      'Home cover geometry matches comfortable library grid on tablet $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              coverRepositoryProvider.overrideWith((_) async => null),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: CatalogueShelf(
                    items: [entry('one'), entry('two'), entry('three')],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final width = tester.getSize(find.byType(BookCover).first).width;
        if (size.width >= 600) {
          expect(
            width,
            closeTo(
              catalogueCoverWidth(size.width, CatalogueDensity.comfortable),
              .01,
            ),
          );
          expect(width, greaterThan(160));
        } else {
          expect(width, lessThanOrEqualTo(120));
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
