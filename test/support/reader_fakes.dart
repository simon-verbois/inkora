import 'dart:async';
import 'dart:convert';

import 'package:inkora/core/errors/failure_kind.dart';
import 'package:inkora/reader/domain/content_key.dart';
import 'package:inkora/reader/domain/page_source.dart';
import 'package:inkora/reader/domain/reader_manifest.dart';

final fixtureRaster = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+ip1sAAAAASUVORK5CYII=',
);
ReaderManifest readerManifest({
  String account = 'reader-account',
  String book = 'reader-book',
  String revision = 'revision-a',
  int count = 4,
  List<PageDimensions>? dimensions,
}) => ReaderManifest(
  accountId: account,
  bookId: book,
  revision: revision,
  title: 'Fixture reader',
  libraryId: 'library',
  seriesId: 'series',
  pages:
      dimensions ??
      List.generate(
        count,
        (_) => PageDimensions(100, 150, sizeBytes: fixtureRaster.length),
      ),
);

class FixturePageSource implements PageSource {
  final requests = <ContentKey>[];
  final cancelled = <ContentKey>[];
  bool offline = false;
  bool hold = false;
  final pending = <ContentKey, Completer<EncodedPage>>{};
  @override
  Future<EncodedPage> read(
    ContentKey key, {
    required CancellationSignal cancellation,
  }) async {
    requests.add(key);
    if (cancellation.isCancelled) {
      throw const ReaderFailure(FailureKind.cancelled, 'Cancelled');
    }
    if (offline) {
      throw const ReaderFailure(FailureKind.offlineUnavailable, 'Offline');
    }
    final page = EncodedPage(
      key: key,
      bytes: fixtureRaster,
      mediaType: 'image/png',
    );
    if (!hold) return page;
    final completer = Completer<EncodedPage>();
    pending[key] = completer;
    cancellation.whenCancelled.then((_) {
      if (!completer.isCompleted) {
        cancelled.add(key);
        completer.completeError(
          const ReaderFailure(FailureKind.cancelled, 'Cancelled'),
        );
      }
    });
    return completer.future;
  }

  void complete(ContentKey key) => pending[key]!.complete(
    EncodedPage(key: key, bytes: fixtureRaster, mediaType: 'image/png'),
  );
}
