import 'dart:convert';

import '../../reader/domain/ebook_locator.dart';

enum ProgressOperation { advance, rewind, markUnread, complete }

/// Server timestamp is an observed version, never compared with the device clock.
final class ProgressSnapshot {
  const ProgressSnapshot({
    required this.revision,
    this.pageIndex,
    this.completed = false,
    this.version,
    this.documentLocator,
  });
  final String revision;
  final int? pageIndex;
  final bool completed;
  final String? version;
  final String? documentLocator;
  double get preciseProgress => documentLocator == null
      ? 0
      : EbookLocator.decode(documentLocator!).progression;
  Map<String, Object?> toJson() => {
    'revision': revision,
    'page': pageIndex,
    'completed': completed,
    'version': version,
    if (documentLocator != null) 'documentLocator': documentLocator,
  };
  String encode() => jsonEncode(toJson());
  factory ProgressSnapshot.decode(String value) {
    final json = jsonDecode(value) as Map<String, dynamic>;
    return ProgressSnapshot(
      revision: json['revision'] as String,
      pageIndex: json['page'] as int?,
      completed: json['completed'] as bool,
      version: json['version'] as String?,
      documentLocator: json['documentLocator'] as String?,
    );
  }
  bool sameState(ProgressSnapshot other) =>
      revision == other.revision &&
      pageIndex == other.pageIndex &&
      completed == other.completed &&
      (documentLocator == null && other.documentLocator == null ||
          documentLocator != null &&
              other.documentLocator != null &&
              EbookLocator.decode(documentLocator!).href ==
                  EbookLocator.decode(other.documentLocator!).href &&
              (preciseProgress - other.preciseProgress).abs() < 0.000001);
  bool sameVersion(ProgressSnapshot other) =>
      sameState(other) && version == other.version;
}

final class ProgressIntent {
  const ProgressIntent({
    required this.accountId,
    required this.bookId,
    required this.sequence,
    required this.revision,
    required this.pageIndex,
    required this.fraction,
    required this.operation,
    required this.state,
    required this.attempt,
    required this.retryAt,
    required this.pageCount,
    this.baseline,
    this.remote,
    this.documentLocator,
  });
  final String accountId, bookId, revision, state;
  final int sequence, pageIndex, pageCount, attempt, retryAt;
  final double fraction;
  final String? documentLocator;
  final ProgressOperation operation;
  final ProgressSnapshot? baseline, remote;
}
