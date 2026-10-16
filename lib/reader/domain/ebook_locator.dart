import 'dart:convert';

/// Readium resource locators are independent of font size and viewport pages.
final class EbookLocator {
  EbookLocator(Map<String, dynamic> json) : value = Map.unmodifiable(json) {
    final href = value['href'];
    final type = value['type'];
    final locations = value['locations'];
    if (href is! String ||
        href.isEmpty ||
        type is! String ||
        locations is! Map ||
        jsonEncode(value).length > 16384) {
      throw const FormatException('Invalid ebook locator');
    }
    for (final key in ['progression', 'totalProgression']) {
      final n = locations[key];
      if (n != null && (n is! num || !n.isFinite || n < 0 || n > 1)) {
        throw const FormatException('Invalid ebook progression');
      }
    }
  }
  final Map<String, dynamic> value;
  String get href => value['href'] as String;
  Map<String, dynamic> get locations =>
      Map<String, dynamic>.from(value['locations'] as Map);
  double get progression => (locations['progression'] as num? ?? 0).toDouble();
  double get total => (locations['totalProgression'] as num? ?? 0).toDouble();
  String encode() => jsonEncode(value);
  factory EbookLocator.decode(String text) =>
      EbookLocator(jsonDecode(text) as Map<String, dynamic>);

  /// A short display excerpt; structural anchors remain in locations.
  String get excerpt => ((value['text'] as Map?)?['highlight'] as String? ?? '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  factory EbookLocator.bookmark(
    Map<String, dynamic> value, {
    String? selectedText,
  }) {
    final text = Map<String, dynamic>.from(value['text'] as Map? ?? const {});
    String bounded(String value, int max) =>
        value.length <= max ? value : value.substring(0, max);
    final excerpt = selectedText ?? text['highlight'] as String?;
    if (excerpt != null) text['highlight'] = bounded(excerpt, 512);
    for (final key in ['before', 'after']) {
      final context = text[key];
      if (context is String) {
        text[key] = key == 'before' && context.length > 128
            ? context.substring(context.length - 128)
            : bounded(context, 128);
      }
    }
    return EbookLocator({...value, if (text.isNotEmpty) 'text': text});
  }

  /// Native EPUB positions can renumber after reflow. Prefer stable structural/text
  /// anchors when present, retaining progression for older page-only bookmarks.
  String get bookmarkKey {
    final location = locations;
    final text = value['text'] as Map?;
    final anchored =
        (text != null &&
            ['before', 'after'].any(
              (key) => text[key] is String && (text[key] as String).isNotEmpty,
            )) ||
        ['cssSelector', 'partialCfi', 'domRange', 'fragments'].any(
          (key) => switch (location[key]) {
            final String value => value.isNotEmpty,
            final List<Object?> value => value.isNotEmpty,
            final Map<Object?, Object?> value => value.isNotEmpty,
            _ => false,
          },
        );
    return jsonEncode(
      _canonical({
        'href': href,
        'type': value['type'],
        'locations': {
          for (final entry in location.entries)
            if (!anchored ||
                ![
                  'position',
                  'progression',
                  'totalProgression',
                ].contains(entry.key))
              entry.key: entry.value,
        },
        if (excerpt.isNotEmpty) 'text': value['text'],
      }),
    );
  }

  List<double>? get pdfRectangle {
    final raw = locations['inkoraPdfRect'];
    if (raw is! List ||
        raw.length != 4 ||
        raw.any((v) => v is! num || !v.isFinite || v.abs() > 1000000)) {
      return null;
    }
    final rect = raw.map((v) => (v as num).toDouble()).toList();
    return rect[0] < rect[2] && rect[1] > rect[3] ? rect : null;
  }

  /// Komga and native Readium can use different position counts. Resolve by
  /// resource + progression against the server's own position list.
  int positionIn(List<Map<String, dynamic>> positions) {
    final resource = Uri.decodeComponent(href.split('#').first);
    var found = -1;
    for (var i = 0; i < positions.length; i++) {
      final p = positions[i];
      if (Uri.decodeComponent((p['href'] as String).split('#').first) ==
          resource) {
        if (found < 0) found = i;
        if ((((p['locations'] as Map)['progression'] as num?) ?? 0) <=
            progression + 0.000001) {
          found = i;
        }
      }
    }
    if (found < 0) throw const FormatException('Unknown ebook resource');
    return found;
  }

  EbookLocator forKomga(List<Map<String, dynamic>> positions) {
    final position = positions[positionIn(positions)];
    return EbookLocator({
      ...value,
      'href': position['href'],
      'type': position['type'],
      'locations': {
        ...locations,
        ...(position['locations'] as Map).cast<String, dynamic>(),
        'progression': progression,
      },
    });
  }
}

/// Built once per book, then searched in logarithmic time on native scroll
/// position events. Never scan the publication on a per-pixel callback.
final class EbookPositionMap {
  EbookPositionMap(List<Map<String, dynamic>> source) : positions = source {
    for (var i = 0; i < source.length; i++) {
      final locator = EbookLocator(source[i]);
      final href = Uri.decodeComponent(locator.href.split('#').first);
      (_resources[href] ??= []).add((i, locator.progression));
    }
    for (final values in _resources.values) {
      values.sort((a, b) => a.$2.compareTo(b.$2));
    }
  }
  final List<Map<String, dynamic>> positions;
  final _resources = <String, List<(int, double)>>{};
  (int, EbookLocator) map(EbookLocator locator) {
    final resource =
        _resources[Uri.decodeComponent(locator.href.split('#').first)];
    if (resource == null || resource.isEmpty) {
      throw const FormatException('Unknown ebook resource');
    }
    // Canonical positions are segment starts, not the chapter's end bound.
    // Preserve the exact native location beyond the final segment start.
    final progression = locator.progression;
    var lo = 0, hi = resource.length;
    while (lo < hi) {
      final mid = (lo + hi) ~/ 2;
      if (resource[mid].$2 <= progression + .000001) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    final index = resource[(lo - 1).clamp(0, resource.length - 1)].$1;
    final canonical = positions[index];
    return (
      index,
      EbookLocator({
        ...locator.value,
        'href': canonical['href'],
        'type': canonical['type'],
        'locations': {
          ...locator.locations,
          ...(canonical['locations'] as Map).cast<String, dynamic>(),
          'progression': progression,
        },
      }),
    );
  }
}

Object? _canonical(Object? value) {
  if (value is Map) {
    final keys = value.keys.cast<String>().toList()..sort();
    return {for (final key in keys) key: _canonical(value[key])};
  }
  if (value is List) return value.map(_canonical).toList();
  return value;
}
