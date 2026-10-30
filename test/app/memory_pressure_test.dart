import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/memory_pressure.dart';
import 'package:inkora/features/library/application/cover_providers.dart';
import 'package:inkora/features/library/data/cover_repository.dart';
import 'package:inkora/reader/data/page_network_gate.dart';

import '../support/connection_fakes.dart';

void main() {
  testWidgets(
    'active caches trim once and disposed observers stop receiving pressure',
    (tester) async {
      final client = fixtureClient(
        savedSession.endpoint,
        savedSession.credentials,
        FixtureAdapter((_) => throw StateError('Unexpected network request')),
      );
      final cover = CoverRepository(
        client,
        PageNetworkGate(),
        Directory.systemTemp,
        'pressure-test',
      );
      addTearDown(() {
        cover.close();
        client.close();
      });
      final container = ProviderContainer(
        overrides: [coverRepositoryProvider.overrideWith((ref) async => cover)],
      );
      final cache = container.listen(coverRepositoryProvider, (_, _) {});
      final ready = container.read(coverRepositoryProvider.future);
      await tester.pump();
      await ready;
      final originalGeneration = cover.generation;
      final observer = container.listen(memoryPressureProvider, (_, _) {});
      tester.binding.handleMemoryPressure();
      await tester.pump();
      expect(cover.generation, originalGeneration + 1);
      final trimmedGeneration = cover.generation;
      observer.close();
      cache.close();
      container.dispose();
      tester.binding.handleMemoryPressure();
      await tester.pump();
      expect(cover.generation, trimmedGeneration);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'memory pressure does not initialize an inactive cover repository',
    (tester) async {
      var initializations = 0;
      final container = ProviderContainer(
        overrides: [
          coverRepositoryProvider.overrideWith((ref) async {
            initializations++;
            return null;
          }),
        ],
      );
      final observer = container.listen(memoryPressureProvider, (_, _) {});
      tester.binding.handleMemoryPressure();
      await tester.pump();
      expect(initializations, 0);
      expect(container.exists(coverRepositoryProvider), isFalse);
      observer.close();
      container.dispose();
      tester.binding.handleMemoryPressure();
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}
