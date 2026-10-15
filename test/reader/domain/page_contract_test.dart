import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/reader/domain/content_key.dart';
import 'package:inkora/reader/domain/page_source.dart';

void main() {
  ContentKey key({
    String account = 'account-1',
    String revision = 'hash-1',
    int page = 0,
  }) => ContentKey(
    accountId: account,
    bookId: 'book-1',
    revision: revision,
    pageIndex: page,
  );

  test('cache identity isolates accounts, revisions and page indexes', () {
    expect(key(), key());
    expect(
      {
        key(),
        key(),
        key(account: 'account-2'),
        key(revision: 'hash-2'),
        key(page: 1),
      }.length,
      4,
    );
    expect(() => key(page: -1), throwsArgumentError);
    expect(() => key(account: ''), throwsArgumentError);
  });

  test(
    'cancellation completes once and remains observable to late subscribers',
    () async {
      final controller = CancellationController();
      expect(controller.isCancelled, isFalse);
      final pending = controller.whenCancelled;
      controller.cancel();
      controller.cancel();
      await pending;
      await controller.whenCancelled;
      expect(controller.isCancelled, isTrue);
    },
  );
}
