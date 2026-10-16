import 'package:drift/drift.dart' show Variable;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/core/storage/app_database.dart';
import 'package:inkora/reader/data/ebook_bookmarks.dart';
import 'package:inkora/reader/domain/ebook_locator.dart';

void main() {
  test('selection anchors survive reflow; atomic mutations retain concurrent additions and skip duplicate writes', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final bookmarks = EbookBookmarks(database, 'account', 'book');
    EbookLocator anchor(
      String selector, {
      int position = 1,
      double progression = .2,
    }) => EbookLocator.bookmark({
      'href': 'chapter.xhtml',
      'type': 'application/xhtml+xml',
      'locations': {
        'cssSelector': selector,
        'position': position,
        'progression': progression,
      },
      'text': {'highlight': 'A remembered line'},
    });
    await Future.wait([
      bookmarks.add(anchor('#first')),
      EbookBookmarks(database, 'account', 'book').add(anchor('#second')),
    ]);
    expect(await bookmarks.read(), hasLength(2));
    final before = await database
        .customSelect(
          'SELECT payload FROM app_preferences WHERE key=?',
          variables: [Variable(bookmarks.key)],
        )
        .getSingle();
    final changesBefore =
        (await database.customSelect('SELECT total_changes() AS n').getSingle())
            .read<int>('n');
    await bookmarks.add(anchor('#first', position: 9, progression: .8));
    final changesAfter =
        (await database.customSelect('SELECT total_changes() AS n').getSingle())
            .read<int>('n');
    expect(changesAfter, changesBefore);
    expect(await bookmarks.read(), hasLength(2));
    final after = await database
        .customSelect(
          'SELECT payload FROM app_preferences WHERE key=?',
          variables: [Variable(bookmarks.key)],
        )
        .getSingle();
    expect(after.read<String>('payload'), before.read<String>('payload'));
    await bookmarks.remove(anchor('#first', position: 12));
    expect((await bookmarks.read()).single.locations['cssSelector'], '#second');
    expect(
      await EbookBookmarks(database, 'another-account', 'book').read(),
      isEmpty,
    );
  });

  test(
    'text-context anchors deduplicate reflow and distinguish repeated words',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final bookmarks = EbookBookmarks(database, 'account', 'book');
      EbookLocator selected(int position, String before) =>
          EbookLocator.bookmark({
            'href': 'chapter.xhtml',
            'type': 'application/xhtml+xml',
            'locations': {'position': position, 'progression': position / 100},
            'text': {
              'before': before,
              'highlight': 'lantern',
              'after': ' lights the path',
            },
          });
      await bookmarks.add(selected(1, 'First paragraph: '));
      final before =
          (await database
                  .customSelect('SELECT total_changes() AS n')
                  .getSingle())
              .read<int>('n');
      await bookmarks.add(selected(8, 'First paragraph: '));
      expect(
        (await database.customSelect('SELECT total_changes() AS n').getSingle())
            .read<int>('n'),
        before,
      );
      await bookmarks.add(selected(8, 'Second paragraph: '));
      expect(await bookmarks.read(), hasLength(2));
      await bookmarks.remove(selected(20, 'First paragraph: '));
      expect(
        (await bookmarks.read()).single.value['text'],
        containsPair('before', 'Second paragraph: '),
      );
    },
  );

  test('selected text is bounded and PDF coordinates round-trip without affecting old page bookmarks', () {
    final selected = EbookLocator.bookmark({
      'href': 'document.pdf',
      'type': 'application/pdf',
      'locations': {
        'position': 2,
        'inkoraPdfRect': [40, 720, 260, 700],
      },
      'text': {
        'highlight': 'line ' * 1000,
        'before': '${'far ' * 100}nearest ',
        'after': 'next ${'distant ' * 100}',
      },
    });
    expect(selected.excerpt.length, lessThanOrEqualTo(512));
    expect((selected.value['text'] as Map)['before'], endsWith('nearest '));
    expect(((selected.value['text'] as Map)['before'] as String).length, 128);
    expect((selected.value['text'] as Map)['after'], startsWith('next '));
    expect(EbookLocator.decode(selected.encode()).pdfRectangle, [
      40,
      720,
      260,
      700,
    ]);
    final old = EbookLocator({
      'href': 'document.pdf',
      'type': 'application/pdf',
      'locations': {'position': 2},
    });
    expect(old.pdfRectangle, isNull);
    expect(old.excerpt, isEmpty);
    expect(selected.bookmarkKey, isNot(old.bookmarkKey));
    final emptyFragments = EbookLocator({
      ...old.value,
      'locations': {'position': 3, 'fragments': <String>[]},
    });
    expect(emptyFragments.bookmarkKey, isNot(old.bookmarkKey));
  });

  test(
    'bookmarks survive reopen and remain isolated by account and book',
    () async {
      final root = await Directory.systemTemp.createTemp('inkora-bookmarks-');
      final file = File('${root.path}/db');
      final database = AppDatabase(NativeDatabase(file));
      final locator = EbookLocator({
        'href': 'chapter.xhtml',
        'type': 'application/xhtml+xml',
        'locations': {'progression': .4},
        'text': {'highlight': 'An anchor'},
      });
      await EbookBookmarks(database, 'one', 'book').write([locator]);
      expect(await EbookBookmarks(database, 'two', 'book').read(), isEmpty);
      expect(await EbookBookmarks(database, 'one', 'another').read(), isEmpty);
      await database.close();
      final reopened = AppDatabase(NativeDatabase(file));
      addTearDown(() async {
        await reopened.close();
        await root.delete(recursive: true);
      });
      expect(
        (await EbookBookmarks(reopened, 'one', 'book').read()).single.encode(),
        locator.encode(),
      );
      await EbookBookmarks(reopened, 'one', 'book').write([]);
      expect(await EbookBookmarks(reopened, 'one', 'book').read(), isEmpty);
    },
  );
}
