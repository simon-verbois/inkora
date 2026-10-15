import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inkora/reader/application/reader_network_policy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:inkora/core/storage/app_database.dart';
import 'package:inkora/core/errors/failure_kind.dart';
import 'package:inkora/reader/data/reader_asset_store.dart';
import 'package:inkora/reader/data/reader_repository.dart';
import 'package:inkora/reader/data/tiered_page_source.dart';
import 'package:inkora/reader/data/prefetch_session.dart';
import 'package:inkora/reader/data/encoded_page_cache.dart';
import 'package:inkora/reader/domain/content_key.dart';
import 'package:inkora/reader/domain/page_source.dart';
import 'package:inkora/reader/domain/prefetch_policy.dart';
import 'package:inkora/reader/domain/reader_manifest.dart';
import 'package:inkora/reader/domain/reading_settings.dart';
import 'package:inkora/reader/domain/reader_trace.dart';
import 'package:inkora/reader/presentation/reader_viewport.dart';

import '../test/reader/presentation/webtoon_decode_admission_test.dart'
    as admission;

/// Explicit, GET-only loopback fixture service (adb reverse tcp:18765).
/// The host supplies private real pages or generated representative fixtures;
/// credentials, personal stores and progress never enter this probe.
class ProbeSource implements BudgetedPageSource {
  ProbeSource(this.rows, this.config);
  final Map<String, dynamic> config;
  final List<dynamic> rows;
  final http = HttpClient();
  bool offline = false;
  Future<Uint8List> get(
    String path, {
    int maximumBytes = 32 * 1024 * 1024,
  }) async {
    final request = await http.getUrl(
      Uri.parse('http://127.0.0.1:18765/$path'),
    );
    final response = await request.close();
    if (response.statusCode != 200) throw StateError('Fixture HTTP failed');
    final builder = BytesBuilder(copy: false);
    await for (final chunk in response) {
      if (builder.length + chunk.length > maximumBytes) {
        throw const ReaderFailure(
          FailureKind.corruptContent,
          'Fixture reservation exceeded',
        );
      }
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  @override
  Future<EncodedPage> read(
    ContentKey key, {
    required CancellationSignal cancellation,
  }) async {
    return readWithinBudget(
      key,
      cancellation: cancellation,
      maximumBytes: 32 * 1024 * 1024,
    );
  }

  @override
  Future<EncodedPage> readWithinBudget(
    ContentKey key, {
    required CancellationSignal cancellation,
    required int maximumBytes,
  }) async {
    final delay = config['delayMs'] as int? ?? 0;
    if (delay > 0) await Future<void>.delayed(Duration(milliseconds: delay));
    if (config['errorIndex'] == key.pageIndex) {
      throw const ReaderFailure(
        FailureKind.transientNetwork,
        'Deliberate fixture failure',
      );
    }
    if (offline) {
      throw const ReaderFailure(
        FailureKind.offlineUnavailable,
        'Offline fixture',
      );
    }
    final bytes = await get(
      '${rows[key.pageIndex]['sourceIndex']}.img',
      maximumBytes: maximumBytes,
    );
    if (cancellation.isCancelled) {
      throw const ReaderFailure(FailureKind.cancelled, 'Cancelled');
    }
    return EncodedPage(
      key: key,
      bytes: bytes,
      mediaType: rows[key.pageIndex]['mediaType'] as String,
    );
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized()
    ..framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('representative long-strip trace and endurance', (tester) async {
    PaintingBinding.instance.imageCache.maximumSizeBytes = 48 * 1024 * 1024;
    const definedSeconds = int.fromEnvironment('WEBTOON_SOAK_SECONDS');
    final client = HttpClient();
    final response = await (await client.getUrl(
      Uri.parse('http://127.0.0.1:18765/manifest.json'),
    )).close();
    final rows =
        jsonDecode(await utf8.decoder.bind(response).join()) as List<dynamic>;
    final configResponse = await (await client.getUrl(
      Uri.parse('http://127.0.0.1:18765/probe-config.json'),
    )).close();
    final config = configResponse.statusCode == 200
        ? jsonDecode(await utf8.decoder.bind(configResponse).join())
              as Map<String, dynamic>
        : <String, dynamic>{};
    client.close();
    final seconds = config['soakSeconds'] as int? ?? definedSeconds;
    if (config.containsKey('constrained') || config.containsKey('paused')) {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        ReaderNetworkPolicy.channel,
        (call) async => call.method == 'events'
            ? false
            : {
                'metered': config['constrained'] == true,
                'dataSaver': config['paused'] == true,
              },
      );
    }
    final source = ProbeSource(rows, config);
    final root = await Directory(
      '${(await getTemporaryDirectory()).path}/webtoon-probe-${DateTime.now().microsecondsSinceEpoch}',
    ).create();
    final db = AppDatabase(
      NativeDatabase.createInBackground(File('${root.path}/probe.sqlite')),
    );
    final assets = ReaderAssetStore(
      db,
      Directory('${root.path}/cache'),
      Directory('${root.path}/download'),
    );
    final memory = EncodedPageCache();
    final manifest = ReaderManifest(
      accountId: 'webtoon-probe',
      bookId: 'private-fixture',
      revision: 'v1',
      title: 'Webtoon probe',
      pages: [
        for (final row in rows)
          PageDimensions(
            row['width'] as int,
            row['height'] as int,
            sizeBytes: config['underestimate'] == true
                ? 1
                : row['bytes'] as int,
          ),
      ],
    );
    final gate = PageNetworkGate();
    final tiered = TieredPageSource(
      manifest,
      assets,
      source,
      gate,
      memory: memory,
    );
    if (config['storage'] == 'download') {
      final verified = <int, DownloadAsset>{};
      for (var i = 0; i < rows.length; i++) {
        final file = File('${root.path}/$i.img');
        await file.writeAsBytes(
          await source.get('${rows[i]['sourceIndex']}.img'),
        );
        verified[i] = await inspectDownloadAsset(
          file,
          rows[i]['mediaType'] as String,
        );
      }
      await assets.installVerifiedDownload(
        manifest,
        verified,
        CancellationController(),
      );
    } else if (config['storage'] == 'cache') {
      for (var i = 0; i < rows.length; i++) {
        await tiered.read(
          manifest.key(i),
          cancellation: CancellationController(),
        );
      }
      memory.clear();
    }
    source.offline = config['offline'] == true;
    final session = PrefetchSession(
      manifest,
      tiered,
      PrefetchPolicy(gate.estimate),
      memory,
    );
    final clock = Stopwatch()..start();
    final startedUtcUs = DateTime.now().microsecondsSinceEpoch;
    ReaderLocator? lastLocator;
    final events = <Map<String, Object?>>[];
    ReaderTrace.sink = (stage, page, data) {
      if (events.length < 100000) {
        events.add({
          'us': clock.elapsedMicroseconds,
          'stage': stage,
          'page': page,
          ...data,
        });
      }
    };
    final timings = <Map<String, int>>[];
    var recordShortFrames = true;
    var soakFrames = 0, soakOverBudget = 0;
    final soakHistogram = List<int>.filled(1001, 0);
    var soakStartUs = 0;
    void frames(List<ui.FrameTiming> batch) {
      for (final frame in batch) {
        if (!recordShortFrames) {
          final micros =
              frame.buildDuration.inMicroseconds >
                  frame.rasterDuration.inMicroseconds
              ? frame.buildDuration.inMicroseconds
              : frame.rasterDuration.inMicroseconds;
          soakFrames++;
          if (micros >
              1000000 /
                  ui
                      .PlatformDispatcher
                      .instance
                      .views
                      .first
                      .display
                      .refreshRate) {
            soakOverBudget++;
          }
          soakHistogram[(micros ~/ 100).clamp(0, 1000)]++;
        } else if (timings.length < 10000) {
          timings.add({
            'us': clock.elapsedMicroseconds,
            'build': frame.buildDuration.inMicroseconds,
            'raster': frame.rasterDuration.inMicroseconds,
          });
        }
      }
    }

    binding.addTimingsCallback(frames);
    final rss = <Map<String, int>>[];
    Timer? sampler;
    final quality = ValueNotifier(
      ReadingSettings(
        mode: ReadingMode.webtoon,
        webtoonQuality: config['quality'] == 'balanced'
            ? WebtoonQuality.balanced
            : WebtoonQuality.sharp,
      ),
    );
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<ReadingSettings>(
            valueListenable: quality,
            builder: (context, settings, _) => ReaderViewport(
              reader: OpenReader(
                manifest,
                tiered,
                ReaderLocator(7, .5),
                prefetch: session,
              ),
              settings: settings,
              onLocatorChanged: (locator) => lastLocator = locator,
              controlsVisible: false,
              saveLocator: (_) async {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 5));
      final list = find.byKey(const Key('webtoon-reader'));
      final controller = tester.widget<ListView>(list).controller!;
      // Timed gestures let real frames run at the device's refresh rate.
      Future<void> swipe(bool down, int ms, double distance) async {
        await tester.timedDragFrom(
          tester.getCenter(list) + Offset(0, down ? 230 : -230),
          Offset(0, down ? -distance : distance),
          Duration(milliseconds: ms),
          frequency: 120,
        );
        await tester.pump(const Duration(milliseconds: 80));
      }

      for (var repeat = 0; repeat < 3; repeat++) {
        for (var i = 0; i < 8; i++) {
          await swipe(true, 70, 700);
        }
        for (var i = 0; i < 8; i++) {
          await swipe(false, 70, 700);
        }
      }
      await tester.pump(const Duration(seconds: 1));
      if (config['rotate'] == true) {
        controller.jumpTo(controller.offset);
        await tester.pump(const Duration(milliseconds: 100));
        final before = lastLocator;
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
        ]);
        await tester.pump(const Duration(seconds: 2));
        final after = lastLocator;
        expect(after?.pageIndex, before?.pageIndex);
        expect(after?.fraction, closeTo(before?.fraction ?? 0, .01));
        for (var i = 0; i < 8; i++) {
          await swipe(i < 4, 100, 500);
        }
        await SystemChrome.setPreferredOrientations([]);
        await tester.pump(const Duration(seconds: 1));
      }
      if (config['qualityChange'] == true) {
        controller.jumpTo(controller.offset);
        await tester.pump(const Duration(milliseconds: 100));
        final before = lastLocator;
        quality.value = const ReadingSettings(
          mode: ReadingMode.webtoon,
          webtoonQuality: WebtoonQuality.balanced,
        );
        await tester.pump(const Duration(seconds: 1));
        expect(lastLocator?.pageIndex, before?.pageIndex);
        expect(lastLocator?.fraction, closeTo(before?.fraction ?? 0, .01));
        for (var i = 0; i < 8; i++) {
          await swipe(i < 4, 100, 500);
        }
      }
      expect(tester.takeException(), isNull);
      final shortEnd = clock.elapsedMicroseconds;
      if (seconds > 0) {
        ReaderTrace.sink = null;
        // Visit the entire chapter before the memory baseline. These are
        // warmup jumps, excluded from the timed, gesture-driven endurance.
        for (var i = 0; i < rows.length; i++) {
          controller.jumpTo(
            controller.position.maxScrollExtent * i / (rows.length - 1),
          );
          await tester.pump(const Duration(milliseconds: 400));
        }
        recordShortFrames = false;
        soakStartUs = clock.elapsedMicroseconds;
        sampler = Timer.periodic(
          const Duration(seconds: 5),
          (_) => rss.add({
            'us': clock.elapsedMicroseconds,
            'rss': ProcessInfo.currentRss,
            'encodedBytes': memory.bytes,
            'decodedRetainedBytes':
                PaintingBinding.instance.imageCache.currentSizeBytes,
            'liveImages': PaintingBinding.instance.imageCache.liveImageCount,
          }),
        );
        rss.add({
          'us': clock.elapsedMicroseconds,
          'rss': ProcessInfo.currentRss,
        });
        final soak = Stopwatch()..start();
        var down = true;
        var gestures = 0;
        while (soak.elapsed.inSeconds < seconds) {
          if (controller.offset >= controller.position.maxScrollExtent - 1000) {
            down = false;
          }
          if (controller.offset < 1000) down = true;
          await swipe(down, 220, 650);
          gestures++;
        }
        rss.add({
          'us': clock.elapsedMicroseconds,
          'rss': ProcessInfo.currentRss,
        });
        binding.reportData = {
          'soakSeconds': soak.elapsedMilliseconds / 1000,
          'soakFrames': soakFrames,
          'soakOverBudget': soakOverBudget,
          'soakHistogram100us': soakHistogram,
          'soakStartUs': soakStartUs,
          'soakEndUs': clock.elapsedMicroseconds,
          'gestures': gestures,
        };
      }
      binding.reportData = {
        ...?binding.reportData,
        'mode': kProfileMode
            ? 'profile'
            : kReleaseMode
            ? 'release'
            : 'debug',
        'shortEndUs': shortEnd,
        'startedUtcUs': startedUtcUs,
        'config': config,
        'tiers': tiered.tierHits,
        'encodedMemoryBytes': memory.bytes,
        'gatePeak': gate.peakActive,
        'events': events,
        'frames': timings,
        'rss': rss,
        'pages': rows,
      };
    } finally {
      sampler?.cancel();
      ReaderTrace.sink = null;
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        ReaderNetworkPolicy.channel,
        null,
      );
      binding.removeTimingsCallback(frames);
      await tester.pumpWidget(const SizedBox.shrink());
      quality.dispose();
      session.close();
      tiered.close();
      source.http.close(force: true);
      await db.close();
      await root.delete(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 40)));
  admission.main();
}
