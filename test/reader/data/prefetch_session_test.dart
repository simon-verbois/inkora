import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/reader/data/encoded_page_cache.dart';
import 'package:inkora/reader/data/page_network_gate.dart';
import 'package:inkora/reader/data/prefetch_session.dart';
import 'package:inkora/reader/domain/content_key.dart';
import 'package:inkora/reader/domain/page_source.dart';
import 'package:inkora/reader/domain/prefetch_policy.dart';

import '../../support/reader_fakes.dart';

class ControlledSource implements PrioritizedPageSource {
  final fixture = FixturePageSource()..hold = true;
  final priorities = <ContentKey, PageRequest>{};
  @override
  Future<EncodedPage> read(
    ContentKey key, {
    required CancellationSignal cancellation,
  }) => fixture.read(key, cancellation: cancellation);
  @override
  Future<EncodedPage> readAhead(
    ContentKey key, {
    required CancellationSignal cancellation,
    required PageRequest request,
  }) {
    priorities[key] = request;
    return read(key, cancellation: cancellation);
  }

  @override
  Future<void> invalidate(ContentKey key) async {}
}

void main() {
  Future<void> flush() => Future<void>.delayed(Duration.zero);
  test('direction reversal cancels obsolete subscribers immediately and rebuilds deadlines', () async {
    var now = Duration.zero;
    final manifest = readerManifest(count: 30);
    final source = ControlledSource();
    final session = PrefetchSession(
      manifest,
      source,
      PrefetchPolicy(ReaderNetworkEstimate()),
      EncodedPageCache(),
      now: () => now,
    );
    session.update(5);
    final old = source.fixture.requests.toList();
    now = const Duration(seconds: 1);
    session.update(6);
    now = const Duration(seconds: 2);
    session.update(4);
    await flush();
    expect(session.policy.direction, -1);
    expect(session.demands.every((d) => d.index < 4), true);
    expect(old.every(source.fixture.cancelled.contains), true);
    session.close();
    await flush();
    expect(session.pending, 0);
    expect(source.fixture.cancelled.length, source.fixture.requests.length);
  });
  test('chapter speculation is lowest priority and reversed/jumped generations release it', () async {
    var now = Duration.zero;
    final manifest = readerManifest(count: 4);
    final next = readerManifest(book: 'next');
    final source = ControlledSource();
    final nextSource = ControlledSource();
    var releases = 0;
    final session = PrefetchSession(
      manifest,
      source,
      PrefetchPolicy(ReaderNetworkEstimate()),
      EncodedPageCache(),
      now: () => now,
      prepareNext: (_) async =>
          ChapterAhead(next, nextSource, () => releases++),
    );
    session.update(3);
    await flush();
    expect(nextSource.fixture.requests, [next.key(0)]);
    expect(nextSource.priorities[next.key(0)]!.priority, PagePriority.chapter);
    now = const Duration(seconds: 1);
    session.update(0);
    await flush();
    expect(releases, 1);
    expect(nextSource.fixture.cancelled, [next.key(0)]);
    session.close();
  });
  test(
    'close cancels manifest preparation and releases its late result',
    () async {
      final prepare = Completer<ChapterAhead?>();
      CancellationSignal? preparation;
      var released = false;
      final session = PrefetchSession(
        readerManifest(),
        ControlledSource(),
        PrefetchPolicy(ReaderNetworkEstimate()),
        EncodedPageCache(),
        prepareNext: (signal) {
          preparation = signal;
          return prepare.future;
        },
      );
      session.update(3);
      session.close();
      expect(preparation!.isCancelled, true);
      prepare.complete(
        ChapterAhead(
          readerManifest(book: 'other'),
          ControlledSource(),
          () => released = true,
        ),
      );
      await flush();
      expect(released, true);
      expect(session.pending, 0);
    },
  );
  test('suspension and constrained networks avoid chapter work; shared memory records ready demand', () async {
    var preparations = 0;
    final manifest = readerManifest();
    final memory = EncodedPageCache()
      ..put(
        EncodedPage(
          key: manifest.key(0),
          bytes: fixtureRaster,
          mediaType: 'image/png',
        ),
      );
    final policy = PrefetchPolicy(ReaderNetworkEstimate())..constrained = true;
    final session = PrefetchSession(
      manifest,
      ControlledSource(),
      policy,
      memory,
      prepareNext: (_) async {
        preparations++;
        return null;
      },
    );
    session.update(3);
    await flush();
    expect(preparations, 0);
    session.foreground(manifest.key(0));
    session.foreground(manifest.key(1));
    expect(session.readyBeforeDemand, 1);
    session.suspend(true);
    session.update(2);
    expect(session.pending, 0);
    session.close();
  });
}
