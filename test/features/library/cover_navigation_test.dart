import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/core/network/server_endpoint.dart';
import 'package:inkora/features/connection/application/session_controller.dart';
import 'package:inkora/features/library/application/cover_providers.dart';
import 'package:inkora/features/library/data/cover_repository.dart';
import 'package:inkora/features/library/presentation/book_cover.dart';
import 'package:inkora/reader/data/page_network_gate.dart';
import 'package:inkora/reader/domain/page_source.dart';

import '../../support/catalogue_fakes.dart';
import '../../support/connection_fakes.dart';
import '../../support/reader_fakes.dart';

void main() {
  testWidgets(
    'warm navigation presents the same decoded cover on the first frame, including offstage',
    (tester) async {
      final directory = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('inkora-cover-navigation-'),
      ))!;
      final adapter = FixtureAdapter(
        (_) => ResponseBody.fromBytes(
          fixtureRaster,
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
        'account',
      );
      const key = (kind: 'book', id: 'book', modified: 1);
      final bytes = await tester.runAsync(
        () => repository.load(key, CancellationController()),
      );
      final container = ProviderContainer(
        overrides: [
          coverRepositoryProvider.overrideWithValue(AsyncData(repository)),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await tester.runAsync(repository.flush);
        repository.close();
        client.close();
        await tester.runAsync(() => directory.delete(recursive: true));
      });
      Widget cover({bool enabled = true}) => UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: TickerMode(
            enabled: enabled,
            child: Center(
              child: BookCover(item: entry('book', modified: 1), width: 100),
            ),
          ),
        ),
      );
      await tester.pumpWidget(cover());
      await tester.runAsync(
        () => precacheImage(
          tester.widget<Image>(find.byType(Image)).image,
          tester.element(find.byType(Image)),
        ),
      );
      await tester.pumpAndSettle();
      final image = tester
          .widget<RawImage>(find.byType(RawImage))
          .image
          ?.clone();
      addTearDown(() => image?.dispose());
      expect(image, isNotNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pumpWidget(cover());
      expect(find.byType(Image), findsOneWidget);
      expect(
        tester.widget<RawImage>(find.byType(RawImage)).image?.isCloneOf(image!),
        isTrue,
      );
      expect(container.read(coverProvider(key)).requireValue, same(bytes));
      await tester.pumpWidget(cover(enabled: false));
      expect(
        tester.widget<RawImage>(find.byType(RawImage)).image?.isCloneOf(image!),
        isTrue,
      );
      expect(adapter.requests, hasLength(1));
      expect(repository.peek((kind: 'book', id: 'book', modified: 2)), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test(
    'account-owned cover cache survives missing consumers and clears on logout',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'inkora-cover-owner-',
      );
      final adapter = FixtureAdapter(
        (options) => options.path.endsWith('users/me')
            ? jsonResponse(userJson)
            : ResponseBody.fromBytes(
                fixtureRaster,
                200,
                headers: {
                  'content-type': ['image/png'],
                },
              ),
      );
      final container = ProviderContainer(
        overrides: [
          sessionStoreProvider.overrideWithValue(
            MemorySessionStore()..saved = savedSession,
          ),
          komgaClientFactoryProvider.overrideWithValue(
            (endpoint, credentials) =>
                fixtureClient(endpoint, credentials, adapter),
          ),
          coverCacheDirectoryProvider.overrideWithValue(
            Future.value(directory),
          ),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await directory.delete(recursive: true);
      });
      container.read(sessionProvider);
      await container.pump();
      final listener = container.listen(coverRepositoryProvider, (_, _) {});
      final repository = (await container.read(
        coverRepositoryProvider.future,
      ))!;
      const key = (kind: 'book', id: 'book', modified: 1);
      await repository.load(key, CancellationController());
      await repository.flush();
      listener.close();
      await container.pump();
      expect(
        container.read(coverRepositoryProvider).requireValue,
        same(repository),
      );
      expect(repository.peek(key), isNotNull);
      await container.read(sessionProvider.notifier).logout();
      await container.pump();
      expect(repository.peek(key), isNull);
      expect(await container.read(coverRepositoryProvider.future), isNull);
    },
  );
}
