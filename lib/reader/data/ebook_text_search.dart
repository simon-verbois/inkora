import 'dart:isolate';

/// Keep extraction/matching bounded to one page and move dense pages off the UI
/// isolate. Native PDFium owns extraction; only a short snippet reaches the UI.
Future<String?> ebookSearchSnippet(String text, String query) async {
  if (query.isEmpty) return null;
  if (text.length > 128 * 1024) {
    return Isolate.run(() => _snippet(text, query));
  }
  return _snippet(text, query);
}

String? _snippet(String text, String query) {
  final match = text.toLowerCase().indexOf(query.toLowerCase());
  if (match < 0) return null;
  return text.substring(
    (match - 30).clamp(0, text.length),
    (match + query.length + 60).clamp(0, text.length),
  );
}
