import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/reader/application/reader_network_policy.dart';
import 'package:inkora/reader/data/encoded_page_cache.dart';
import 'package:inkora/reader/data/prefetch_session.dart';
import 'package:inkora/reader/data/page_network_gate.dart';
import 'package:inkora/reader/data/reader_repository.dart';
import 'package:inkora/reader/domain/content_key.dart';
import 'package:inkora/reader/domain/page_source.dart';
import 'package:inkora/reader/domain/prefetch_policy.dart';
import 'package:inkora/reader/domain/reader_manifest.dart';
import 'package:inkora/reader/domain/reading_settings.dart';
import 'package:inkora/reader/presentation/reader_viewport.dart';

import '../../support/reader_fakes.dart';
import '../../support/reader_widget_support.dart';

class _Ahead extends FixturePageSource implements PrioritizedPageSource {
  @override
  Future<EncodedPage> readAhead(
    ContentKey key, {
    required CancellationSignal cancellation,
    required PageRequest request,
  }) => read(key, cancellation: cancellation);
  @override
  Future<void> invalidate(ContentKey key) async {}
}

void main() {
  for (final mode in [ReadingMode.comics, ReadingMode.webtoon]) {
    for (final startHidden in [false, true]) {
      testWidgets(
        'inactive $mode keeps speculation/policy/warming stopped across resume and resize (initial=$startHidden)',
        (tester) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          var policyCalls = 0;
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            ReaderNetworkPolicy.channel,
            (call) async {
              if (call.method == 'events') return false;
              policyCalls++;
              return {'metered': false, 'dataSaver': false};
            },
          );
          addTearDown(
            () => tester.binding.defaultBinaryMessenger
                .setMockMethodCallHandler(ReaderNetworkPolicy.channel, null),
          );
          final manifest = readerManifest(count: 30);
          final ahead = _Ahead()..hold = true;
          final memory = EncodedPageCache();
          final session = PrefetchSession(
            manifest,
            ahead,
            PrefetchPolicy(ReaderNetworkEstimate()),
            memory,
          );
          addTearDown(session.close);
          final reader = OpenReader(
            manifest,
            FixturePageSource(),
            ReaderLocator(1, .2),
            prefetch: session,
          );
          final active = ValueNotifier(!startHidden);
          addTearDown(active.dispose);
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: ValueListenableBuilder<bool>(
                  valueListenable: active,
                  builder: (_, enabled, _) => ReaderViewport(
                    reader: reader,
                    settings: ReadingSettings(mode: mode),
                    active: enabled,
                    controlsVisible: false,
                    saveLocator: (_) async {},
                  ),
                ),
              ),
            ),
          );
          await settleReaderImages(tester);
          final viewport = find.byType(ReaderViewport);
          final owner = tester.state(viewport);
          if (startHidden) {
            expect(session.pending, 0);
            expect(policyCalls, 0);
            active.value = true;
            await settleReaderImages(tester);
          }
          expect(session.pending, greaterThan(0));
          active.value = false;
          await tester.pump();
          expect(session.pending, 0);
          final reads = ahead.requests.length;
          final calls = policyCalls;
          final misses = memory.misses;
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.paused,
          );
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          tester.view.physicalSize = const Size(480, 844);
          await tester.pump();
          for (var i = 0; i < 12; i++) {
            await tester.pump(const Duration(milliseconds: 50));
          }
          expect(session.pending, 0);
          expect(ahead.requests.length, reads);
          expect(policyCalls, calls);
          expect(
            memory.misses,
            misses,
            reason: 'No 50ms speculative decode-warming scans while covered',
          );
          expect(tester.state(viewport), same(owner));
          active.value = true;
          await settleReaderImages(tester);
          expect(session.pending, greaterThan(0));
          expect(policyCalls, greaterThan(calls));
          expect(tester.state(viewport), same(owner));
          await tester.pumpWidget(const SizedBox.shrink());
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
