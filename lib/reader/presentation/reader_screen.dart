import 'raster_navigation_sheet.dart';
import '../data/raster_bookmarks.dart';
import '../../offline/data/progress_store.dart';
import '../../offline/domain/progress.dart';
import '../../features/library/application/catalogue_providers.dart';
import '../../features/library/data/catalogue_store.dart';
import '../../features/library/domain/catalogue.dart';
import '../../features/library/presentation/book_cover.dart';
import '../../features/library/presentation/progress_format.dart';
import '../../offline/application/offline_coordinator.dart';
import '../../app/widgets/inkora_widgets.dart';
import 'reader_chrome.dart';
import 'reader_details.dart';
import 'ebook_reader_screen.dart';
import '../domain/gesture_zones.dart';
import '../../app/l10n/app_strings.dart';
import 'reader_gesture_guard.dart';
import '../../app/icons/inkora_icons.dart';

import 'dart:async';

import '../../offline/presentation/progress_sheet.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/reader_providers.dart';
import '../domain/reader_manifest.dart';
import '../data/reader_repository.dart';
import '../data/reader_store.dart';
import '../domain/reading_settings.dart';
import 'reader_settings_sheet.dart';
import 'reader_viewport.dart';
import 'reader_system_ui.dart';

class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({
    required this.bookId,
    this.gestureZones = const GestureZones(),
    super.key,
  });
  final GestureZones gestureZones;
  final String bookId;
  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen>
    with WidgetsBindingObserver {
  OpenReader? _suppressedReader, _locatorOwner;
  ReaderLocator? _currentLocator;
  int _positionRevision = 0;
  final _navigation = ValueNotifier<ReaderLocator?>(null);

  /// Visible page for the top-bar subtitle. Only the subtitle listens; the
  /// int comparison makes repeated same-page reports free.
  final _page = ValueNotifier<int>(0);
  bool _ending = false;
  bool _refreshing = false;
  bool _changingChapter = false;
  bool _controlsVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(ReaderSystemUi.setImmersive(!widget.gestureZones.showSystemBars));
  }

  /// Book-scoped: pairing depends on this volume's page order. Other book
  /// overrides are preserved; the settings stream re-pairs the viewport.
  Future<void> _toggleSpreadOffset(
    ReaderStore store,
    ReaderManifest manifest,
  ) async {
    try {
      await store.toggleSpreadOffset(manifest);
    } catch (_) {
      if (mounted) {
        notifyInk(context, 'Unable to save page pairing.');
      }
    }
  }

  OpenReader? _headingOwner;
  Future<ReaderHeading>? _heading;

  /// Memoized per opened book; created when the controls first appear.
  Future<ReaderHeading>? _headingFor(
    OpenReader reader,
    ReaderRepository? repository,
  ) {
    if (repository == null) return null;
    if (!identical(_headingOwner, reader)) {
      _headingOwner = reader;
      _heading = loadReaderHeading(repository, reader.manifest);
    }
    return _heading;
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    unawaited(
      ReaderSystemUi.setImmersive(
        !_controlsVisible && !widget.gestureZones.showSystemBars,
      ),
    );
  }

  @override
  void didUpdateWidget(ReaderScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.gestureZones.showSystemBars !=
        widget.gestureZones.showSystemBars) {
      unawaited(
        ReaderSystemUi.setImmersive(
          !_controlsVisible && !widget.gestureZones.showSystemBars,
        ),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(
        ReaderSystemUi.setImmersive(
          !_controlsVisible && !widget.gestureZones.showSystemBars,
        ),
      );
    }
  }

  @override
  void dispose() {
    _navigation.dispose();
    _page.dispose();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(ReaderSystemUi.setImmersive(false));
    super.dispose();
  }

  Future<void> _refresh() async {
    final bookId = widget.bookId;
    setState(() => _refreshing = true);
    try {
      final repository = await ref.read(readerRepositoryProvider.future);
      if (repository == null) return;
      final refreshed = await repository.open(bookId, refresh: true);
      repository.release(refreshed);
      if (mounted) ref.invalidate(openReaderProvider(bookId));
    } catch (error) {
      if (mounted) {
        notifyInk(
          context,
          error is ReaderFailure
              ? error.message
              : 'Unable to refresh this book.',
        );
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<bool> _nextChapter(OpenReader reader) async {
    setState(() => _changingChapter = true);
    try {
      final repository = await ref.read(readerRepositoryProvider.future);
      final next = await repository?.nextChapterId(reader.manifest);
      if (!mounted) return false;
      if (next == null) {
        notifyInk(context, 'No next chapter is available.');
        return false;
      }
      reader.prefetch?.suspend(true);
      if (GoRouterState.of(context).name != 'series-reader' ||
          reader.manifest.seriesId == null) {
        context.pushReplacementNamed('reader', pathParameters: {'id': next});
        return true;
      }
      context.pushReplacementNamed(
        'series-reader',
        pathParameters: {
          'kind': 'series',
          'id': reader.manifest.seriesId!,
          'bookId': next,
        },
      );
      return true;
    } catch (_) {
      if (mounted) {
        notifyInk(context, 'Unable to open the next chapter.');
      }
      return false;
    } finally {
      if (mounted) setState(() => _changingChapter = false);
    }
  }

  Future<void> _navigate(OpenReader reader, {bool bookmarks = false}) async {
    final repository = await ref.read(readerRepositoryProvider.future);
    if (!mounted || repository == null) return;
    final result = await showInkSheet<ReaderLocator>(
      context: context,
      child: RasterNavigationSheet(
        reader: reader,
        current: _currentLocator ?? reader.locator,
        bookmarks: RasterBookmarks(
          repository.store.database,
          reader.manifest.accountId,
          reader.manifest.bookId,
        ),
        showBookmarks: bookmarks,
      ),
    );
    if (mounted && result != null) _navigation.value = result;
  }

  Future<void> _end(OpenReader reader) async {
    if (_ending) return;
    _ending = true;
    try {
      final repository = await ref.read(readerRepositoryProvider.future);
      final catalogue = await ref.read(catalogueRepositoryProvider.future);
      if (repository == null || !mounted) return;
      final nextId = await repository.nextChapterId(reader.manifest);
      // Exact lookup remains account/publication scoped; never infer remote IDs.
      final nextItem = nextId == null
          ? null
          : await catalogue?.store.item(CatalogueKind.book, nextId).first;
      if (!mounted) return;
      final action = await showInkSheet<String>(
        context: context,
        child: _VolumeEndSheet(next: nextItem),
      );
      if (action == null || !mounted) return;
      final last = ReaderLocator(reader.manifest.pages.length - 1, 1);
      final previous = _suppressedReader;
      _suppressedReader = reader;
      try {
        await ProgressStore(
          repository.store.database,
          repository.store.accountId,
        ).save(reader.manifest, last, operation: ProgressOperation.complete);
      } catch (_) {
        _suppressedReader = previous;
        rethrow;
      }
      if (!mounted) return;
      if (action == 'next' && nextId != null) {
        if (!await _nextChapter(reader)) _suppressedReader = previous;
      } else {
        await openReaderDetails(context, reader.manifest);
      }
    } catch (_) {
      if (mounted) {
        notifyInk(context, 'Unable to finish this volume. Try again.');
      }
    } finally {
      _ending = false;
    }
  }

  Future<void> _settings(OpenReader reader) async {
    final repository = await ref.read(readerRepositoryProvider.future);
    if (!mounted || repository == null) return;
    await showInkSheet<void>(
      context: context,
      child: ReaderSettingsSheet(
        modal: true,
        store: repository.store,
        manifest: reader.manifest,
      ),
    );
  }

  Future<void> _details(OpenReader reader) async {
    reader.prefetch?.suspend(true);
    try {
      await openReaderDetails(context, reader.manifest);
    } finally {
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        reader.prefetch?.suspend(false);
      }
    }
  }

  Future<void> _progress(OpenReader reader) async {
    final previousSuppression = _suppressedReader;
    final changed = await showInkSheet<bool>(
      context: context,
      child: ProgressSheet(
        manifest: reader.manifest,
        currentLocator: _currentLocator ?? reader.locator,
        onChanging: () {
          _suppressedReader = reader;
          _positionRevision++;
        },
      ),
    );
    if (mounted &&
        (changed == true ||
            !identical(previousSuppression, _suppressedReader))) {
      ref.invalidate(openReaderProvider(widget.bookId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final zones = widget.gestureZones;
    final data = ref.watch(openReaderProvider(widget.bookId));
    final preferences = ref.watch(readingSettingsProvider(widget.bookId));
    final repository = ref.watch(readerRepositoryProvider).asData?.value;
    final opened = data.asData?.value;
    if (opened != null && opened.manifest.isDocument && repository != null) {
      return EbookReaderScreen(
        key: ObjectKey(opened),
        reader: opened,
        gestureZones: zones,
        repository: repository,
        settings:
            preferences.asData?.value ??
            const ReadingSettings(mode: ReadingMode.ebook),
      );
    }
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          ReaderGestureGuard(
            zones: zones,
            child: _body(data, preferences, repository),
          ),
          if (_controlsVisible || data.hasError || preferences.hasError)
            Align(
              alignment: Alignment.topCenter,
              child: opened == null
                  ? ReaderTopBar(
                      title: context.tr('Reader'),
                      onBack: () => context.pop(),
                      actions: const [],
                    )
                  : _RasterTopBar(
                      manifest: opened.manifest,
                      heading: _headingFor(opened, repository),
                      page: _page,
                      onBack: () => context.pop(),
                      onDetails: () => _details(opened),
                    ),
            ),
        ],
      ),
    );
  }

  Widget _body(
    AsyncValue<OpenReader> data,
    AsyncValue<ReadingSettings> preferences,
    ReaderRepository? repository,
  ) => data.when(
    loading: () => const ReaderLoadingView(),
    error: (error, _) => ReaderErrorView(
      message: error is ReaderFailure
          ? error.message
          : 'Unable to open this book.',
      actionLabel: 'Retry',
      onAction: () => ref.invalidate(openReaderProvider(widget.bookId)),
    ),
    data: (reader) {
      if (preferences.hasError) {
        return const ReaderErrorView(
          message: 'Unable to load reading preferences.',
        );
      }
      if (!preferences.hasValue) return const ReaderLoadingView();
      if (!identical(_locatorOwner, reader)) {
        _locatorOwner = reader;
        _currentLocator = reader.locator;
        _page.value = reader.locator.pageIndex;
      }
      return ReaderViewport(
        key: ValueKey((
          reader.manifest.key(0),
          identical(reader, _suppressedReader)
              ? _positionRevision - 1
              : _positionRevision,
        )),
        navigation: _navigation,
        onEnd: () => _end(reader),
        onLocatorChanged: (locator) {
          _currentLocator = locator;
          _page.value = locator.pageIndex;
        },
        reader: reader,
        settings: preferences.asData?.value ?? const ReadingSettings(),
        controlsVisible: _controlsVisible,
        controlsActions: ReaderActionRow(
          children: [
            ReaderQuickAction(
              label: 'Pages',
              icon: InkIcons.squaresFour,
              onPressed: () => _navigate(reader),
            ),
            ReaderQuickAction(
              label: 'Bookmarks',
              icon: InkIcons.bookmarks,
              onPressed: () => _navigate(reader, bookmarks: true),
            ),
            ReaderQuickAction(
              label: 'Settings',
              icon: InkIcons.slidersHorizontal,
              onPressed: () => _settings(reader),
            ),
            ReaderMoreAction(
              entries: [
                ReaderMenuEntry(
                  label: 'Finish volume',
                  icon: InkIcons.checkCircle,
                  onSelected: _changingChapter ? null : () => _end(reader),
                ),
                ReaderMenuEntry(
                  label: 'Reading progress',
                  icon: InkIcons.clockCounterClockwise,
                  onSelected: () => unawaited(_progress(reader)),
                ),
                ReaderMenuEntry(
                  label: 'Refresh book',
                  icon: InkIcons.arrowsClockwise,
                  onSelected: _refreshing ? null : () => unawaited(_refresh()),
                ),
              ],
            ),
          ],
        ),
        onToggleControls: _toggleControls,
        saveLocator: (locator) async {
          if (repository != null && !identical(_suppressedReader, reader)) {
            await repository.store.saveLocator(reader.manifest, locator);
          }
        },
        onToggleSpreadOffset: repository == null
            ? null
            : () => unawaited(
                _toggleSpreadOffset(repository.store, reader.manifest),
              ),
      );
    },
  );
}

/// Series title and volume number for the top bar.
typedef ReaderHeading = ({String? series, String title, double number});

/// One local catalogue lookup per opened book (titles do not change while
/// reading): no per-page or per-frame query, and no network request.
Future<ReaderHeading> loadReaderHeading(
  ReaderRepository repository,
  ReaderManifest manifest,
) async {
  try {
    final store = CatalogueStore(
      repository.store.database,
      manifest.accountId,
      applyLibraryVisibility: false,
    );
    final seriesId = manifest.seriesId;
    final (book, series) = await (
      store.item(CatalogueKind.book, manifest.bookId).first,
      seriesId == null || seriesId.isEmpty
          ? Future<CatalogueItem?>.value()
          : store.item(CatalogueKind.series, seriesId).first,
    ).wait;
    return (
      series: series?.title,
      title: book?.title ?? manifest.title,
      number: book?.number ?? 0.0,
    );
  } catch (_) {
    return (series: null, title: manifest.title, number: 0.0);
  }
}

/// Series (or book) title with the volume/page subtitle.
class _RasterTopBar extends StatelessWidget {
  const _RasterTopBar({
    required this.manifest,
    required this.heading,
    required this.page,
    required this.onBack,
    required this.onDetails,
  });
  final ReaderManifest manifest;
  final Future<ReaderHeading>? heading;
  final ValueListenable<int> page;
  final VoidCallback onBack, onDetails;

  @override
  Widget build(BuildContext context) => FutureBuilder<ReaderHeading>(
    future: heading,
    builder: (context, snapshot) {
      final seriesTitle = snapshot.data?.series;
      final volume = seriesTitle == null ? 0.0 : snapshot.data!.number;
      final count = manifest.pages.length;
      return ReaderTopBar(
        title: seriesTitle ?? manifest.title,
        onBack: onBack,
        subtitle: ValueListenableBuilder<int>(
          valueListenable: page,
          builder: (context, index, _) => Text(
            readerPositionLabel(
              AppStrings.of(context),
              index: index,
              count: count,
              volume: volume,
              lead: seriesTitle == null
                  ? null
                  : snapshot.data?.title ?? manifest.title,
            ),
            key: const Key('reader-subtitle'),
          ),
        ),
        actions: [
          ReaderDetailsButton(manifest: manifest, onPressed: onDetails),
        ],
      );
    },
  );
}

class _VolumeEndSheet extends ConsumerWidget {
  const _VolumeEndSheet({required this.next});
  final CatalogueItem? next;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloaded = ref.watch(
      downloadedBooksProvider.select(
        (value) =>
            value.asData?.value.any((b) => b.item.id == next?.id) ?? false,
      ),
    );
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: LText(
                    'Finish volume',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const CloseButton(),
              ],
            ),
            if (next != null) ...[
              Center(
                child: SizedBox(
                  width: 120,
                  height: 180,
                  child: BookCover(item: next!),
                ),
              ),
              const SizedBox(height: 12),
              Text(next!.title, textAlign: TextAlign.center),
              LText(
                downloaded
                    ? 'Available offline'
                    : 'Download required for offline reading',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: next!.canOpen
                    ? () => Navigator.pop(context, 'next')
                    : null,
                child: const LText('Read next volume'),
              ),
            ] else
              const LText('No next chapter is available.'),
            TextButton(
              onPressed: () => Navigator.pop(context, 'series'),
              child: const LText('Return to series'),
            ),
          ],
        ),
      ),
    );
  }
}
