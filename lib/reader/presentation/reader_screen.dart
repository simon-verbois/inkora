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

  Future<void> _nextChapter(OpenReader reader) async {
    setState(() => _changingChapter = true);
    try {
      final repository = await ref.read(readerRepositoryProvider.future);
      final next = await repository?.nextChapterId(reader.manifest);
      if (!mounted) return;
      if (next == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: LText('No next chapter is available.')),
        );
        return;
      }
      reader.prefetch?.suspend(true);
      if (reader.manifest.seriesId == null) {
        context.pushReplacementNamed('reader', pathParameters: {'id': next});
        return;
      }
      context.pushReplacementNamed(
        'series-reader',
        pathParameters: {
          'kind': 'series',
          'id': reader.manifest.seriesId!,
          'bookId': next,
        },
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: LText('Unable to open the next chapter.')),
        );
      }
    } finally {
      if (mounted) setState(() => _changingChapter = false);
    }
  }

  Future<void> _settings(OpenReader reader) async {
    final repository = await ref.read(readerRepositoryProvider.future);
    if (!mounted || repository == null) return;
    await showModalBottomSheet<void>(
      context: context,
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
        onLocatorChanged: (locator) => _currentLocator = locator,
        reader: reader,
        settings: preferences.asData?.value ?? const ReadingSettings(),
        controlsVisible: _controlsVisible,
        controlsActions: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ReaderQuickAction(
                label: 'Next chapter',
                icon: InkIcons.skipForward,
                onPressed: _changingChapter ? null : () => _nextChapter(reader),
              ),
            ),
            Expanded(
              child: ReaderQuickAction(
                label: 'Reading preferences',
                icon: InkIcons.slidersHorizontal,
                onPressed: () => _settings(reader),
              ),
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
