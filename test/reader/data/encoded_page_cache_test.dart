import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/reader/data/encoded_page_cache.dart';
import 'package:inkora/reader/domain/page_source.dart';

import '../../support/reader_fakes.dart';

void main() {
  test('encoded LRU evicts by bytes, honors recency and never caches an oversized buffer', () {
    final memory = EncodedPageCache(maximumBytes: fixtureRaster.length * 2);
    final manifest = readerManifest();
    EncodedPage page(int i) => EncodedPage(
      key: manifest.key(i),
      bytes: fixtureRaster,
      mediaType: 'image/png',
    );
    memory.put(page(0));
    memory.put(page(1));
    memory.get(manifest.key(0));
    memory.put(page(2));
    expect(memory.get(manifest.key(1)), isNull);
    expect(memory.get(manifest.key(0)), isNotNull);
    expect(memory.bytes, fixtureRaster.length * 2);
    memory.remove(manifest.key(0));
    expect(memory.bytes, fixtureRaster.length);
    final tiny = EncodedPageCache(maximumBytes: fixtureRaster.length - 1)
      ..put(page(0));
    expect(tiny.bytes, 0);
  });
  test('revision invalidation preserves other books and accounts', () {
    final memory = EncodedPageCache();
    for (final manifest in [
      readerManifest(),
      readerManifest(revision: 'new'),
      readerManifest(account: 'other'),
      readerManifest(book: 'other'),
    ]) {
      memory.put(
        EncodedPage(
          key: manifest.key(0),
          bytes: fixtureRaster,
          mediaType: 'image/png',
        ),
      );
    }
    memory.retainRevision('reader-account', 'reader-book', 'new');
    expect(memory.contains(readerManifest().key(0)), false);
    expect(memory.contains(readerManifest(revision: 'new').key(0)), true);
    expect(memory.contains(readerManifest(account: 'other').key(0)), true);
    expect(memory.contains(readerManifest(book: 'other').key(0)), true);
    memory.clear();
    expect(memory.bytes, 0);
  });
}
