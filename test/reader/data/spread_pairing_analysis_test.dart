import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inkora/reader/application/reader_providers.dart';
import 'package:inkora/core/storage/app_database.dart';
import 'package:inkora/reader/data/reader_asset_store.dart';
import 'package:inkora/reader/data/reader_repository.dart';
import 'package:inkora/reader/data/reader_store.dart';
import 'package:inkora/reader/data/spread_pairing_analysis.dart';
import 'package:inkora/reader/data/tiered_page_source.dart';
import 'package:inkora/reader/domain/page_source.dart';
import 'package:inkora/reader/domain/reader_manifest.dart';
import 'package:inkora/reader/domain/reading_settings.dart';

import '../../support/connection_fakes.dart';
import '../../support/reader_fakes.dart';

void main() {
  late AppDatabase database;
  late Directory folder;
  late ReaderRepository repository;
  var requests = 0;
  setUp(() async {
    requests = 0;
    database = AppDatabase(NativeDatabase.memory());
    folder = await Directory.systemTemp.createTemp('inkora-pairing-');
    final client = fixtureClient(
      savedSession.endpoint,
      savedSession.credentials,
      FixtureAdapter((_) {
        requests++;
        throw StateError('No analysis network');
      }),
    );
    addTearDown(client.close);
    repository = ReaderRepository(
      ReaderStore(database, 'reader-account'),
      ReaderAssetStore(
        database,
        Directory('${folder.path}/cache'),
        Directory('${folder.path}/downloads'),
      ),
      client,
      PageNetworkGate(),
      isCurrent: () => true,
    );
  });
  tearDown(() async {
    repository.close();
    await repository.assets.idle;
    await database.close();
    await folder.delete(recursive: true);
  });
  test('opening analysis writes once, stays stable and never requests remote pages', () async {
    final manifest = readerManifest();
    await repository.prepareSpreadPairing(manifest, CancellationController());
    final first = await repository.store.overrides(
      SettingsScope.book,
      manifest.bookId,
    );
    expect(first.spreadAnalysis, isNotNull);
    final changes = await database
        .customSelect('SELECT total_changes() AS n')
        .getSingle();
    await repository.prepareSpreadPairing(manifest, CancellationController());
    expect(
      (await database.customSelect('SELECT total_changes() AS n').getSingle())
          .read<int>('n'),
      changes.read<int>('n'),
    );
    expect(requests, 0);
    expect(
      (await repository.store.overrides(
        SettingsScope.book,
        manifest.bookId,
      )).toJson(),
      first.toJson(),
    );
  });
  test(
    'Auto result is revision/account scoped and explicit manual choice wins',
    () async {
      final manifest = readerManifest();
      final store = repository.store;
      await store.saveOverrides(
        SettingsScope.global,
        '',
        const ReadingOverrides(mode: ReadingMode.manga),
      );
      await store.saveSpreadAnalysis(
        manifest,
        SpreadPairingAnalysis(
          revision: manifest.revision,
          rightToLeft: true,
          shifted: false,
        ),
      );
      expect((await store.settings(manifest).first).spreadOffset, false);
      expect(
        (await store.settings(readerManifest(revision: 'new')).first)
            .spreadOffset,
        true,
      );
      await store.toggleSpreadOffset(manifest);
      final manual = await store.settings(manifest).first;
      expect(manual.spreadPairing, SpreadPairing.shifted);
      expect(manual.spreadOffset, true);
      await store.saveSpreadAnalysis(
        manifest,
        SpreadPairingAnalysis(
          revision: manifest.revision,
          rightToLeft: true,
          shifted: false,
        ),
      );
      expect((await store.settings(manifest).first).spreadOffset, true);
      final other = ReaderStore(database, 'another-account');
      expect(
        (await other.overrides(
          SettingsScope.book,
          manifest.bookId,
        )).spreadAnalysis,
        isNull,
      );
      await expectLater(
        repository.prepareSpreadPairing(
          readerManifest(account: 'other'),
          CancellationController(),
        ),
        throwsArgumentError,
      );
    },
  );
  test(
    'late analysis merges manual choice and unrelated book settings',
    () async {
      final manifest = readerManifest();
      await repository.store.saveOverrides(
        SettingsScope.book,
        manifest.bookId,
        const ReadingOverrides(
          spreadPairing: SpreadPairing.unshifted,
          spacing: 12,
          pageAnimation: false,
        ),
      );
      await repository.store.saveSpreadAnalysis(
        manifest,
        SpreadPairingAnalysis(
          revision: manifest.revision,
          rightToLeft: false,
          shifted: true,
        ),
      );
      final value = await repository.store.settings(manifest).first;
      expect(value.spreadOffset, false);
      expect(value.spacing, 12);
      expect(value.pageAnimation, false);
    },
  );
  test('cancelled opening does not persist a fallback decision', () async {
    final cancellation = CancellationController()..cancel();
    final manifest = readerManifest();
    await repository.prepareSpreadPairing(manifest, cancellation);
    expect(
      (await repository.store.overrides(
        SettingsScope.book,
        manifest.bookId,
      )).spreadAnalysis,
      isNull,
    );
    expect(requests, 0);
  });
  test(
    'local analysis skips oversized cache entries without invalidating them',
    () async {
      final manifest = readerManifest();
      final bytes = Uint8List(300 * 1024)..setAll(0, fixtureRaster);
      await repository.assets.cache(
        EncodedPage(key: manifest.key(0), bytes: bytes, mediaType: 'image/png'),
      );
      final result = await repository.assets.readForPairing(
        manifest.key(0),
        CancellationController(),
        maximumBytes: 1024,
      );
      expect(result, isNull);
      expect(
        await repository.assets.read(
          manifest.key(0),
          'cache',
          CancellationController(),
        ),
        isNotNull,
      );
    },
  );
  test(
    'visual evidence has an eight-page limit and a cancellable deadline',
    () async {
      var calls = 0;
      await analyzeSpreadPairing(
        readerManifest(count: 100),
        rightToLeft: true,
        cancellation: CancellationController(),
        sample: (_, _) async {
          calls++;
          return null;
        },
      );
      expect(calls, 8);
      final pending = Completer<PageEdgeSample?>();
      CancellationSignal? owned;
      final result = await analyzeSpreadPairing(
        readerManifest(),
        rightToLeft: true,
        cancellation: CancellationController(),
        deadline: const Duration(milliseconds: 1),
        sample: (_, signal) {
          owned = signal;
          return pending.future;
        },
      );
      expect(result.shifted, isNull);
      expect(owned!.isCancelled, true);
      pending.complete(null);
    },
  );
  test('strong geometry bypasses visual reads', () async {
    final result = await analyzeSpreadPairing(
      readerManifest(dimensions: [PageDimensions(1400, 1000)]),
      rightToLeft: true,
      cancellation: CancellationController(),
      sample: (_, _) => throw StateError('Unexpected visual read'),
    );
    expect(result.shifted, false);
  });

  testWidgets(
    'local thumbnail sampling reads real PNG edges and composites transparent margins',
    (tester) async {
      final sample = await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);
        for (var y = 0; y < 64; y++) {
          canvas.drawRect(
            ui.Rect.fromLTWH(28, y.toDouble(), 4, 1),
            ui.Paint()
              ..color = y.isEven
                  ? const ui.Color(0xff000000)
                  : const ui.Color(0xffffffff),
          );
        }
        final picture = recorder.endRecording();
        final image = await picture.toImage(32, 64);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        picture.dispose();
        final manifest = readerManifest();
        await repository.assets.cache(
          EncodedPage(
            key: manifest.key(0),
            bytes: data!.buffer.asUint8List(),
            mediaType: 'image/png',
          ),
        );
        return LocalPairingSamples(
          repository.assets,
          manifest,
        ).read(0, CancellationController());
      });
      expect(sample, isNotNull);
      expect(sample!.left, List.filled(64, 255));
      expect(sample.right, [for (var y = 0; y < 64; y++) y.isEven ? 0 : 255]);
    },
  );

  test('entering Auto in an open reader analyzes once without publishing a provisional pairing', () async {
    final manifest = readerManifest(
      dimensions: [
        PageDimensions(1400, 1000),
        PageDimensions(700, 1000),
        PageDimensions(700, 1000),
      ],
    );
    await repository.store.saveOverrides(
      SettingsScope.global,
      '',
      const ReadingOverrides(mode: ReadingMode.manga, spreadOffset: true),
    );
    final container = ProviderContainer(
      overrides: [
        readerRepositoryProvider.overrideWith((ref) async => repository),
        openReaderProvider(manifest.bookId).overrideWith(
          (ref) async =>
              OpenReader(manifest, FixturePageSource(), ReaderLocator(0)),
        ),
      ],
    );
    addTearDown(container.dispose);
    final values = <ReadingSettings>[];
    final ready = Completer<void>();
    container.listen(readingSettingsProvider(manifest.bookId), (_, state) {
      final value = state.asData?.value;
      if (value == null) return;
      values.add(value);
      if (value.spreadPairing == SpreadPairing.automatic &&
          !value.spreadOffset &&
          !ready.isCompleted) {
        ready.complete();
      }
    }, fireImmediately: true);
    expect(
      (await container.read(readingSettingsProvider(manifest.bookId).future))
          .spreadOffset,
      true,
    );
    await repository.store.saveOverrides(
      SettingsScope.book,
      manifest.bookId,
      const ReadingOverrides(spreadPairing: SpreadPairing.automatic),
    );
    await ready.future.timeout(const Duration(seconds: 2));
    expect(
      values
          .where((v) => v.spreadPairing == SpreadPairing.automatic)
          .every((v) => !v.spreadOffset),
      true,
    );
    expect(requests, 0);
  });
}
