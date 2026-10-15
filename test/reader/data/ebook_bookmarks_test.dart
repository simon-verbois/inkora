import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/core/storage/app_database.dart';
import 'package:inkora/reader/data/ebook_bookmarks.dart';
import 'package:inkora/reader/domain/ebook_locator.dart';

void main() {
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
