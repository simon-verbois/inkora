import 'package:flutter/material.dart';

import 'dart:ui' show Tristate;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/theme/inkora_theme.dart';
import 'package:inkora/features/library/application/cover_providers.dart';
import 'package:inkora/features/library/domain/catalogue.dart';
import 'package:inkora/features/library/domain/catalogue_filters.dart';
import 'package:inkora/features/library/domain/resume_entry.dart';
import 'package:inkora/features/library/presentation/catalogue_card.dart';
import 'package:inkora/offline/application/offline_coordinator.dart';
import 'package:inkora/offline/data/download_store.dart';

import '../../support/catalogue_fakes.dart';

Future<void> _pump(
  WidgetTester tester,
  Size size,
  Widget child, {
  Set<String> downloaded = const {},
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        coverRepositoryProvider.overrideWith((ref) async => null),
        downloadedIdentitiesProvider.overrideWith(
          (ref) => Stream.value(downloaded),
        ),
        downloadsProvider.overrideWith(
          (ref) => Stream.value(const <DownloadJob>[]),
        ),
        offlineCoordinatorProvider.overrideWith((ref) async => null),
      ],
      child: MaterialApp(
        theme: InkoraTheme.dark(),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: 140, height: 300, child: child),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final size in [const Size(390, 844), const Size(1280, 800)]) {
    testWidgets('cover badges and one combined label at $size', (tester) async {
      final semantics = tester.ensureSemantics();
      final volume = CatalogueItem(
        kind: CatalogueKind.book,
        id: 'b1',
        title: 'Moonlit District 1',
        seriesId: 's',
        number: 1,
        pageCount: 20,
        readingStatus: ReadingStatus.completed,
      );
      await _pump(
        tester,
        size,
        InkCoverTile(item: volume),
        downloaded: {'book:b1'},
      );
      expect(find.byKey(const ValueKey('cover-volume-b1')), findsNothing);
      expect(find.byKey(const Key('cover-read')), findsOneWidget);
      expect(find.byKey(const Key('cover-offline')), findsOneWidget);
      expect(find.byKey(const Key('cover-unavailable')), findsNothing);
      // The former per-cover overflow button is gone.
      expect(find.byType(PopupMenuButton<String>), findsNothing);
      final node = tester.getSemantics(find.byType(InkCoverTile));
      expect(node.label, 'Moonlit District 1, 20 pages, Read, Ready offline');
      expect(node.flagsCollection.isButton, isTrue);
      expect(
        node.getSemanticsData().customSemanticsActionIds,
        isNotEmpty,
        reason: 'menu entries are reachable without a long press',
      );
      // Long press lists the secondary actions; removal is offered.
      await tester.longPress(find.byType(InkCoverTile));
      await tester.pumpAndSettle();
      expect(find.text('Read book'), findsOneWidget);
      expect(find.text('Remove download'), findsOneWidget);
      await tester.tap(find.text('Remove download'));
      await tester.pumpAndSettle();
      expect(find.text('Remove this download?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('ink-confirm-cancel')));
      await tester.pumpAndSettle();
      semantics.dispose();
    });

    testWidgets('resume progress bar and unavailable badge at $size', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final resume = ResumeEntry(
        item: entry('book-a', number: 3),
        seriesTitle: 'Moonlit District',
        pageIndex: 45,
        pageCount: 100,
        fraction: 0,
      );
      await _pump(
        tester,
        size,
        InkCoverTile(
          item: const CatalogueItem(
            kind: CatalogueKind.series,
            id: 'series-a',
            title: 'Moonlit District',
          ),
          resume: resume,
          onOpen: (_) {},
        ),
      );
      expect(find.text('book-a · 45 %'), findsOneWidget);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byKey(const Key('cover-progress')),
            )
            .value,
        .45,
      );
      expect(
        tester.getSemantics(find.byType(InkCoverTile)).label,
        'Moonlit District, book-a · 45 %, In progress',
      );
      await tester.longPress(find.byType(InkCoverTile));
      await tester.pumpAndSettle();
      expect(find.text('Continue reading'), findsOneWidget);
      expect(find.text('View details'), findsOneWidget);
      await tester.tapAt(const Offset(5, 700));
      await tester.pumpAndSettle();

      await _pump(
        tester,
        size,
        InkCoverTile(
          item: entry('gone', available: false, kind: CatalogueKind.series),
        ),
      );
      expect(find.byKey(const Key('cover-unavailable')), findsOneWidget);
      expect(
        tester
            .getSemantics(find.byType(InkCoverTile))
            .flagsCollection
            .isEnabled,
        Tristate.isFalse,
      );
      semantics.dispose();
    });
  }

  testWidgets('shelf announces skeleton loading once', (tester) async {
    await _pump(
      tester,
      const Size(390, 844),
      Builder(builder: (context) => coverSkeletonBuilder(context, 0)),
    );
    expect(find.bySemanticsLabel('Loading'), findsOneWidget);
    expect(find.byType(CoverTileSkeleton), findsOneWidget);
  });
}
