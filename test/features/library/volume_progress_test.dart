import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/l10n/app_strings.dart';
import 'package:inkora/core/storage/app_database.dart';
import 'package:inkora/features/library/data/catalogue_store.dart';
import 'package:inkora/features/library/data/komga_catalogue_remote.dart';
import 'package:inkora/features/library/domain/catalogue.dart';
import 'package:inkora/features/library/domain/catalogue_filters.dart';
import 'package:inkora/features/library/domain/volume_progress.dart';
import 'package:inkora/features/library/presentation/volume_browser.dart';
import 'package:inkora/offline/data/progress_store.dart';
import 'package:inkora/offline/domain/progress.dart';
import 'package:inkora/reader/domain/reader_manifest.dart';

SeriesVolume volume(
  String id, {
  double number = 1,
  ReadingStatus server = ReadingStatus.unread,
  int? page,
  String media = '',
  bool available = true,
}) => SeriesVolume(
  id: id,
  seriesId: 's',
  title: 'Volume $id',
  number: number,
  pageCount: 100,
  serverStatus: server,
  serverPage: page,
  mediaType: media,
  available: available,
);

void main() {
  group('resolveVolumeProgress', () {
    test('falls back to the catalogue snapshot', () {
      expect(resolveVolumeProgress(volume('a'), null), VolumeProgress.unread);
      expect(
        resolveVolumeProgress(
          volume('a', server: ReadingStatus.completed),
          null,
        ).read,
        isTrue,
      );
      final reading = resolveVolumeProgress(
        volume('a', server: ReadingStatus.inProgress, page: 25),
        null,
      );
      expect(reading.reading, isTrue);
      expect(reading.pageIndex, 25);
      expect(reading.ratio, .25);
    });

    test('a pending local intent overrides the server immediately', () {
      final server = volume('a', server: ReadingStatus.completed);
      final unread = resolveVolumeProgress(
        server,
        const LocalVolumeProgress(operation: 'markUnread'),
      );
      expect(unread.status, ReadingStatus.unread);
      expect(unread.pending, isTrue);
      final complete = resolveVolumeProgress(
        volume('a'),
        const LocalVolumeProgress(
          operation: 'complete',
          eventPage: 99,
          eventPageCount: 100,
        ),
      );
      expect(complete.read, isTrue);
      final advance = resolveVolumeProgress(
        server,
        const LocalVolumeProgress(
          operation: 'advance',
          eventPage: 40,
          eventPageCount: 100,
        ),
      );
      expect(advance.reading, isTrue);
      expect(advance.pageIndex, 40);
      final ebook = resolveVolumeProgress(
        volume('a', media: 'application/epub+zip'),
        const LocalVolumeProgress(
          operation: 'advance',
          eventPage: 2,
          eventPageCount: 10,
          eventTotal: .995,
        ),
      );
      expect(ebook.read, isTrue);
    });

    test('baseline, then local position, then shelf', () {
      final server = volume('a', server: ReadingStatus.inProgress, page: 5);
      expect(
        resolveVolumeProgress(
          server,
          const LocalVolumeProgress(hasBaseline: true, baselineCompleted: true),
        ).read,
        isTrue,
      );
      expect(
        resolveVolumeProgress(
          server,
          const LocalVolumeProgress(hasBaseline: true, positionPage: 50),
        ).status,
        ReadingStatus.unread,
      );
      expect(
        resolveVolumeProgress(
          server,
          const LocalVolumeProgress(positionPage: 50),
        ).pageIndex,
        50,
      );
      expect(
        resolveVolumeProgress(
          volume('a'),
          null,
          shelf: (pageIndex: 70, ratio: .7),
        ).pageIndex,
        70,
      );
      expect(
        resolveVolumeProgress(
          volume('a', server: ReadingStatus.completed),
          null,
          shelf: (pageIndex: 70, ratio: .7),
        ).read,
        isTrue,
      );
    });
  });

  group('SeriesProgress', () {
    SeriesProgress series(Map<String, VolumeProgress> states, [int n = 5]) =>
        SeriesProgress([
          for (var i = 1; i <= n; i++) volume('v$i', number: i.toDouble()),
        ], states);
    const read = VolumeProgress(status: ReadingStatus.completed, ratio: 1);
    const reading = VolumeProgress(
      status: ReadingStatus.inProgress,
      pageIndex: 50,
      ratio: .5,
    );

    test('current volume: shelf, first in progress, On Deck, first unread', () {
      expect(series({}).currentIndex(), 0);
      expect(series({}).started, isFalse);
      expect(series({'v1': read, 'v2': read}).currentIndex(), 2);
      expect(series({'v1': read, 'v4': reading}).currentIndex(), 3);
      expect(
        series({'v1': read, 'v4': reading}).currentIndex(resumeBookId: 'v5'),
        4,
      );
      expect(
        series({'v1': read}).currentIndex(nextBookId: 'v3'),
        2,
        reason: 'On Deck wins over a stale unread snapshot volume',
      );
      expect(
        series({'v1': read, 'v2': reading}).currentIndex(nextBookId: 'v3'),
        1,
      );
      expect(
        series({for (var i = 1; i <= 5; i++) 'v$i': read}).currentIndex(),
        isNull,
      );
      expect(series({'v1': read, 'v2': read}).readCount, 2);
    });

    test('segments: one per volume up to forty, averaged beyond', () {
      expect(series({'v1': read, 'v2': reading}).segments(), [1, .5, 0, 0, 0]);
      final long = series({
        for (var i = 1; i <= 40; i++) 'v$i': read,
        'v41': reading,
      }, 80);
      final segments = long.segments();
      expect(segments, hasLength(40));
      expect(segments.first, 1);
      expect(segments[20], .25);
      expect(segments.last, 0);
    });

    test('filters and reverse order', () {
      final progress = series({'v1': read, 'v2': reading});
      expect(filterVolumes(progress, VolumeFilter.unread).map((v) => v.id), [
        'v3',
        'v4',
        'v5',
      ]);
      expect(
        filterVolumes(progress, VolumeFilter.inProgress).map((v) => v.id),
        ['v2'],
      );
      expect(
        filterVolumes(
          progress,
          VolumeFilter.downloaded,
          downloaded: {'book:v4'},
        ).map((v) => v.id),
        ['v4'],
      );
      expect(
        filterVolumes(progress, VolumeFilter.all, descending: true).first.id,
        'v5',
      );
    });
  });

  test('row titles preserve published titles instead of replacing them with numbers', () {
    final strings = AppStrings('en');
    SeriesVolume titled(String title, double number) =>
        SeriesVolume(id: 'x', seriesId: 's', title: title, number: number);
    expect(volumeRowTitle(strings, titled('Volume 03', 3)), 'Volume 03');
    expect(volumeRowTitle(strings, titled('Tome 3', 3)), 'Tome 3');
    expect(
      volumeRowTitle(strings, titled('Bleach #3', 3), seriesTitle: 'Bleach'),
      'Bleach #3',
    );
    expect(volumeRowTitle(strings, titled('The Return', 3)), 'The Return');
    expect(volumeRowTitle(strings, titled('Prologue', 0)), 'Prologue');
  });

  test('catalogue parser keeps the zero-based server page and version', () {
    final item = parseCatalogueItem({
      'id': 'b',
      'name': 'b',
      'libraryId': 'l',
      'seriesId': 's',
      'deleted': false,
      'media': {'pagesCount': 30, 'mediaType': 'application/zip'},
      'metadata': {'title': 'B', 'numberSort': 1},
      'readProgress': {
        'page': 12,
        'completed': false,
        'lastModified': '2026-10-01T10:00:00Z',
      },
    }, CatalogueKind.book);
    expect(item.readingStatus, ReadingStatus.inProgress);
    expect(item.readPage, 11);
    expect(item.readModified, '2026-10-01T10:00:00Z');
  });

  group('CatalogueStore series queries', () {
    late AppDatabase database;
    late CatalogueStore store;
    setUp(() async {
      database = AppDatabase(NativeDatabase.memory());
      store = CatalogueStore(database, 'a', applyLibraryVisibility: false);
      await store.stage('g1', [
        const CatalogueItem(kind: CatalogueKind.series, id: 's', title: 'S'),
        for (var i = 3; i >= 1; i--)
          CatalogueItem(
            kind: CatalogueKind.book,
            id: 'b$i',
            title: 'Book $i',
            seriesId: 's',
            libraryId: 'l',
            number: i.toDouble(),
            pageCount: 20,
            readingStatus: i == 1
                ? ReadingStatus.completed
                : i == 2
                ? ReadingStatus.inProgress
                : ReadingStatus.unread,
            readPage: i == 2 ? 7 : null,
            readModified: i == 2 ? 'v7' : null,
          ),
        const CatalogueItem(
          kind: CatalogueKind.book,
          id: 'other',
          title: 'Other',
          seriesId: 'elsewhere',
        ),
      ]);
      await store.publish('g1', DateTime(2026), () => true);
    });
    tearDown(() => database.close());

    test('volumes are ordered lean rows with snapshot progress', () async {
      final volumes = await store.readSeriesVolumes('s');
      expect(volumes.map((v) => v.id), ['b1', 'b2', 'b3']);
      expect(volumes[0].serverStatus, ReadingStatus.completed);
      expect(volumes[1].serverPage, 7);
      expect(volumes[1].serverModified, 'v7');
      expect(volumes[2].serverStatus, ReadingStatus.unread);
      expect(await store.needsMediaRefresh(), isFalse);
      // Snapshots written before the server page was stored refresh once.
      await database.customStatement(
        "UPDATE catalogue_entries SET descriptive_metadata=json_remove(descriptive_metadata, '\$.readPage') WHERE remote_id='b2'",
      );
      expect(await store.needsMediaRefresh(), isTrue);
    });

    test(
      'local progress emits only when a series book changes effectively',
      () async {
        final emissions = <Map<String, LocalVolumeProgress>>[];
        final subscription = store
            .watchSeriesLocalProgress('s')
            .listen(emissions.add);
        addTearDown(subscription.cancel);
        await pumpEventQueue();
        expect(emissions.single, isEmpty);
        final progress = ProgressStore(database, 'a');
        await progress.mark([
          const ProgressMark(bookId: 'b3', pageCount: 20),
        ], read: true);
        await pumpEventQueue();
        expect(emissions.last['b3']!.operation, 'complete');
        final count = emissions.length;
        // Another account's and another series' writes do not emit.
        await ProgressStore(
          database,
          'other-account',
        ).mark([const ProgressMark(bookId: 'b3', pageCount: 20)], read: true);
        await progress.mark([
          const ProgressMark(bookId: 'other', pageCount: 20),
        ], read: true);
        // A repeated mark writes nothing.
        await progress.mark([
          const ProgressMark(bookId: 'b3', pageCount: 20),
        ], read: true);
        await pumpEventQueue();
        expect(emissions.length, count);
        // A reader page save of a series book does emit (local wins).
        await progress.save(
          ReaderManifest(
            accountId: 'a',
            bookId: 'b2',
            revision: 'r',
            title: 'B2',
            pages: [for (var i = 0; i < 20; i++) PageDimensions(1, 1)],
          ),
          ReaderLocator(9),
        );
        await pumpEventQueue();
        expect(emissions.length, count + 1);
        expect(emissions.last['b2']!.eventPage, 9);
      },
    );
  });
}
