/// Identity shared by downloads, caches and remote raster page sources.
final class ContentKey {
  ContentKey({
    required this.accountId,
    required this.bookId,
    required this.revision,
    required this.pageIndex,
    this.representation = 'original',
  }) {
    if (accountId.isEmpty ||
        bookId.isEmpty ||
        revision.isEmpty ||
        representation.isEmpty ||
        pageIndex < 0) {
      throw ArgumentError(
        'Content identity requires non-empty fields and a zero-based page index',
      );
    }
  }

  final String accountId;
  final String bookId;
  final String revision;
  final int pageIndex;
  final String representation;

  @override
  bool operator ==(Object other) =>
      other is ContentKey &&
      accountId == other.accountId &&
      bookId == other.bookId &&
      revision == other.revision &&
      pageIndex == other.pageIndex &&
      representation == other.representation;

  @override
  int get hashCode =>
      Object.hash(accountId, bookId, revision, pageIndex, representation);
}
