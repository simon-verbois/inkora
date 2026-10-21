import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/reader/data/page_content_bounds_cache.dart';
import 'package:inkora/reader/domain/page_content_bounds.dart';
import 'package:inkora/reader/domain/content_key.dart';
import 'package:inkora/reader/domain/page_source.dart';

EncodedPage page(
  int index, {
  String account = 'account',
  String revision = 'r',
}) => EncodedPage(
  key: ContentKey(
    accountId: account,
    bookId: 'book',
    revision: revision,
    pageIndex: index,
  ),
  bytes: Uint8List(4),
  mediaType: 'image/png',
);
const cropped = PageContentBounds(.1, .1, .9, .9);
void main() {
  test(
    'background pause drains queued buffers and resume can retry once',
    () async {
      final active = <Completer<PageContentBounds>>[];
      final cache = PageContentBoundsCache((_) {
        final result = Completer<PageContentBounds>();
        active.add(result);
        return result.future;
      });
      final first = cache.request(
        page(0),
        visible: true,
        cancellation: CancellationController(),
      );
      final queued = cache.request(
        page(1),
        visible: false,
        cancellation: CancellationController(),
      );
      cache.pause(true);
      expect(await queued, PageContentBounds.full);
      expect(cache.queuedBytes, 0);
      expect(
        await cache.request(
          page(2),
          visible: true,
          cancellation: CancellationController(),
        ),
        PageContentBounds.full,
      );
      expect(active, hasLength(1));
      cache.pause(false);
      final epoch = cache.resumeEpoch;
      cache.pause(false);
      expect(cache.resumeEpoch, epoch);
      final retry = cache.request(
        page(2),
        visible: true,
        cancellation: CancellationController(),
      );
      active.first.complete(cropped);
      expect(await first, PageContentBounds.full);
      expect(active, hasLength(2));
      active.last.complete(cropped);
      expect(await retry, cropped);
    },
  );

  test(
    'equivalent identities coalesce and cached metadata avoids repeat analysis',
    () async {
      var calls = 0;
      final ready = Completer<PageContentBounds>();
      final cache = PageContentBoundsCache((_) {
        calls++;
        return ready.future;
      });
      final firstSignal = CancellationController(),
          secondSignal = CancellationController();
      final first = cache.request(
        page(0),
        visible: false,
        cancellation: firstSignal,
      );
      final second = cache.request(
        page(0),
        visible: true,
        cancellation: secondSignal,
      );
      expect(identical(first, second), true);
      expect(calls, 1);
      firstSignal.cancel();
      ready.complete(cropped);
      expect(await second, cropped);
      cache.pause(true);
      cache.pause(false);
      expect(
        await cache.request(
          page(0),
          visible: true,
          cancellation: CancellationController(),
        ),
        cropped,
      );
      expect(
        calls,
        1,
        reason: 'Completed metadata survives application backgrounding',
      );
      expect(
        await cache.request(
          page(0),
          visible: true,
          cancellation: CancellationController(),
        ),
        cropped,
      );
      expect(calls, 1);
    },
  );
  test(
    'one analysis at a time with bounded queued bytes and foreground priority',
    () async {
      final starts = <int>[];
      final pending = <int, Completer<PageContentBounds>>{};
      final cache = PageContentBoundsCache(
        (page) {
          starts.add(page.key.pageIndex);
          return (pending[page.key.pageIndex] = Completer<PageContentBounds>())
              .future;
        },
        maximumQueued: 2,
        maximumQueuedBytes: 8,
      );
      Future<PageContentBounds> request(int index, {bool visible = false}) =>
          cache.request(
            page(index),
            visible: visible,
            cancellation: CancellationController(),
          );
      final active = request(0), background = request(1), evicted = request(2);
      final visible = request(3, visible: true);
      expect(await evicted, PageContentBounds.full);
      expect(starts, [0]);
      expect(cache.queuedBytes, 8);
      pending[0]!.complete(cropped);
      await active;
      expect(starts, [0, 3]);
      pending[3]!.complete(cropped);
      await visible;
      expect(starts, [0, 3, 1]);
      pending[1]!.complete(cropped);
      await background;
      expect(cache.queuedBytes, 0);
    },
  );
  test(
    'cancelled queued consumers never start and optional failures can retry',
    () async {
      final ready = Completer<PageContentBounds>();
      var calls = 0;
      final cache = PageContentBoundsCache((_) {
        calls++;
        return calls == 1
            ? ready.future
            : Future.error(StateError('bad image'));
      });
      final first = cache.request(
        page(0),
        visible: true,
        cancellation: CancellationController(),
      );
      final signal = CancellationController();
      final cancelled = cache.request(
        page(1),
        visible: false,
        cancellation: signal,
      );
      signal.cancel();
      ready.complete(cropped);
      await first;
      expect(await cancelled, PageContentBounds.full);
      expect(calls, 1);
      for (var i = 0; i < 2; i++) {
        expect(
          await cache.request(
            page(2),
            visible: true,
            cancellation: CancellationController(),
          ),
          PageContentBounds.full,
        );
      }
      expect(calls, 3);
      expect(cache.peek(page(2).key), isNull);
    },
  );
  for (final invalidation in [
    'account',
    'revision',
    'retry',
    'pressure',
    'pause',
  ]) {
    test(
      '$invalidation prevents stale in-flight results from repopulating metadata',
      () async {
        final ready = Completer<PageContentBounds>();
        final cache = PageContentBoundsCache((_) => ready.future);
        final result = cache.request(
          page(0),
          visible: true,
          cancellation: CancellationController(),
        );
        switch (invalidation) {
          case 'account':
            cache.clearAccount('account');
          case 'revision':
            cache.retainRevision('account', 'book', 'new');
          case 'retry':
            cache.invalidate(page(0).key);
          case 'pressure':
            cache.clear();
          case 'pause':
            cache.pause(true);
        }
        ready.complete(cropped);
        expect(await result, PageContentBounds.full);
        expect(cache.length, 0);
      },
    );
  }
  test(
    'metadata LRU is bounded and separates accounts and revisions',
    () async {
      var calls = 0;
      final cache = PageContentBoundsCache((_) async {
        calls++;
        return cropped;
      }, maximumEntries: 2);
      for (final p in [
        page(0),
        page(0, account: 'other'),
        page(0, revision: 'new'),
      ]) {
        await cache.request(
          p,
          visible: true,
          cancellation: CancellationController(),
        );
      }
      expect(calls, 3);
      expect(cache.length, 2);
      expect(cache.peek(page(0).key), isNull);
      cache.clearAccount('other');
      expect(cache.length, 1);
      cache.retainRevision('account', 'book', 'latest');
      expect(cache.length, 0);
    },
  );
}
