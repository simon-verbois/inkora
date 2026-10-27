import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/core/network/server_endpoint.dart';
import 'package:inkora/features/library/data/cover_repository.dart';
import 'package:inkora/features/library/presentation/series_header.dart';
import 'package:inkora/features/settings/domain/ui_preferences.dart';
import 'package:inkora/reader/data/page_network_gate.dart';
import 'package:inkora/reader/domain/page_source.dart';

import '../../support/catalogue_artwork.dart';
import '../../support/connection_fakes.dart';
import 'series_detail_widget_test.dart' show openSeries;

void main() {
  for (final dpr in [1.0, 1.5, 2.125]) {
    for (final appearance in [AppAppearance.light, AppAppearance.dark]) {
      testWidgets('wide series backdrop has no moving edge at $dpr/$appearance', (
        tester,
      ) async {
        final cover = (await tester.runAsync(() => demonstrationCover(1)))!;
        final directory = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('inkora-series-backdrop-'),
        ))!;
        final adapter = FixtureAdapter(
          (_) => ResponseBody.fromBytes(
            cover,
            200,
            headers: {
              'content-type': ['image/png'],
            },
          ),
        );
        final client = fixtureClient(
          ServerEndpoint('https://example.test'),
          savedSession.credentials,
          adapter,
        );
        final repository = CoverRepository(
          client,
          PageNetworkGate(),
          directory,
          savedSession.accountId,
        );
        await tester.runAsync(() async {
          for (final id in ['series-a', 'v1', 'v2', 'v3', 'v4', 'v5', 'v6']) {
            await repository.load((
              kind: id == 'series-a' ? 'series' : 'book',
              id: id,
              modified: 0,
            ), CancellationController());
          }
        });
        const capture = Key('series-backdrop-capture');
        final harness = await openSeries(
          tester,
          size: const Size(1280, 800),
          covers: repository,
          captureKey: capture,
          appearance: appearance,
        );
        addTearDown(() async {
          repository.close();
          await tester.runAsync(() async {
            await repository.flush();
            await directory.delete(recursive: true);
          });
        });
        tester.view.physicalSize = Size(1280 * dpr, 800 * dpr);
        tester.view.devicePixelRatio = dpr;
        for (var i = 0; i < 8; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pumpAndSettle();
        }
        final pane = find.byKey(const Key('series-about-pane'));
        final backdrop = find.byType(SeriesBackdrop);
        expect(backdrop, findsOneWidget);
        final sourceCalls = adapter.requests.length;
        Future<Uint8List> marginPixels() async {
          final image = await tester
              .renderObject<RenderRepaintBoundary>(find.byKey(capture))
              .toImage(pixelRatio: dpr);
          final data = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          final pixels = BytesBuilder();
          // A text-free vertical margin crosses the former hero boundary.
          for (var y = 90; y < 700; y++) {
            final offset =
                ((y * dpr).floor() * image.width + (4 * dpr).floor()) * 4;
            pixels.add(data.buffer.asUint8List(offset, 4));
          }
          image.dispose();
          return pixels.takeBytes();
        }

        final before = (await tester.runAsync(marginPixels))!;
        final scroll = tester
            .state<ScrollableState>(
              find
                  .descendant(of: pane, matching: find.byType(Scrollable))
                  .first,
            )
            .position;
        for (var i = 0; i < 20; i++) {
          scroll.jumpTo((i + 1) * 7.3);
          await tester.pump();
        }
        expect(await tester.runAsync(marginPixels), before);
        expect(tester.getRect(backdrop), tester.getRect(pane));
        expect(adapter.requests.length, sourceCalls);
        if (const bool.fromEnvironment('CAPTURE_SERIES_BACKDROP')) {
          await tester.runAsync(() async {
            final image = await tester
                .renderObject<RenderRepaintBoundary>(find.byKey(capture))
                .toImage(pixelRatio: dpr);
            final bytes = (await image.toByteData(
              format: ui.ImageByteFormat.png,
            ))!;
            final file = File(
              'artifacts/settings-series-followup/series-$dpr-${appearance.name}.png',
            );
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes.buffer.asUint8List());
            image.dispose();
          });
        }
        await harness.close(tester);
      });
    }
  }
}
