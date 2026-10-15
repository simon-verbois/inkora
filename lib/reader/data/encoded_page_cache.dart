import '../domain/content_key.dart';
import '../domain/page_source.dart';

/// Completed buffers only. Subscribers/streams have separate admission budgets.
final class EncodedPageCache {
  EncodedPageCache({this.maximumBytes = 32 * 1024 * 1024}) {
    if (maximumBytes < 0) throw ArgumentError('Invalid encoded memory quota');
  }
  final int maximumBytes;
  final _pages = <ContentKey, EncodedPage>{};
  int bytes = 0;
  int hits = 0;
  int misses = 0;
  EncodedPage? get(ContentKey key) {
    final page = _pages.remove(key);
    if (page == null) {
      misses++;
      return null;
    }
    hits++;
    _pages[key] = page;
    return page;
  }

  bool contains(ContentKey key) => _pages.containsKey(key);

  void put(EncodedPage page) {
    remove(page.key);
    if (page.bytes.length > maximumBytes) return;
    while (bytes + page.bytes.length > maximumBytes && _pages.isNotEmpty) {
      remove(_pages.keys.first);
    }
    _pages[page.key] = page;
    bytes += page.bytes.length;
  }

  void remove(ContentKey key) {
    final old = _pages.remove(key);
    if (old != null) bytes -= old.bytes.length;
  }

  void retainRevision(String account, String book, String revision) {
    for (final key in _pages.keys.toList()) {
      if (key.accountId == account &&
          key.bookId == book &&
          key.revision != revision) {
        remove(key);
      }
    }
  }

  void clear() {
    _pages.clear();
    bytes = 0;
  }
}
