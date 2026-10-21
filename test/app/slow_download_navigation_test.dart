import '../support/home_navigation.dart';

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/router.dart';
import 'package:inkora/offline/application/background_transfer.dart';
import 'package:inkora/offline/application/offline_coordinator.dart';
import 'package:inkora/offline/data/download_scheduler.dart';
import 'package:inkora/offline/data/download_store.dart';
import 'package:inkora/offline/data/progress_store.dart';
import 'package:inkora/offline/data/progress_sync.dart';
import 'package:inkora/reader/application/reader_network_policy.dart';
import 'package:inkora/reader/data/page_network_gate.dart';
import 'package:inkora/reader/data/reader_asset_store.dart';

import '../offline/progress_sync_test.dart' show FakeRemote;
import '../support/connection_fakes.dart';
import '../support/reader_fakes.dart';
import '../support/ui_harness.dart';

void main() {
  testWidgets(
    'slow transfers keep advancing across sidebar changes and return',
    (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final root = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('inkora-slow-download-'),
      ))!;
      final started = Completer<void>();
      final response = Completer<void>();
      var transfers = 0;
      late OfflineCoordinator service;
      final manifest = readerManifest(
        account: savedSession.accountId,
        count: 1,
      );
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        BackgroundTransfer.channel,
        (call) async =>
            call.method == 'results' || call.method == 'accounts' ? [] : null,
      );
      messenger.setMockMethodCallHandler(
        ReaderNetworkPolicy.channel,
        (call) async => call.method == 'events'
            ? false
            : {'metered': false, 'dataSaver': false},
      );
      final harness = await UiHarness.create(
        tester,
        offlineFactory: (database) {
          final store = DownloadStore(
            database,
            savedSession.accountId,
            Directory('${root.path}/stage'),
          );
          final assets = ReaderAssetStore(
            database,
            Directory('${root.path}/cache'),
            Directory('${root.path}/downloads'),
          );
          final gate = PageNetworkGate();
          final scheduler = DownloadScheduler(
            store,
            assets,
            gate,
            loadManifest: (_, _) async => manifest,
            isCurrent: () => true,
            transfer: (m, p, f, t, b) async {
              transfers++;
              await f.writeAsBytes(
                fixtureRaster.take(fixtureRaster.length ~/ 2).toList(),
              );
              await Future<void>.delayed(const Duration(milliseconds: 210));
              service.downloads.progress.received(
                store.id(manifest),
                0,
                50,
                100,
              );
              started.complete();
              await response.future;
              await f.writeAsBytes(fixtureRaster);
              return (mediaType: 'image/png', byteLength: fixtureRaster.length);
            },
          );
          return service = OfflineCoordinator(
            store,
            assets,
            savedSession,
            scheduler,
            ProgressSync(
              ProgressStore(database, savedSession.accountId),
              FakeRemote(),
              gate,
              isCurrent: () => true,
            ),
            BackgroundTransfer(),
            () => true,
          );
        },
      );
      addTearDown(() async {
        if (!response.isCompleted) response.complete();
        service.close();
        await tester.runAsync(() async {
          await service.downloads.idle;
          await service.sync.idle;
          await service.assets.idle;
        });
        await harness.close(tester);
        messenger.setMockMethodCallHandler(BackgroundTransfer.channel, null);
        messenger.setMockMethodCallHandler(ReaderNetworkPolicy.channel, null);
        await tester.runAsync(() => root.delete(recursive: true));
      });
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.runAsync(
        () => service.start().timeout(const Duration(seconds: 5)),
      );
      await harness.mount(tester, settle: false);
      for (var turn = 0; turn < 6; turn++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 20));
      }
      Object? transferError;
      await tester.runAsync(() async {
        unawaited(
          service.enqueue(manifest.bookId).catchError((Object error) {
            transferError = error;
          }),
        );
      });
      for (var turn = 0; turn < 100 && !started.isCompleted; turn++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(transferError, isNull);
      expect(started.isCompleted, isTrue);
      final router = harness.container.read(routerProvider);
      for (final branch in [
        'downloads',
        'libraries',
        'settings',
        'libraries',
        'downloads',
      ]) {
        await openHomeDestination(tester, branch);
        for (var turn = 0; turn < 4; turn++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump(const Duration(milliseconds: 20));
        }
        await tester.pumpAndSettle();
        expect(
          router.routeInformationProvider.value.uri.path,
          branch == 'libraries' ? '/' : '/$branch',
        );
        expect(tester.takeException(), isNull, reason: branch);
      }
      expect(find.text('Downloading · 49 %'), findsOneWidget);
      expect(
        transfers,
        1,
        reason: 'Tab changes do not restart an active transfer',
      );
      var completed = false;
      await tester.runAsync(() async {
        response.complete();
        unawaited(service.downloads.idle.then((_) => completed = true));
      });
      for (var turn = 0; turn < 100 && !completed; turn++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(completed, isTrue);
      await tester.pumpAndSettle();
      expect(
        (await tester.runAsync(() => service.store.jobs()))!.single.state,
        DownloadState.complete,
      );
      expect(
        await tester.runAsync(() => service.assets.isDownloaded(manifest)),
        isTrue,
      );
      expect(transfers, 1);
      service.close();
      await harness.close(tester);
    },
  );
}
