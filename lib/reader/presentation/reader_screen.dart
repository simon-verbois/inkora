import 'raster_navigation_sheet.dart';
import '../data/raster_bookmarks.dart';
import '../../offline/data/progress_store.dart';
import '../../offline/domain/progress.dart';
import '../../features/library/application/catalogue_providers.dart';
import '../../features/library/domain/catalogue.dart';
import '../../features/library/presentation/book_cover.dart';
import '../../offline/application/offline_coordinator.dart';
import '../../app/widgets/inkora_widgets.dart';
import '../../app/theme/inkora_motion.dart';
import 'reader_chrome.dart';
import 'reader_details.dart';
import 'ebook_reader_screen.dart';
import '../domain/gesture_zones.dart';
import '../../app/l10n/app_strings.dart';
import 'reader_gesture_guard.dart';
import '../../app/icons/inkora_icons.dart';

import 'dart:async';

import '../../offline/presentation/progress_sheet.dart';

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
    bool current,
  ) async {
    try {
      final book = await store.overrides(SettingsScope.book, manifest.bookId);
      await store.saveOverrides(
        SettingsScope.book,
        manifest.bookId,
        ReadingOverrides.fromJson({...book.toJson(), 'spreadOffset': !current}),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(content: LText('Unable to save page pairing.')),
        );
      }
    }
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: LText(
              error is ReaderFailure
                  ? error.message
                  : 'Unable to refresh this book.',
            ),
          ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: LText('No next chapter is available.')),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: LText('Unable to open the next chapter.')),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: LText('Unable to finish this volume. Try again.'),
          ),
        );
      }
    } finally {
      _ending = false;
    }
  }

  Future<void> _settings(OpenReader reader) async {
    final repository = await ref.read(readerRepositoryProvider.future);
    if (!mounted || repository == null) return;
    await showModalBottomSheet<void>(
      context: context,
      sheetAnimationStyle: InkoraMotion.sheetStyle(context),
      isScrollControlled: true,
      builder: (_) => ReaderSettingsSheet(
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
    final changed = await showModalBottomSheet<bool>(
      context: context,
      sheetAnimationStyle: InkoraMotion.sheetStyle(context),
      isScrollControlled: true,
      builder: (_) => ProgressSheet(
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
              child: ReaderTopBar(
                title: opened?.manifest.title ?? context.tr('Reader'),
                onBack: () => context.pop(),
                actions: [
                  if (opened != null)
                    ReaderDetailsButton(
                      manifest: opened.manifest,
                      onPressed: () => _details(opened),
                    ),
                  PopupMenuButton<String>(
                    tooltip: context.tr('Reading controls'),
                    icon: const Icon(InkIcons.dotsThreeVertical),
                    itemBuilder: (_) => [
                      if (opened != null)
                        const PopupMenuItem(
                          value: 'progress',
                          child: LText('Reading progress'),
                        ),
                      PopupMenuItem(
                        value: 'refresh',
                        enabled: !_refreshing,
                        child: const LText('Refresh book'),
                      ),
                    ],
                    onSelected: (value) {
                      if (value == 'progress' && opened != null) {
                        unawaited(_progress(opened));
                      } else if (value == 'refresh') {
                        unawaited(_refresh());
                      }
                    },
                  ),
                ],
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
    loading: () => Center(
      child: CircularProgressIndicator(
        semanticsLabel: context.tr("Opening book"),
      ),
    ),
    error: (error, _) => Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LText(
              error is ReaderFailure
                  ? error.message
                  : 'Unable to open this book.',
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () =>
                  ref.invalidate(openReaderProvider(widget.bookId)),
              child: const LText('Retry'),
            ),
          ],
        ),
      ),
    ),
    data: (reader) {
      if (preferences.hasError) {
        return const Center(
          child: LText('Unable to load reading preferences.'),
        );
      }
      if (!preferences.hasValue) {
        return const Center(child: CircularProgressIndicator());
      }
      if (!identical(_locatorOwner, reader)) {
        _locatorOwner = reader;
        _currentLocator = reader.locator;
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
        onLocatorChanged: (locator) => _currentLocator = locator,
        reader: reader,
        settings: preferences.asData?.value ?? const ReadingSettings(),
        controlsVisible: _controlsVisible,
        controlsActions: _ReaderActions(
          children: [
            ReaderQuickAction(
              label: 'Finish volume',
              icon: InkIcons.skipForward,
              onPressed: _changingChapter ? null : () => _end(reader),
            ),
            ReaderQuickAction(
              label: 'Page overview',
              icon: InkIcons.squaresFour,
              onPressed: () => _navigate(reader),
            ),
            ReaderQuickAction(
              label: 'Bookmarks',
              icon: InkIcons.bookmarks,
              onPressed: () => _navigate(reader, bookmarks: true),
            ),
            ReaderQuickAction(
              label: 'Reading preferences',
              icon: InkIcons.slidersHorizontal,
              onPressed: () => _settings(reader),
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
                _toggleSpreadOffset(
                  repository.store,
                  reader.manifest,
                  preferences.asData?.value.spreadOffset ?? false,
                ),
              ),
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

class _ReaderActions extends StatelessWidget {
  const _ReaderActions({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final columns =
          bounds.maxWidth < 480 ||
              MediaQuery.textScalerOf(context).scale(1) > 1.5
          ? 2
          : 4;
      return Wrap(
        children: [
          for (final child in children)
            SizedBox(width: bounds.maxWidth / columns, child: child),
        ],
      );
    },
  );
}
