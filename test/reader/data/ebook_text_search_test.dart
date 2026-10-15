import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/reader/data/ebook_text_search.dart';

void main() {
  test(
    'short and dense PDF pages keep original text in bounded snippets',
    () async {
      for (final count in [0, 300000]) {
        final text = '${'a' * count}The Lantern lights the path.${'z' * 150}';
        final snippet = await ebookSearchSnippet(text, 'lantern');
        expect(snippet, contains('The Lantern lights the path.'));
        expect(snippet!.length, lessThanOrEqualTo(97));
        expect(await ebookSearchSnippet(text, 'missing'), isNull);
      }
      expect(await ebookSearchSnippet('book', ''), isNull);
    },
  );
}
