import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/inkora_app.dart';
import 'package:inkora/app/l10n/app_strings.dart';
import 'package:inkora/app/router.dart';
import 'package:inkora/core/storage/app_database.dart';
import 'package:inkora/features/library/domain/catalogue.dart';
import 'package:inkora/features/library/domain/catalogue_metadata.dart';
import 'package:inkora/features/library/domain/resume_entry.dart';
import 'package:inkora/features/library/presentation/resume_carousel.dart';
import 'package:inkora/features/library/presentation/volume_actions.dart';
import 'package:inkora/features/settings/domain/ui_preferences.dart';
import 'package:inkora/offline/data/progress_store.dart';
import 'package:inkora/offline/domain/progress.dart';
import 'package:inkora/reader/data/reader_store.dart';
import 'package:inkora/reader/domain/reader_manifest.dart';

import '../../support/catalogue_fakes.dart';
import '../../support/connection_fakes.dart';
import '../../support/reader_fakes.dart';
import '../../support/ui_harness.dart';

const _book = 'resume-target';
const _title = 'The saved volume';
const _position = 'saved-version';

CatalogueItem book(String mediaType) => CatalogueItem(
  kind: CatalogueKind.book,
  id: _book,
  title: _title,
  seriesId: 'series-a',
  libraryId: 'library-a',
  pageCount: 4,
  readPage: 1,
  readModified: _position,
  metadata: CatalogueMetadata(mediaType: mediaType),
);

ResumeEntry position(String mediaType) => ResumeEntry(
  item: book(mediaType),
  seriesTitle: 'Saved series',
  pageIndex: 1,
  pageCount: 4,
  fraction: .3,
  raster: mediaType != 'application/epub+zip',
);

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pumpAndSettle();
  }
}

