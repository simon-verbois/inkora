import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/core/storage/app_database.dart';
import 'package:inkora/features/library/data/catalogue_store.dart';
import 'package:inkora/features/library/domain/catalogue.dart';
import 'package:inkora/offline/data/progress_store.dart';
import 'package:inkora/offline/domain/progress.dart';
import 'package:inkora/reader/data/reader_store.dart';
import 'package:inkora/reader/domain/reader_manifest.dart';

import '../../support/catalogue_fakes.dart';
import '../../support/reader_fakes.dart';

void main() {
  test('resume excludes other accounts, stale manifests and explicit unread/completion', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final catalogue = CatalogueStore(database, 'account');
    await catalogue.stage('snapshot', [
      entry('book'),
      entry('series-a', kind: CatalogueKind.series, title: 'Saved series'),
    ]);
    await catalogue.publish('snapshot', DateTime.utc(2026, 10, 12), () => true);
    final manifest = readerManifest(account: 'account', book: 'book');
    final reader = ReaderStore(database, 'account');
    final progress = ProgressStore(database, 'account');
    await reader.saveManifest(manifest);
    await reader.saveLocator(manifest, ReaderLocator(1, .5));
    final entryValue = (await catalogue.resume().first).single;
    expect(entryValue.pageIndex, 1);
    expect(entryValue.seriesTitle, 'Saved series');
    expect(entryValue.progress, .375);
    expect(
      await CatalogueStore(database, 'other-account').resume().first,
      isEmpty,
    );
    await progress.save(
      manifest,
      ReaderLocator(0),
      operation: ProgressOperation.markUnread,
    );
    expect(await catalogue.resume().first, isEmpty);
    await progress.save(
      manifest,
      ReaderLocator(1),
      operation: ProgressOperation.rewind,
    );
    expect(await catalogue.resume().first, hasLength(1));
    await progress.save(
      manifest,
      ReaderLocator(1),
      operation: ProgressOperation.complete,
    );
    expect(await catalogue.resume().first, isEmpty);
    await reader.saveManifest(
      readerManifest(account: 'account', book: 'book', revision: 'new'),
    );
    expect(await catalogue.resume().first, isEmpty);
  });
}
