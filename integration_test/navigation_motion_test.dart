import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:inkora/app/router.dart';
import 'package:inkora/core/storage/app_database.dart';
import 'package:inkora/app/widgets/inkora_widgets.dart';
import 'package:inkora/features/library/data/cover_repository.dart';
import 'package:inkora/features/library/domain/catalogue.dart';
import 'package:inkora/features/library/domain/resume_entry.dart';
import 'package:inkora/features/library/presentation/library_screen.dart';
import 'package:inkora/features/settings/domain/ui_preferences.dart';
import 'package:inkora/reader/data/page_network_gate.dart';

import '../test/support/catalogue_artwork.dart';
import '../test/support/catalogue_fakes.dart';
import '../test/support/connection_fakes.dart';
import '../test/support/ui_harness.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized()
    ..framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('library home navigation motion on synthetic catalogue', (
    tester,
  ) async {
    final root = await Directory(
      '${(await getTemporaryDirectory()).path}/navigation-motion-${DateTime.now().microsecondsSinceEpoch}',
    ).create();
    final artwork = [
      for (var i = 0; i < demonstrationTitles.length; i++)
        await demonstrationCover(i),
    ];
    var requests = 0;
    final client = fixtureClient(
      savedSession.endpoint,
      savedSession.credentials,
      FixtureAdapter((request) {
        requests++;
        final id = request.uri.pathSegments.reversed.skip(1).first;
        final index = int.tryParse(id.split('-').last) ?? 0;
        return ResponseBody.fromBytes(
          artwork[index % artwork.length],
          200,
          headers: {
            'content-type': ['image/png'],
          },
        );
      }),
    );
    final coverDirectory = await Directory('${root.path}/covers').create();
    final covers = CoverRepository(
      client,
      PageNetworkGate(),
      coverDirectory,
      savedSession.accountId,
    );
    final series = [
      for (var i = 0; i < 250; i++)
        entry(
          'series-$i',
          kind: CatalogueKind.series,
          title:
              '${i.toString().padLeft(3, '0')} · ${demonstrationTitles[i % artwork.length]}',
        ),
    ];
    final books = [
      for (var i = 0; i < 3; i++)
        entry('book-$i', seriesId: 'series-$i', title: 'Volume ${i + 1}'),
    ];
    final harness = await UiHarness.create(
      tester,
      databaseOverride: AppDatabase(
        NativeDatabase.createInBackground(
          File('${root.path}/catalogue.sqlite'),
        ),
      ),
      covers: covers,
      preferences: const UiPreferences(
        appearance: AppAppearance.forest,
        locale: 'en',
      ),
      catalogue: [
        entry(
          'library-a',
          kind: CatalogueKind.library,
          title: 'Demonstration library',
        ),
        ...series,
        ...books,
      ],
      resumeEntries: [
        for (var i = 0; i < 3; i++)
          ResumeEntry(
            item: books[i],
            seriesTitle: series[i].title,
            pageIndex: 3 + i,
            pageCount: 10,
            fraction: 0,
          ),
      ],
    );
    addTearDown(() async {
      await harness.close(tester);
      await covers.flush();
      covers.close();
      client.close();
      if (await root.exists()) await root.delete(recursive: true);
    });
    await harness.mount(tester);
    final router = harness.container.read(routerProvider);
    // Warm all destinations and the one detail before comparing motion.
    for (final path in ['/downloads', '/settings', '/']) {
      router.go(path);
      await tester.pumpAndSettle();
    }
    router.push<void>('/catalogue/series/series-0');
    await tester.pumpAndSettle();
    router.pop();
    await tester.pumpAndSettle();
    final results = <Map<String, Object?>>[];
    final phases = <({String name, int start})>[];
    final frames = <({int timestamp, int build, int raster})>[];
    void timings(List<ui.FrameTiming> values) {
      for (final value in values) {
        frames.add((
          timestamp: value.timestampInMicroseconds(
            ui.FramePhase.rasterFinishWallTime,
          ),
          build: value.buildDuration.inMicroseconds,
          raster: value.rasterDuration.inMicroseconds,
        ));
      }
    }

    binding.addTimingsCallback(timings);
    try {
      debugPrint('NAV_VISUAL_READY');
      await tester.pump(const Duration(seconds: 2));
      for (final phase in ['tabs', 'details', 'sheets', 'scroll']) {
        phases.add((name: phase, start: DateTime.now().microsecondsSinceEpoch));
        final before = requests;
        final rss = ProcessInfo.currentRss;
        debugPrint('NAV_PHASE_$phase');
        for (var i = 0; i < 12; i++) {
          if (phase == 'tabs') {
            for (final destination in ['downloads', 'settings', 'libraries']) {
              await tester.tap(find.byKey(ValueKey('navigation-$destination')));
              await tester.pump(const Duration(milliseconds: 280));
            }
          } else if (phase == 'details') {
            router.push<void>('/catalogue/series/series-0');
            await tester.pump(const Duration(milliseconds: 300));
            router.pop();
            await tester.pump(const Duration(milliseconds: 260));
          } else if (phase == 'sheets') {
            final context = tester.element(find.byType(LibraryScreen));
            showInkSheet<void>(
              context: context,
              child: const SizedBox(
                height: 200,
                child: Center(child: Text('Fixture panel')),
              ),
            );
            await tester.pump(const Duration(milliseconds: 300));
            Navigator.of(context, rootNavigator: true).pop();
            await tester.pump(const Duration(milliseconds: 240));
          } else {
            final scroll = find
                .descendant(
                  of: find.byType(CustomScrollView),
                  matching: find.byType(Scrollable),
                )
                .first;
            await tester.timedDrag(
              scroll,
              Offset(0, i.isEven ? -500 : 500),
              const Duration(milliseconds: 400),
            );
            await tester.pump(const Duration(milliseconds: 200));
          }
          expect(tester.takeException(), isNull);
        }
        results.add({
          'phase': phase,
          'requestsBefore': before,
          'requestsAfter': requests,
          'rssBefore': rss,
          'rssAfter': ProcessInfo.currentRss,
        });
        if (phase == 'tabs') {
          expect(
            requests,
            before,
            reason: 'Warmed peer transitions must not reload artwork',
          );
        }
      }
      await tester.pump(const Duration(seconds: 1));
      for (var i = 0; i < phases.length; i++) {
        results[i]['frames'] = [
          for (final f in frames)
            if (f.timestamp >= phases[i].start &&
                (i == phases.length - 1 || f.timestamp < phases[i + 1].start))
              [f.build, f.raster],
        ];
      }
      binding.reportData = {
        'mode': kProfileMode ? 'profile' : 'debug',
        'kind': 'navigation motion',
        'refreshRate': tester.view.display.refreshRate,
        'physicalSize': [
          tester.view.physicalSize.width,
          tester.view.physicalSize.height,
        ],
        'pixelRatio': tester.view.devicePixelRatio,
        'results': results,
        'limitations': [
          'Short local synthetic navigation comparison; no network or reader 30-minute acceptance claim.',
        ],
      };
    } finally {
      binding.removeTimingsCallback(timings);
    }
  });
}
