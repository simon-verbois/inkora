import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'ebook_presentation.dart';

/// Display pages in the complete book for one native layout configuration.
@immutable
class EbookPagination {
  const EbookPagination(this.pages, this.total);
  final List<int> pages;
  final int total;

  factory EbookPagination.decode(String raw) {
    final value = jsonDecode(raw);
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Invalid EPUB pagination');
    }
    final pages = value['pages'];
    final total = value['total'];
    if (total is! int ||
        total < 1 ||
        pages is! List ||
        pages.isEmpty ||
        pages.length > 2 ||
        pages.any((page) => page is! int || page < 1 || page > total)) {
      throw const FormatException('Invalid EPUB pagination');
    }
    return EbookPagination(List<int>.unmodifiable(pages), total);
  }

  @override
  bool operator ==(Object other) =>
      other is EbookPagination &&
      total == other.total &&
      listEquals(pages, other.pages);
  @override
  int get hashCode => Object.hash(total, Object.hashAll(pages));
}

/// Coalesces scalar native layout snapshots without writing progress.
/// Obsolete/hidden/disposed results cannot update the footer.
class EbookPageNumbersController extends ValueNotifier<EbookPagination?> {
  EbookPageNumbersController({Future<String?> Function()? snapshot})
    : _snapshot = snapshot ?? _nativeSnapshot,
      super(null) {
    if (snapshot == null && EbookPresentation.supported) {
      _nativeOwner = this;
      EbookPresentation.channel.setMethodCallHandler((call) async {
        if (call.method == 'paginationChanged' && _active) refresh();
      });
    }
  }

  static EbookPageNumbersController? _nativeOwner;

  final Future<String?> Function() _snapshot;
  var _pending = false;
  var _generation = 0;
  var _running = false;
  var _closed = false;
  var _active = false;

  static Future<String?> _nativeSnapshot() async {
    if (!EbookPresentation.supported) return null;
    return EbookPresentation.channel.invokeMethod<String>('pagination');
  }

  void refresh() {
    if (_closed) return;
    _active = true;
    _generation++;
    _pending = true;
    if (!_running) _drain();
  }

  void hide() {
    _active = false;
    _generation++;
    _pending = false;
    if (!_closed && value != null) value = null;
  }

  Future<void> _drain() async {
    _running = true;
    try {
      while (!_closed && _pending) {
        final generation = _generation;
        _pending = false;
        EbookPagination? numbers;
        try {
          final raw = await _snapshot();
          if (raw != null) {
            numbers = EbookPagination.decode(raw);
          }
        } on PlatformException {
          // Optional layout metadata must never interrupt reading.
        } on MissingPluginException {
          // Platforms without the Android adapter leave the optional folio hidden.
        } on FormatException {
          // A closing/reflowing resource can temporarily lack valid geometry.
        }
        if (!_closed && generation == _generation && value != numbers) {
          value = numbers;
        }
      }
    } finally {
      _running = false;
    }
  }

  @override
  void dispose() {
    _closed = true;
    _active = false;
    if (identical(_nativeOwner, this)) {
      _nativeOwner = null;
      EbookPresentation.channel.setMethodCallHandler(null);
    }
    _pending = false;
    super.dispose();
  }
}
