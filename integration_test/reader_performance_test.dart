import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:inkora/core/network/komga/komga_client.dart';
import 'package:inkora/core/network/server_endpoint.dart';
import 'package:inkora/core/storage/app_database.dart';
import 'package:inkora/features/connection/domain/session.dart';
import 'package:inkora/features/library/data/catalogue_store.dart';
import 'package:inkora/features/library/domain/catalogue.dart';
import 'package:inkora/reader/data/reader_asset_store.dart';
import 'package:inkora/reader/data/reader_repository.dart';
import 'package:inkora/reader/data/reader_store.dart';
import 'package:inkora/reader/data/tiered_page_source.dart';
import 'package:inkora/reader/domain/reader_manifest.dart';
import 'package:inkora/reader/domain/reading_settings.dart';
import 'package:inkora/reader/presentation/reader_image_provider.dart';
import 'package:inkora/reader/presentation/reader_viewport.dart';

import 'support/shaped_page_adapter.dart';

Future<Uint8List> syntheticPage() async {
  const width = 768;
  const height = 1024;
  final pixels = Uint8List(width * height * 4);
  var seed = 19;
  for (var i = 0; i < pixels.length; i += 4) {
    seed = (seed * 1664525 + 1013904223) & 0xffffffff;
    final value = ((seed >> 28) & 15) * 17;
    pixels[i] = value;
    pixels[i + 1] = value;
    pixels[i + 2] = value;
    pixels[i + 3] = 255;
  }
  final ready = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    pixels,
    width,
    height,
    ui.PixelFormat.rgba8888,
    ready.complete,
  );
  final image = await ready.future;
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return png!.buffer.asUint8List();
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized()
    ..framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('reader impairment and cache benchmark', (tester) async {
    const rtt = int.fromEnvironment('BENCH_RTT_MS', defaultValue: 250);
    final mbps = double.parse(
      const String.fromEnvironment('BENCH_MBPS', defaultValue: '10'),
    );
    const pages = int.fromEnvironment('BENCH_PAGES', defaultValue: 15);
    const dwell = int.fromEnvironment('BENCH_DWELL_MS', defaultValue: 2000);
    const soak = int.fromEnvironment('BENCH_SOAK_SECONDS');
    const jitter = int.fromEnvironment('BENCH_JITTER_MS');
    const stalls = int.fromEnvironment('BENCH_STALL_EVERY');
    const filterName = String.fromEnvironment(
      'BENCH_VISUAL_FILTER',
      defaultValue: 'original',
    );
    final filter = VisualFilter.values.byName(filterName);
    final quality = {
      for (final format in RasterFormat.values)
        format: RasterQuality(filter: filter),
    };
    final png = await syntheticPage();
    final hash = sha256.convert(png).toString();
    final root = await getApplicationCacheDirectory();
    final folder = await Directory(
      '${root.path}/reader-benchmark-${DateTime.now().microsecondsSinceEpoch}',
    ).create();
    final database = AppDatabase(
      NativeDatabase.createInBackground(
        File('${folder.path}/benchmark.sqlite'),
      ),
    );
    final adapter = ShapedPageAdapter(
      png,
      rttMs: rtt,
      mbps: mbps,
      jitterMs: jitter,
      stallEvery: stalls,
    );
    final client = KomgaClient(
      ServerEndpoint('https://benchmark.invalid'),
      Credentials.apiKey('synthetic-benchmark'),
      dio: Dio()..httpClientAdapter = adapter,
    );
    final gate = PageNetworkGate();
    final assets = ReaderAssetStore(
      database,
      Directory('${folder.path}/encoded'),
      Directory('${folder.path}/downloads'),
    );
    final repository = ReaderRepository(
      ReaderStore(database, 'synthetic'),
      assets,
      client,
      gate,
      isCurrent: () => true,
    );
    ReaderManifest manifest(String id) => ReaderManifest(
      accountId: 'synthetic',
      bookId: id,
      revision: hash,
      title: 'Synthetic benchmark',
      seriesId: 'synthetic-series',
      pages: List.generate(
        // Landscape/tablet automatic layouts advance two logical pages per
        // transition; retain enough groups for the steady and reversal runs.
        math.max(20, (pages + 4) * 2),
        (_) => PageDimensions(768, 1024, sizeBytes: png.length),
      ),
    );
    final book = manifest('first');
    final nextBook = manifest('next');
    await repository.store.saveManifest(book);
    await repository.store.saveManifest(nextBook);
    final catalogue = CatalogueStore(database, 'synthetic');
    await catalogue.stage('fixture', [
      for (final (index, m) in [book, nextBook].indexed)
        CatalogueItem(
          kind: CatalogueKind.book,
          id: m.bookId,
          title: m.title,
          seriesId: m.seriesId,
          number: index.toDouble(),
        ),
    ]);
    await catalogue.publish('fixture', DateTime.utc(2026), () => true);
    final reader = await repository.open(book.bookId);
    final settings = ValueNotifier(ReadingSettings(imageQuality: quality));
    final frameSamples = <List<int>>[];
    final framePhases = <int>[];
    final phases = <({String name, int startMicros})>[];
    void phase(String name) {
      if (phases.isEmpty || phases.last.name != name) {
        phases.add((
          name: name,
          startMicros: DateTime.now().microsecondsSinceEpoch,
        ));
      }
    }

    void frames(List<ui.FrameTiming> frames) {
      for (final frame in frames) {
        frameSamples.add([
          frame.buildDuration.inMicroseconds,
          frame.rasterDuration.inMicroseconds,
        ]);
        // Timing callbacks are batched; match the frame's wall timestamp to
        // its actual phase instead of the phase when this callback arrives.
        final finished = frame.timestampInMicroseconds(
          ui.FramePhase.rasterFinishWallTime,
        );
        framePhases.add(
          phases.lastIndexWhere((phase) => phase.startMicros <= finished),
        );
      }
      if (frameSamples.length > 200000) {
        frameSamples.removeRange(0, frameSamples.length - 200000);
        framePhases.removeRange(0, framePhases.length - 200000);
      }
    }

    binding.addTimingsCallback(frames);
    final rss = <int>[];
    final memoryTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => rss.add(ProcessInfo.currentRss),
    );
    final scenarios = <String, List<int>>{};
    Future<void> waitForPresentation(
      int previous, {
      Duration timeout = const Duration(seconds: 25),
    }) async {
      final watch = Stopwatch()..start();
      while (reader.telemetry!.presentations <= previous &&
          watch.elapsed < timeout) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
      }
      expect(reader.telemetry!.presentations, greaterThan(previous));
    }

    Future<void> transition(String scenario, String tooltip) async {
      phase(scenario);
      final before = reader.telemetry!.presentations;
      final watch = Stopwatch()..start();
      await tester.tap(find.byTooltip(tooltip));
      await tester.pump();
      await waitForPresentation(before);
      scenarios.putIfAbsent(scenario, () => []).add(watch.elapsedMicroseconds);
    }

    try {
      phase('cold');
      final cold = Stopwatch()..start();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder(
              valueListenable: settings,
              builder: (_, value, _) => ReaderViewport(
                reader: reader,
                settings: value,
                saveLocator: (_) async {},
              ),
            ),
          ),
        ),
      );
      await waitForPresentation(0);
      scenarios['cold'] = [cold.elapsedMicroseconds];
      for (var i = 0; i < pages; i++) {
        await Future<void>.delayed(const Duration(milliseconds: dwell));
        await transition(i < 3 ? 'warmup' : 'steady', 'Next page');
      }
      final warmRss = ProcessInfo.currentRss;
      for (var i = 0; i < 3; i++) {
        await transition('reversal', 'Previous page');
      }
      for (var i = 0; i < 3; i++) {
        await transition('fast', 'Next page');
      }
      // Demand at chapter end verifies actual repository ordering and next-page warming.
      phase('chapter-handoff');
      final slider = tester.widget<Slider>(
        find.byKey(const Key('reader-page-slider')),
      );
      slider.onChangeEnd!(book.pages.length - 1.0);
      await tester.pump();
      await Future<void>.delayed(Duration(milliseconds: rtt + 4000));
      expect(await repository.nextChapterId(book), nextBook.bookId);
      final chapterReady = repository.memory.contains(nextBook.key(0));
      adapter.offline = true;
      phase('offline-jump');
      // Index one belongs to the first spread in landscape. Start from the
      // second group so Previous page always produces a new presentation.
      slider.onChangeEnd!(2);
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await transition('offline-cached', 'Previous page');
      adapter.offline = false;
      phase('webtoon');
      settings.value = ReadingSettings(
        mode: ReadingMode.webtoon,
        imageQuality: quality,
      );
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 500));
      final webtoonFinder = find.byKey(const Key('webtoon-reader'));
      final scrollable = tester.state<ScrollableState>(
        find
            .descendant(of: webtoonFinder, matching: find.byType(Scrollable))
            .first,
      );
      final refresh = tester.view.display.refreshRate;
      await tester.timedDrag(
        webtoonFinder,
        const Offset(0, -600),
        const Duration(milliseconds: 400),
        frequency: refresh,
      );
      await tester.pumpAndSettle();
      // Warm the moving decoded window before the long-run memory baseline.
      // Instantaneous drags generate almost no scrolling frames on a device.
      if (soak > 0) {
        phase('webtoon-warmup');
        for (var i = 0; i < 8; i++) {
          await Future<void>.delayed(const Duration(seconds: 2));
          await tester.timedDrag(
            webtoonFinder,
            const Offset(0, -600),
            const Duration(milliseconds: 400),
            frequency: refresh,
          );
          await tester.pumpAndSettle();
        }
      }
      final soakStartRss = ProcessInfo.currentRss;
      phase('webtoon-soak');
      final soakWatch = Stopwatch()..start();
      var scrollDirection = -1.0;
      var soakGestures = 0;
      var soakReversals = 0;
      while (soakWatch.elapsed.inSeconds < soak) {
        await Future<void>.delayed(const Duration(seconds: 2));
        final position = scrollable.position;
        if ((scrollDirection < 0 &&
                position.pixels >= position.maxScrollExtent - 600) ||
            (scrollDirection > 0 &&
                position.pixels <= position.minScrollExtent + 600)) {
          scrollDirection = -scrollDirection;
          soakReversals++;
        }
        await tester.timedDrag(
          webtoonFinder,
          Offset(0, scrollDirection * 600),
          const Duration(milliseconds: 400),
          frequency: refresh,
        );
        await tester.pumpAndSettle();
        soakGestures++;
      }
      await Future<void>.delayed(const Duration(seconds: 1));
      phase('finished');
      final period = (1e6 / refresh).round();
      final overBudget = frameSamples
          .where((f) => math.max(f[0], f[1]) > period)
          .length;
      final index = await database.select(database.readerAssets).get();
      binding.reportData = {
        'mode': kProfileMode
            ? 'profile'
            : kReleaseMode
            ? 'release'
            : 'debug',
        'fixture': {
          'sha256': hash,
          'encodedBytesPerPage': png.length,
          'width': 768,
          'height': 1024,
        },
        'network': {
          'kind': 'in-process shared-bandwidth stream model',
          'rttMs': rtt,
          'mbps': mbps,
          'jitterMs': jitter,
          'retransmitStallEveryTicks': stalls,
          'tickMs': 20,
        },
        'cacheState': 'cold unique sandbox, warm after first 3 transitions',
        'dwellMs': dwell,
        'soakSeconds': soak,
        'soakElapsedMillis': soakWatch.elapsedMilliseconds,
        'soakGestures': soakGestures,
        'soakReversals': soakReversals,
        'framePolicy': 'fullyLive',
        'webtoonGestureDurationMillis': 400,
        'webtoonGestureFrequencyHz': refresh,
        'intentReadinessMicros': scenarios,
        'stages': reader.telemetry!.toJson(),
        'encodedReadyBeforeDemand': reader.prefetch!.readyBeforeDemand,
        'foregroundDemands': reader.prefetch!.foregroundDemands,
        'tierHits': (reader.source as TieredPageSource).tierHits,
        'visualFilter': filter.name,
        'imageSampling': ImageSampling.high.name,
        'webtoonQuality': settings.value.webtoonQuality.name,
        'networkRequests': adapter.requests,
        'deliveredBytesIncludingCancelled': adapter.deliveredBytes,
        'cancelledTransfers': adapter.cancelled,
        'peakNetworkConcurrency': gate.peakActive,
        'finalNetworkConcurrency': gate.limit,
        'foregroundQueueMicros': gate.foregroundQueueMicros,
        'encodedMemoryBytes': repository.memory.bytes,
        'encodedDiskBytes': index.fold<int>(
          0,
          (sum, row) => sum + (row.tier == 'cache' ? row.byteLength : 0),
        ),
        'decodedKeepAliveBytes':
            PaintingBinding.instance.imageCache.currentSizeBytes,
        'decodedLiveImages': PaintingBinding.instance.imageCache.liveImageCount,
        'chapterFirstPageEncodedReady': chapterReady,
        'rssSamplesBytes': rss,
        'rssAfterWarmupBytes': warmRss,
        'rssAtWebtoonSoakStartBytes': soakStartRss,
        'rssFinalBytes': ProcessInfo.currentRss,
        'refreshRate': refresh,
        'viewport': {
          'width':
              tester.view.physicalSize.width / tester.view.devicePixelRatio,
          'height':
              tester.view.physicalSize.height / tester.view.devicePixelRatio,
          'pixelRatio': tester.view.devicePixelRatio,
        },
        'frameBudgetMicros': period,
        'frames': frameSamples,
        'framePhaseIndexes': framePhases,
        'framePhases': [
          for (final value in phases)
            {'name': value.name, 'startMicros': value.startMicros},
        ],
        'overBudgetFrames': overBudget,
        'limitations': [
          'Stream model is not OS packet shaping.',
          'Dart/external memory and physical 30-minute acceptance require separate profile capture.',
          'Debug/emulator runs cannot establish performance targets.',
        ],
      };
      expect(
        repository.memory.bytes,
        lessThanOrEqualTo(repository.memory.maximumBytes),
      );
      expect(gate.speculativeBytes, lessThanOrEqualTo(32 * 1024 * 1024));
      expect(tester.takeException(), isNull);
    } finally {
      memoryTimer.cancel();
      binding.removeTimingsCallback(frames);
      await tester.pumpWidget(const SizedBox());
      repository.close();
      client.close();
      settings.dispose();
      ReaderDecodedCache.clearAccount('synthetic');
      await assets.idle;
      await database.close();
      await folder.delete(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 60)));
}
