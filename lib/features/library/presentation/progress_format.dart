import 'package:flutter/foundation.dart';

import '../../../app/l10n/app_strings.dart';
import '../domain/catalogue.dart';
import '../domain/catalogue_filters.dart';
import '../domain/reading_history.dart';
import '../domain/resume_entry.dart';

/// Reading state shown on covers, rows and detail headers.
enum ReadingState { unread, reading, read }

/// One formatted reading position: a localized [label], an optional [ratio]
/// (null when the position is unknown) and its [state].
@immutable
final class ProgressInfo {
  const ProgressInfo({required this.label, required this.state, this.ratio});
  final String label;
  final ReadingState state;
  final double? ratio;

  @override
  bool operator ==(Object other) =>
      other is ProgressInfo &&
      other.label == label &&
      other.state == state &&
      other.ratio == ratio;
  @override
  int get hashCode => Object.hash(label, state, ratio);
  @override
  String toString() => 'ProgressInfo($label, $state, $ratio)';
}

/// Source keys of the shared reading-status chips of the filter bar.
String readingStatusLabel(ReadingStatus status) => switch (status) {
  ReadingStatus.any => 'All',
  ReadingStatus.unread => 'Unread',
  ReadingStatus.inProgress => 'In progress',
  ReadingStatus.completed => 'Completed',
};

/// Source keys of the per-item state labels.
String readingStateLabel(ReadingState state) => switch (state) {
  ReadingState.unread => 'Unread',
  ReadingState.reading => 'In progress',
  ReadingState.read => 'Read',
};

/// "92 %": the single percent format. An unfinished book never shows 100 %.
String percentLabel(AppStrings strings, double ratio, {bool finished = false}) {
  var percent = (ratio.clamp(0, 1) * 100).round();
  if (!finished && percent == 100 && ratio < 1) percent = 99;
  return strings.text('{0} %', [percent]);
}

/// "Page 53/180": a page position inside the reader or a page list.
String pagePositionLabel(AppStrings strings, int index, int count) =>
    strings.text('Page {0}/{1}', [index + 1, count]);

/// "Vol. 01" from a Komga sort number; null when the number is unknown.
String? volumeLabel(AppStrings strings, double number) {
  if (number <= 0 || !number.isFinite) return null;
  final whole = number == number.roundToDouble();
  final value = whole
      ? number.round().toString().padLeft(2, '0')
      : strings.text('{0}', [number]);
  return strings.text('Vol. {0}', [value]);
}

/// Prefer the server title; numbering is only a fallback for missing titles.
String? volumeDisplayName(AppStrings strings, String title, double number) =>
    title.trim().isNotEmpty ? title : volumeLabel(strings, number);

String _join(AppStrings strings, String? volume, String detail) =>
    volume == null ? detail : strings.text('{0} · {1}', [volume, detail]);

/// Saved position of a Continue reading entry: "Volume title · 92 %" for comics,
/// "8 %" for ebooks, "Volume title · Up next" for on-deck volumes and
/// "In progress" when the server position is unknown.
ProgressInfo formatResumeProgress(AppStrings strings, ResumeEntry entry) {
  final volume = entry.isEbook
      ? null
      : volumeDisplayName(strings, entry.item.title, entry.item.number);
  if (entry.onDeck) {
    return ProgressInfo(
      label: _join(strings, volume, strings.text('Up next')),
      state: ReadingState.unread,
    );
  }
  final known = entry.isEbook
      ? entry.pageKnown || entry.totalProgression != null
      : entry.pageKnown;
  if (!known) {
    return ProgressInfo(
      label: _join(strings, volume, strings.text('In progress')),
      state: ReadingState.reading,
    );
  }
  final ratio = entry.progress.toDouble();
  return ProgressInfo(
    label: _join(strings, volume, percentLabel(strings, ratio)),
    state: ReadingState.reading,
    ratio: ratio,
  );
}

/// Catalogue reading status of a series or volume without a saved position.
ProgressInfo formatItemProgress(AppStrings strings, CatalogueItem item) {
  final state = switch (item.readingStatus) {
    ReadingStatus.completed => ReadingState.read,
    ReadingStatus.inProgress => ReadingState.reading,
    ReadingStatus.unread || ReadingStatus.any => ReadingState.unread,
  };
  return ProgressInfo(
    label: strings.text(readingStateLabel(state)),
    state: state,
    ratio: switch (state) {
      ReadingState.read => 1,
      ReadingState.unread => 0,
      ReadingState.reading => null,
    },
  );
}

/// Reading-history position: "Volume title · 92 %", "Volume title · Read", "8 %"
/// (ebooks) or "Volume title · In progress" when the position is unknown.
ProgressInfo formatHistoryProgress(AppStrings strings, HistoryEntry entry) {
  final volume = entry.isEbook
      ? null
      : volumeDisplayName(strings, entry.title, entry.number);
  return switch (entry.status) {
    ReadingStatus.completed => ProgressInfo(
      label: _join(strings, volume, strings.text('Read')),
      state: ReadingState.read,
      ratio: 1,
    ),
    ReadingStatus.unread || ReadingStatus.any => ProgressInfo(
      label: _join(strings, volume, strings.text('Unread')),
      state: ReadingState.unread,
      ratio: 0,
    ),
    ReadingStatus.inProgress => ProgressInfo(
      label: _join(
        strings,
        volume,
        entry.ratio == null
            ? strings.text('In progress')
            : percentLabel(strings, entry.ratio!),
      ),
      state: ReadingState.reading,
      ratio: entry.ratio,
    ),
  };
}

/// "p. 169" or, for a two-page spread, "p. 12–13" (zero-based indexes).
String pageShortLabel(AppStrings strings, int first, [int? last]) =>
    last == null || last == first
    ? strings.text('p. {0}', [first + 1])
    : strings.text('p. {0}–{1}', [first + 1, last + 1]);

/// Reader top-bar position: "Volume title · p. 169/184", "p. 169/184" without a
/// known volume number, or "[lead] · p. 169/184" when [lead] is given.
String readerPositionLabel(
  AppStrings strings, {
  required int index,
  required int count,
  double volume = 0,
  String? lead,
}) {
  final page = strings.text('p. {0}/{1}', [index + 1, count]);
  final prefix = volumeDisplayName(strings, lead ?? '', volume);
  return prefix == null ? page : strings.text('{0} · {1}', [prefix, page]);
}

/// Progress after the last visible page: "92 % · 15 pages left", or only the
/// percent on the final page.
String readerRemainingLabel(
  AppStrings strings, {
  required int last,
  required int count,
}) {
  final finished = last >= count - 1;
  final percent = percentLabel(
    strings,
    count == 0 ? 0 : (last + 1) / count,
    finished: finished,
  );
  if (finished) return percent;
  return strings.text('{0} · {1}', [
    percent,
    strings.quantity(count - last - 1, 'pageLeft'),
  ]);
}
