import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/core/network/komga/komga_client.dart';
import 'package:inkora/core/network/server_endpoint.dart';
import 'package:inkora/features/connection/domain/session.dart';

void main() {
  final path = Platform.environment['INKORA_KOMGA_CREDENTIALS'];
  test(
    'live authenticated book and series posters honor Komga thumbnail contracts',
    () async {
      final configuration =
          jsonDecode(File(path!).readAsStringSync()) as Map<String, dynamic>;
      final client = KomgaClient(
        ServerEndpoint(configuration['url'] as String),
        Credentials.basic(
          configuration['username'] as String,
          configuration['password'] as String,
        ),
      );
      addTearDown(client.close);
      await client.currentUser();
      final books = await client.books(size: 1);
      final book = books.items.single;
      final bookResult = await client.thumbnailResult(
        'book',
        book.id,
        cancelToken: CancelToken(),
      );
      final bookPoster = bookResult.bytes!;
      expect(bookResult.etag, isNotNull);
      final unchanged = await client.thumbnailResult(
        'book',
        book.id,
        cancelToken: CancelToken(),
        etag: bookResult.etag,
      );
      expect(unchanged.bytes, isNull);
      expect(unchanged.etag, bookResult.etag);
      expect(bookPoster.length, greaterThan(0));
      expect(bookPoster.length, lessThanOrEqualTo(2 * 1024 * 1024));
      final series = await client.cataloguePage<String>(
        'series',
        (value) => (value as Map<String, dynamic>)['id'] as String,
        size: 1,
      );
      final seriesPoster = await client.thumbnail(
        'series',
        series.items.single,
        cancelToken: CancelToken(),
      );
      expect(seriesPoster.length, greaterThan(0));
      expect(seriesPoster.length, lessThanOrEqualTo(2 * 1024 * 1024));
    },
    skip: path == null
        ? 'Set INKORA_KOMGA_CREDENTIALS for explicit live cover verification.'
        : false,
  );
}
