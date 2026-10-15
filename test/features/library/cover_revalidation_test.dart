import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/features/library/data/cover_repository.dart';
import 'package:inkora/reader/data/page_network_gate.dart';
import 'package:inkora/reader/domain/page_source.dart';

import '../../support/connection_fakes.dart';
import '../../support/reader_fakes.dart';

void main() {
  test(
    'large unchanged artwork keeps decoded identity and coalesces validation',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'inkora-large-cover-',
      );
      final large = Uint8List(384 * 1024)
        ..setRange(0, fixtureRaster.length, fixtureRaster);
      var changed = false;
      final adapter = FixtureAdapter((_) {
        final bytes = Uint8List.fromList(large);
        if (changed) bytes[bytes.length - 1] = 1;
        return ResponseBody.fromBytes(
          bytes,
          200,
          headers: {
            'content-type': ['image/png'],
          },
        );
      });
      final client = fixtureClient(
        savedSession.endpoint,
        savedSession.credentials,
        adapter,
      );
      final repository = CoverRepository(
        client,
        PageNetworkGate(),
        directory,
        'large-cover-account',
      );
      addTearDown(() async {
        repository.close();
        client.close();
        await repository.flush();
        await directory.delete(recursive: true);
      });
      const key = (kind: 'series', id: 'large-cover', modified: 1);
      final original = await repository.load(key, CancellationController());
      final version = repository.version(key);
      final updates = <CoverKey>[];
      final subscription = repository.changes.listen(updates.add);
      addTearDown(subscription.cancel);
      final validation = repository.revalidate(key);
      expect(repository.revalidate(key), same(validation));
      expect(await validation, same(original));
      expect(adapter.requests.length, 2);
      expect(updates, isEmpty);
      expect(repository.version(key), version);
      changed = true;
      expect(await repository.revalidate(key), isNot(same(original)));
      expect(adapter.requests.length, 3);
      expect(updates, [key]);
      expect(repository.version(key), version + 1);
    },
  );
  test('unchanged metadata still checks ETag, changed cover replaces cache and failure preserves it', () async {
    final directory = await Directory.systemTemp.createTemp(
      'inkora-validation-',
    );
    var mode = 0;
    final changed = Uint8List.fromList([...fixtureRaster, 1]);
    final adapter = FixtureAdapter((options) {
      if (mode == 3) return jsonResponse({}, status: 503);
      if (mode == 1) {
        return ResponseBody.fromBytes(
          [],
          304,
          headers: {
            'etag': ['"first"'],
          },
        );
      }
      return ResponseBody.fromBytes(
        mode == 2 ? changed : fixtureRaster,
        200,
        headers: {
          'content-type': ['image/png'],
          'etag': [mode == 2 ? '"second"' : '"first"'],
        },
      );
    });
    final client = fixtureClient(
      savedSession.endpoint,
      savedSession.credentials,
      adapter,
    );
    final repository = CoverRepository(
      client,
      PageNetworkGate(),
      directory,
      'account',
    );
    addTearDown(() async {
      repository.close();
      client.close();
      await repository.flush();
      await directory.delete(recursive: true);
    });
    const key = (kind: 'book', id: 'book', modified: 42);
    final original = await repository.load(key, CancellationController());
    mode = 1;
    expect(await repository.revalidate(key), same(original));
    expect(adapter.requests.last.headers['If-None-Match'], '"first"');
    final updates = <CoverKey>[];
    final subscription = repository.changes.listen(updates.add);
    addTearDown(subscription.cancel);
    mode = 2;
    final fresh = await repository.revalidate(key);
    expect(fresh, changed);
    expect(fresh, isNot(same(original)));
    expect(updates, [key]);
    mode = 3;
    expect(await repository.revalidate(key), same(fresh));
    expect(repository.peek(key), same(fresh));
    expect(updates, [key]);
    await repository.flush();
    mode = 1;
    final reopened = CoverRepository(
      client,
      PageNetworkGate(),
      directory,
      'account',
    );
    addTearDown(reopened.close);
    final disk = await reopened.load(key, CancellationController());
    expect(disk, changed);
    expect(await reopened.revalidate(key), same(disk));
    expect(adapter.requests.last.headers['If-None-Match'], '"second"');
    await reopened.flush();
  });

  test(
    'in-flight validation coalesces and a closed account rejects changed bytes',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'inkora-validation-close-',
      );
      final pending = Completer<ResponseBody>();
      var first = true;
      final adapter = FixtureAdapter((_) {
        if (!first) return pending.future;
        first = false;
        return ResponseBody.fromBytes(
          fixtureRaster,
          200,
          headers: {
            'content-type': ['image/png'],
          },
        );
      });
      final client = fixtureClient(
        savedSession.endpoint,
        savedSession.credentials,
        adapter,
      );
      final repository = CoverRepository(
        client,
        PageNetworkGate(),
        directory,
        'account',
      );
      addTearDown(() async {
        repository.close();
        client.close();
        await repository.flush();
        await directory.delete(recursive: true);
      });
      const key = (kind: 'book', id: 'book', modified: 1);
      await repository.load(key, CancellationController());
      final validation = repository.revalidate(key);
      expect(repository.revalidate(key), same(validation));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      repository.close();
      pending.complete(
        ResponseBody.fromBytes(
          fixtureRaster,
          200,
          headers: {
            'content-type': ['image/png'],
          },
        ),
      );
      await validation;
      expect(repository.peek(key), isNull);
    },
  );
}