Future<UiHarness> create(
  WidgetTester tester,
  String mediaType, {
  bool serverOnly = false,
}) async {
  final harness = await UiHarness.create(
    tester,
    catalogue: [
      entry('library-a', kind: CatalogueKind.library),
      entry('series-a', kind: CatalogueKind.series, title: 'Saved series'),
      book(mediaType),
      entry('other-book'),
    ],
  );
  await tester.runAsync(() async {
    if (serverOnly) {
      final source = jsonDecode(
        File('test/fixtures/komga/1.28.1/resume-books.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final original =
          (source['content'] as List).first as Map<String, dynamic>;
      await harness.database
          .into(harness.database.resumeSnapshots)
          .insert(
            ResumeSnapshotsCompanion.insert(
              accountId: savedSession.accountId,
              payload: jsonEncode({
                'books': [
                  {
                    ...original,
                    'id': _book,
                    'name': _title,
                    'seriesId': 'series-a',
                    'libraryId': 'library-a',
                    'media': {
                      ...original['media'] as Map<String, dynamic>,
                      'mediaType': mediaType,
                      'mediaProfile': mediaType == 'application/epub+zip'
                          ? 'EPUB'
                          : 'DIVINA',
                    },
                    'readProgress': {
                      'page': mediaType == 'application/epub+zip' ? 0 : 2,
                      'completed': false,
                      'lastModified': _position,
                    },
                  },
                ],
                'onDeck': <Object?>[],
                'baselines': <String, Object?>{},
              }),
              updatedAt: DateTime.now(),
            ),
          );
    } else {
      final reader = ReaderStore(harness.database, savedSession.accountId);
      final manifest = ReaderManifest(
        accountId: savedSession.accountId,
        bookId: _book,
        revision: 'revision-a',
        title: _title,
        pages: readerManifest().pages,
        documentType: mediaType.isEmpty ? null : mediaType,
      );
      await reader.saveManifest(manifest);
      await reader.saveLocator(
        manifest,
        ReaderLocator(
          1,
          .3,
          mediaType == 'application/epub+zip'
              ? jsonEncode({
                  'href': 'chapter.xhtml',
                  'type': mediaType,
                  'locations': {'totalProgression': .3},
                })
              : null,
        ),
      );
    }
  });
  addTearDown(() => harness.close(tester));
  await harness.mount(tester);
  await settle(tester);
  expect(find.byKey(const ValueKey('resume-$_book')), findsOneWidget);
  return harness;
}

Future<void> openMenu(WidgetTester tester) async {
  await tester.longPress(find.byKey(const ValueKey('resume-$_book')));
  await tester.pumpAndSettle();
  expect(find.text('Mark read'), findsOneWidget);
  expect(find.text('Mark unread'), findsOneWidget);
}

Future<void> mark(WidgetTester tester, {required bool read}) async {
  await openMenu(tester);
  await tester.runAsync(
    () => tester.tap(find.text(read ? 'Mark read' : 'Mark unread')),
  );
  await settle(tester);
  if (read) {
    expect(find.text('Mark as read?'), findsOneWidget);
    await tester.runAsync(
      () => tester.tap(find.byKey(const Key('ink-confirm-accept'))),
    );
    await settle(tester);
  }
}

void main() {
  for (final size in [const Size(390, 844), const Size(1024, 768)]) {
    for (final mediaType in ['', 'application/epub+zip', 'application/pdf']) {
      for (final read in [true, false]) {
        testWidgets(
          'Home marks exact $mediaType book read=$read offline at $size',
          (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final harness = await create(tester, mediaType);
            final requests =
                (harness.repository.remote as FakeCatalogueRemote).calls;
            await mark(tester, read: read);
            final intents = (await tester.runAsync(
              () => ProgressStore(
                harness.database,
                savedSession.accountId,
              ).pending(),
            ))!;
            expect(intents, hasLength(2));
            expect(intents.first.operation, ProgressOperation.advance);
            expect(intents.last.bookId, _book);
            expect(
              intents.last.operation,
              read ? ProgressOperation.complete : ProgressOperation.markUnread,
            );
            expect(intents.last.baseline!.pageIndex, 1);
            expect(intents.last.baseline!.version, _position);
            expect(find.byKey(const ValueKey('resume-$_book')), findsNothing);
            expect(
              harness.container
                  .read(routerProvider)
                  .routeInformationProvider
                  .value
                  .uri
                  .path,
              '/',
            );
            expect(
              (harness.repository.remote as FakeCatalogueRemote).calls,
              requests,
            );
            if (!read) {
              final locator = (await tester.runAsync(
                () => harness.database
                    .select(harness.database.readerPositions)
                    .getSingle(),
              ))!;
              expect(locator.pageIndex, 0);
              expect(locator.documentLocator, isNull);
            }
            expect(tester.takeException(), isNull);
            await harness.close(tester);
          },
        );
      }
    }
  }

  testWidgets(
    'completion cancellation and menu dismissal preserve the saved position',
    (tester) async {
      final harness = await create(tester, '');
      await openMenu(tester);
      harness.container.read(routerProvider).pop();
      await tester.pumpAndSettle();
      await openMenu(tester);
      await tester.tap(find.text('Mark read'));
      await tester.pumpAndSettle();
      expect(find.textContaining(_title), findsWidgets);
      await tester.tap(find.byKey(const Key('ink-confirm-cancel')));
      await tester.pumpAndSettle();
      expect(
        (await tester.runAsync(
          () =>
              ProgressStore(harness.database, savedSession.accountId).pending(),
        ))!,
        hasLength(1),
      );
      expect(find.byKey(const ValueKey('resume-$_book')), findsOneWidget);
      expect(
        harness.container
            .read(routerProvider)
            .routeInformationProvider
            .value
            .uri
            .path,
        '/',
      );
      await harness.close(tester);
    },
  );

  testWidgets(
    'write failure retains the cover and reports the existing progress error',
    (tester) async {
      final harness = await create(tester, '');
      await tester.runAsync(
        () => harness.database.customStatement(
          "CREATE TRIGGER refuse_mark BEFORE INSERT ON progress_events BEGIN SELECT RAISE(ABORT, 'fixture failure'); END",
        ),
      );
      await openMenu(tester);
      await tester.runAsync(() => tester.tap(find.text('Mark unread')));
      await settle(tester);
      expect(find.text('Unable to save reading progress.'), findsOneWidget);
      expect(find.byKey(const ValueKey('resume-$_book')), findsOneWidget);
      expect(
        (await tester.runAsync(
          () =>
              ProgressStore(harness.database, savedSession.accountId).pending(),
        ))!,
        hasLength(1),
      );
      await harness.close(tester);
    },
  );

  for (final read in [true, false]) {
    testWidgets(
      'server-only resume can be marked read=$read without a manifest',
      (tester) async {
        final harness = await create(
          tester,
          'application/epub+zip',
          serverOnly: true,
        );
        await mark(tester, read: read);
        expect(find.byKey(const ValueKey('resume-$_book')), findsNothing);
        final events = (await tester.runAsync(
          () =>
              ProgressStore(harness.database, savedSession.accountId).pending(),
        ))!;
        expect(events.single.bookId, _book);
        expect(events.single.revision, ProgressIntent.anyRevision);
        expect(
          events.single.baseline!.pageIndex,
          0,
          reason: 'Unknown EPUB page still represents existing server progress',
        );
        expect(
          (await tester.runAsync(
            () =>
                harness.database.select(harness.database.readerManifests).get(),
          ))!,
          isEmpty,
        );
        await harness.close(tester);
      },
    );
  }

  testWidgets('a captured mark for a different account cannot write progress', (
    tester,
  ) async {
    final harness = await create(tester, '');
    late WidgetRef ref;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: Consumer(
          builder: (_, widgetRef, _) {
            ref = widgetRef;
            return const InkoraApp();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => expectLater(
        markResumeBook(
          ref,
          position(''),
          accountId: 'previous-account',
          read: false,
        ),
        throwsStateError,
      ),
    );
    expect(
      (await tester.runAsync(
        () => harness.database.select(harness.database.progressEvents).get(),
      ))!,
      hasLength(1),
    );
    await harness.close(tester);
  });

  for (final locale in languageNames.keys) {
    testWidgets(
      'Continue menu and accessibility actions fit $locale at 320dp/200%',
      (tester) async {
        final semantics = tester.ensureSemantics();

        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final harness = await UiHarness.create(
          tester,
          preferences: UiPreferences(locale: locale),
          resumeEntries: [position('')],
        );
        addTearDown(() => harness.close(tester));
        await harness.mount(tester, textScale: 2);
        final actions =
            tester
                .getSemantics(find.byKey(const ValueKey('resume-$_book')))
                .getSemanticsData()
                .customSemanticsActionIds ??
            [];
        final labels = [
          for (final id in actions) CustomSemanticsAction.getAction(id)!.label,
        ];
        final strings = AppStrings(locale);
        expect(
          labels,
          containsAll([strings.text('Mark read'), strings.text('Mark unread')]),
        );
        await tester.longPress(find.byKey(const ValueKey('resume-$_book')));
        await tester.pumpAndSettle();
        expect(
          find.text(strings.text('Mark read')).hitTestable(),
          findsOneWidget,
        );
        expect(
          find.text(strings.text('Mark unread')).hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        harness.container.read(routerProvider).pop();
        await tester.pumpAndSettle();
        expect(find.byType(ResumeCarousel), findsOneWidget);
        semantics.dispose();
        await harness.close(tester);
      },
    );
  }
}
