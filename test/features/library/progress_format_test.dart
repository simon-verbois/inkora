import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/l10n/app_strings.dart';
import 'package:inkora/features/library/domain/catalogue.dart';
import 'package:inkora/features/library/domain/catalogue_filters.dart';
import 'package:inkora/features/library/domain/resume_entry.dart';
import 'package:inkora/features/library/presentation/progress_format.dart';

import '../../support/catalogue_fakes.dart';

void main() {
  final en = AppStrings('en');
  final fr = AppStrings('fr');

  ResumeEntry resume({
    double number = 1,
    int page = 4,
    int count = 10,
    bool raster = true,
    bool known = true,
    bool onDeck = false,
    double? total,
  }) => ResumeEntry(
    item: entry('book', number: number),
    seriesTitle: 'Series',
    pageIndex: page,
    pageCount: count,
    fraction: 0,
    raster: raster,
    pageKnown: known,
    onDeck: onDeck,
    totalProgression: total,
  );

  test('raster position shows the server title and one percent format', () {
    expect(
      formatResumeProgress(en, resume(number: 1, page: 91, count: 100)),
      const ProgressInfo(
        label: 'book · 91 %',
        state: ReadingState.reading,
        ratio: .91,
      ),
    );
    expect(formatResumeProgress(fr, resume()).label, 'book · 40 %');
    // Titles remain available even without a volume number.
    expect(formatResumeProgress(en, resume(number: 0)).label, 'book · 40 %');
    expect(volumeLabel(en, 12.5), 'Vol. 12.5');
    expect(volumeLabel(en, 0), isNull);
  });

  test('missing titles use numbering only as a fallback', () {
    expect(volumeDisplayName(en, 'A supplied title', 12), 'A supplied title');
    expect(volumeDisplayName(fr, '   ', 12), 'T12');
    expect(volumeDisplayName(en, '', 0), isNull);
    expect(
      readerPositionLabel(
        fr,
        index: 4,
        count: 20,
        volume: 1,
        lead: 'Le passage',
      ),
      'Le passage · p. 5/20',
    );
  });

  test('ebook position is a percent without a volume prefix', () {
    final info = formatResumeProgress(
      en,
      resume(raster: false, known: false, total: .083),
    );
    expect(info.label, '8 %');
    expect(info.ratio, .083);
    expect(info.state, ReadingState.reading);
  });

  test('on-deck volume is up next and unread, without a ratio', () {
    final info = formatResumeProgress(en, resume(number: 2, onDeck: true));
    expect(info.label, 'book · Up next');
    expect(info.state, ReadingState.unread);
    expect(info.ratio, isNull);
  });

  test('unknown server position stays in progress without a bar', () {
    final info = formatResumeProgress(en, resume(known: false));
    expect(info.label, 'book · In progress');
    expect(info.ratio, isNull);
    expect(
      formatResumeProgress(en, resume(raster: false, known: false)).label,
      'In progress',
    );
  });

  test('an unfinished book never rounds up to 100 %', () {
    expect(percentLabel(en, .996), '99 %');
    expect(percentLabel(en, 1), '100 %');
    expect(percentLabel(en, .996, finished: true), '100 %');
  });

  test('catalogue reading status maps to shared state labels', () {
    CatalogueItem item(ReadingStatus status) => CatalogueItem(
      kind: CatalogueKind.series,
      id: 's',
      title: 'S',
      readingStatus: status,
    );
    expect(
      formatItemProgress(en, item(ReadingStatus.completed)),
      const ProgressInfo(label: 'Read', state: ReadingState.read, ratio: 1),
    );
    expect(formatItemProgress(fr, item(ReadingStatus.completed)).label, 'Lu');
    expect(formatItemProgress(en, item(ReadingStatus.unread)).label, 'Unread');
    expect(
      formatItemProgress(en, item(ReadingStatus.inProgress)).ratio,
      isNull,
    );
    expect(readingStatusLabel(ReadingStatus.completed), 'Completed');
    expect(readingStatusLabel(ReadingStatus.any), 'All');
    expect(pagePositionLabel(en, 52, 180), 'Page 53/180');
  });
}
