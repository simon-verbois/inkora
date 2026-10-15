import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/core/errors/failure_kind.dart';
import 'package:inkora/core/network/komga/api_failure.dart';
import 'package:inkora/features/library/data/komga_catalogue_remote.dart';
import 'package:inkora/features/library/domain/catalogue.dart';

import '../../support/connection_fakes.dart';

Object? fixture(String name) => jsonDecode(
  File('test/fixtures/komga/1.28.1/catalogue/$name.json').readAsStringSync(),
);

void main() {
  for (final kind in CatalogueKind.values) {
    test(
      'runtime ${kind.name} fixture maps identity and pagination under a subpath',
      () async {
        final name = kind == CatalogueKind.library
            ? 'local-libraries'
            : 'local-${kind.name}-0';
        final adapter = FixtureAdapter((_) => jsonResponse(fixture(name)));
        final client = fixtureClient(
          savedSession.endpoint,
          savedSession.credentials,
          adapter,
        );
        addTearDown(client.close);
        final remote = KomgaCatalogueRemote(client);
        final result = await remote.fetch(kind, 0);
        expect(result.items, isNotEmpty);
        expect(result.items.every((item) => item.kind == kind), isTrue);
        expect(adapter.requests.single.uri.path, startsWith('/komga/api/v1/'));
        if (kind == CatalogueKind.collection ||
            kind == CatalogueKind.readlist) {
          expect(result.items.single.ordered, isTrue);
          expect(result.items.single.members, isNotEmpty);
        }
        if (kind != CatalogueKind.library) {
          expect(adapter.requests.single.queryParameters['sort'], 'id,asc');
        }
      },
    );
  }
  test('readlist member fixture pages agree with DTO order; removed files map as unavailable', () {
    final lists = fixture('local-readlist-0') as Map<String, dynamic>;
    final list = parseCatalogueItem(
      (lists['content'] as List).single,
      CatalogueKind.readlist,
    );
    final ordered = <String>[];
    for (final page in [0, 1]) {
      final json =
          fixture('local-readlist-members-$page') as Map<String, dynamic>;
      ordered.addAll(
        (json['content'] as List).map(
          (value) => parseCatalogueItem(value, CatalogueKind.book).id,
        ),
      );
    }
    expect(ordered, list.members);
    final changed = parseCatalogueItem(
      fixture('local-readlist-changed'),
      CatalogueKind.readlist,
    );
    expect(changed.members, list.members.skip(1).toList());
    final deleted = parseCatalogueItem(
      fixture('local-deleted-book'),
      CatalogueKind.book,
    );
    expect(deleted.deleted, isTrue);
    expect(deleted.canOpen, isFalse);
  });
  test('invalid membership and timestamps reject malformed DTOs', () {
    final fixtureJson =
        fixture('local-readlist-changed') as Map<String, dynamic>;
    expect(
      () => parseCatalogueItem({
        ...fixtureJson,
        'bookIds': ['same', 'same'],
      }, CatalogueKind.readlist),
      throwsFormatException,
    );
    expect(
      () => parseCatalogueItem({
        ...fixtureJson,
        'lastModifiedDate': 'bad',
      }, CatalogueKind.readlist),
      throwsFormatException,
    );
  });
  test('cancelled refresh transport fails silently with stable cancellation category', () async {
    final client = fixtureClient(
      savedSession.endpoint,
      savedSession.credentials,
      FixtureAdapter((_) => jsonResponse(fixture('local-libraries'))),
    );
    addTearDown(client.close);
    final remote = KomgaCatalogueRemote(client)..cancel();
    await expectLater(
      remote.fetch(CatalogueKind.library, 0),
      throwsA(
        isA<ApiFailure>().having(
          (error) => error.kind,
          'kind',
          FailureKind.cancelled,
        ),
      ),
    );
  });
}
