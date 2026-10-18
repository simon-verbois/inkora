import '../../app/theme/inkora_motion.dart';
import 'reader_chrome.dart';
import 'reader_details.dart';
import 'ebook_presentation.dart';
import 'ebook_selection.dart';
import 'reading_colors.dart';

import 'dart:isolate';

import 'package:flutter/services.dart';

import 'ebook_search_sheet.dart';
import '../domain/gesture_zones.dart';
import 'reader_gesture_guard.dart';
import '../application/reader_providers.dart';
import '../../offline/presentation/progress_sheet.dart';
import '../domain/page_source.dart';

import 'package:pdfrx/pdfrx.dart';

import 'ebook_pdf_surface.dart';

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_readium/flutter_readium.dart' hide ReadiumReaderWidget;
import 'package:flutter_readium/reader_widget.dart' as native;
import 'package:go_router/go_router.dart';

import '../../app/icons/inkora_icons.dart';
import '../../app/widgets/image_enhancement.dart';
import '../../core/images/image_enhancement.dart';
import '../../app/l10n/app_strings.dart';
import '../../offline/application/offline_coordinator.dart';
import '../../offline/data/download_store.dart';
import '../../offline/data/progress_store.dart';
import '../../offline/domain/progress.dart';
import '../data/ebook_bookmarks.dart';
import '../data/ebook_text_search.dart';
import '../data/manifest_codec.dart';
import '../data/reader_repository.dart';
import '../domain/ebook_locator.dart';
import '../domain/reader_manifest.dart';
import '../domain/reading_settings.dart';
import 'reader_settings_sheet.dart';
import 'reader_system_ui.dart';

/// Local native publication surface. Position events update only the footer;
/// native reflow and navigation never reconstruct the platform view.
class EbookReaderScreen extends ConsumerStatefulWidget {
  const EbookReaderScreen({
    super.key,
    required this.reader,
    required this.repository,
    required this.settings,
    this.gestureZones = const GestureZones(),
  });
  final OpenReader reader;
  final ReaderRepository repository;
  final ReadingSettings settings;
  final GestureZones gestureZones;
  @override
  ConsumerState<EbookReaderScreen> createState() => _EbookReaderScreenState();
}

class _EbookReaderScreenState extends ConsumerState<EbookReaderScreen>
    with WidgetsBindingObserver {
  final _engine = FlutterReadium();
  final _controls = ValueNotifier(false);
  final _position = ValueNotifier<(int, double)>((0, 0));
  StreamSubscription<Locator>? _locations;
  StreamSubscription<List<DownloadJob>>? _downloadWatch;
  Completer<void>? _downloadDone;
  StreamSubscription<ReadiumError>? _errors;
  Publication? _publication;
  EbookPositionMap? _positionMap;
  final _pdfController = PdfViewerController();
  String? _pdfPath;
  Widget? _surface;
  String? _message;
  Locator? _current;
  ReaderLocator? _pending;
  Timer? _saveTimer;
  Future<void> _writes = Future.value();
  Future<void> _preferences = Future.value();
  Future<void> _bookmarkWrites = Future.value();
  bool _bookmarkDecorationsReady = false;
  bool _presentationReady = false;
  bool _disableAnimations = false;
  (bool, bool, ImageEnhancement)? _lastPresentation;
  ImageEnhancement _imageEnhancement = ImageEnhancement.off;
  EPUBPreferences? _lastEPUBPreferences;
  bool _backgrounded = false;
  bool _rewind = false;
  bool _savingSuppressed = false;
  ReaderLocator? _lastLocator;
  bool get _epub =>
      widget.reader.manifest.documentType == 'application/epub+zip';
  ReaderManifest get _manifest => widget.reader.manifest;
  late final _bookmarks = EbookBookmarks(
    widget.repository.store.database,
    _manifest.accountId,
    _manifest.bookId,
  );
  List<EbookLocator> _saved = [];

  // Readium's API owns one native publication. Serialize close/open across
  // route replacement so disposal cannot close the following book.
  static Future<void> _nativeLifecycle = Future.value();
  Future<T> _native<T>(Future<T> Function() action) {
    final result = _nativeLifecycle.then((_) => action());
    _nativeLifecycle = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controls.addListener(_chromeChanged);
    _chromeChanged();
    _position.value = (
      widget.reader.locator.pageIndex,
      widget.reader.locator.fraction,
    );
    unawaited(_open());
  }

  void _chromeChanged() => unawaited(
    ReaderSystemUi.setImmersive(
      !_controls.value && !widget.gestureZones.showSystemBars,
    ),
  );
  Future<void> _open() async {
    try {
      var file = await widget.repository.assets.documentFile(_manifest);
      if (!mounted) return;
      if (file == null) {
        if (widget.reader.offline) {
          throw const FormatException('Offline ebook unavailable');
        }
        final coordinator = await ref.read(offlineCoordinatorProvider.future);
        if (coordinator == null || !mounted) return;
        final id = await coordinator.downloads.enqueue(_manifest.bookId);
        final job = await coordinator.store.job(id);
        if (job?.state != DownloadState.complete) {
          final done = _downloadDone = Completer<void>();
          _downloadWatch = coordinator.store.watch().listen(
            (jobs) {
              if (done.isCompleted) return;
              final current = jobs.where((j) => j.id == id).firstOrNull;
              if (current?.state == DownloadState.failed ||
                  current?.state == DownloadState.cancelled ||
                  current?.state == DownloadState.paused) {
                done.completeError(
                  const FormatException('Ebook download interrupted'),
                );
              } else if (current?.state == DownloadState.complete) {
                done.complete();
              }
            },
            onError: (Object error, StackTrace trace) {
              if (!done.isCompleted) done.completeError(error, trace);
            },
          );
          try {
            await done.future;
          } finally {
            await _downloadWatch?.cancel();
            _downloadWatch = null;
            _downloadDone = null;
          }
        }
        if (!mounted) return;
        file = await widget.repository.assets.documentFile(_manifest);
      }
      if (file == null || !mounted) {
        throw const FormatException('Missing ebook file');
      }
      _saved = await _bookmarks.read();
      if (_epub) {
        _positionMap = await buildEbookPositionMap(_manifest.positions);
      }
      if (!mounted) return;
      if (!_epub) {
        _pdfPath = file.path;
        _surface = _pdfSurface();
        setState(() {});
        return;
      }
      final publication = await _native(() async {
        if (!mounted) throw const FormatException('Reader closed');
        await _engine.setLogLevel(LogLevel.error);
        // Credentials never enter the document renderer or its resource loader.
        await _engine.setCustomHeaders({});
        await _engine.closePublication();
        final opened = await _engine.openPublication(file!.uri.toString());
        await _applyPreferences();
        return opened;
      });
      if (!mounted) return;
      _publication = publication;
      final restored = widget.reader.locator;
      Locator? initial;
      if (_epub && restored.documentLocator != null) {
        initial = Locator.fromJson(
          EbookLocator.decode(restored.documentLocator!).value,
        );
      } else if (_epub && restored.pageIndex > 0) {
        initial = Locator.fromJson(_manifest.positions[restored.pageIndex]);
      } else if (!_epub && publication.readingOrder.isNotEmpty) {
        initial = Locator(
          href: publication.readingOrder.first.href,
          type: 'application/pdf',
          locations: Locations(position: restored.pageIndex + 1),
        );
      }
      _current = initial;
      _locations = _engine.onTextLocatorChanged.listen(_locationChanged);
      _errors = _engine.onErrorEvent.listen(
        (_) => _showError('Unable to read this ebook.'),
      );
      _surface = native.ReadiumReaderWidget(
        preloadPreviousPositionCount: 1,
        preloadNextPositionCount: 2,
        publication: publication,
        initialLocator: initial,
        shouldShowControls: _controls,
        goBackwardSemanticLabel: context.tr('Previous page'),
        goForwardSemanticLabel: context.tr('Next page'),
        toggleShowControlsSemanticLabel: context.tr('Reading controls'),
        onExternalLinkActivated: (_) {},
        fontFamilyDeclarations: [_baskerville],
        selectionActions: [
          SelectionAction(
            id: 'inkora-bookmark',
            title: context.tr('Add bookmark'),
          ),
          if (Theme.of(context).platform == TargetPlatform.android)
            SelectionAction(id: 'inkora-copy', title: context.tr('Copy')),
        ],
        allowedDefaultActions: const {DefaultSelectionAction.copy},
        onTextSelected: (_) => _controls.value = false,
        onSelectionAction: (event) {
          if (event.actionId == 'inkora-bookmark') {
            unawaited(
              _addBookmark(event.locator, selectedText: event.selectedText),
            );
          } else if (event.actionId == 'inkora-copy') {
            unawaited(
              _copySelection(
                event.selectedText ?? event.locator.text?.highlight ?? '',
              ),
            );
          }
        },
      );
      setState(() {});
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = 'Unable to open this ebook. Check the download and file permissions.',
        );
      }
    }
  }

  static final _baskerville = ReaderFontFamily(
    name: 'InkoraBaskerville',
    fallbacks: const ['serif'],
    faces: const [ReaderFontFace(asset: 'assets/fonts/LibreBaskerville.ttf')],
  );

  Widget _pdfSurface() => EbookPdfSurface(
    path: _pdfPath!,
    controller: _pdfController,
    initialPage: _position.value.$1 + 1,
    settings: widget.settings,
    bookmarks: _saved,
    onBookmark: (locator) => _addBookmark(Locator.fromJson(locator.value)!),
    onTextSelected: () => _controls.value = false,
    onPage: (page) => _locationChanged(
      Locator(
        href: 'document.pdf',
        type: 'application/pdf',
        locations: Locations(position: page),
      ),
    ),
    onToggleControls: () => _controls.value = !_controls.value,
  );

  Future<void> _decorateBookmarks() async {
    if (!mounted || !_epub || !_bookmarkDecorationsReady) return;
    try {
      await _native(() async {
        if (!mounted) return;
        await _engine.applyDecorations('inkora-bookmarks', [
          for (var i = 0; i < _saved.length; i++)
            if (_saved[i].excerpt.isNotEmpty &&
                Locator.fromJson(_saved[i].value) != null)
              ReaderDecoration(
                id: 'bookmark-$i',
                locator: Locator.fromJson(_saved[i].value)!,
                style: const ReaderDecorationStyle(
                  style: DecorationStyle.underline,
                  tint: Color(0xffd39a32),
                ),
              ),
        ]);
      });
    } catch (_) {
      _showError('Unable to display bookmarks.');
    }
  }

  Future<void> _addBookmark(Locator locator, {String? selectedText}) async {
    try {
      final bookmark = await _selectedBookmark(locator, selectedText);
      await _clearSelection();
      await _mutateBookmarks(() => _bookmarks.add(bookmark), announce: true);
    } catch (_) {
      _showError('Unable to save bookmark.');
    }
  }

  Future<void> _clearSelection() => _native(() async {
    if (mounted && _epub) await clearEbookSelection();
  });

  Future<void> _copySelection(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    await _clearSelection();
  }

  Future<void> _mutateBookmarks(
    Future<List<EbookLocator>> Function() action, {
    bool announce = false,
  }) {
    final next = _bookmarkWrites.then((_) async {
      final before = _saved.length;
      final saved = await action();
      if (!mounted) return;
      _saved = saved;
      if (_epub) {
        await _decorateBookmarks();
      } else {
        setState(() => _surface = _pdfSurface());
      }
      if (announce && saved.length > before) _showError('Bookmark added');
    });
    _bookmarkWrites = next.catchError(
      (Object _) => _showError('Unable to save bookmark.'),
    );
    return _bookmarkWrites;
  }

  Future<void> _applyPreferences() async {
    final settings = widget.settings;
    final ebook = settings.ebook;
    final background = settings.background.paperColor;
    if (_epub) {
      final prefs = EPUBPreferences(
        fontFamily: ebook.font == 'publisher'
            ? null
            : ebook.font == 'baskerville'
            ? 'InkoraBaskerville'
            : ebook.font,
        fontSize: ebook.fontSize,
        lineHeight: ebook.lineHeight,
        pageMargins: ebook.margins,
        scroll: ebook.scroll,
        columnCount: EpubColumnCount.values.byName(ebook.columns),
        publisherStyles: ebook.publisherStyles,
        textAlign: ebook.justify ? TextAlign.justify : TextAlign.start,
        backgroundColor: background,
        textColor: settings.background.inkColor,
      );
      if (_lastEPUBPreferences != prefs) {
        _engine.setDefaultPreferences(prefs);
        await _engine.setEPUBPreferences(prefs);
        _lastEPUBPreferences = prefs;
      }
      await _configurePresentation();
    }
  }

  Future<void> _configurePresentation({bool force = false}) async {
    if (!mounted || !_epub) return;
    final value = (
      widget.settings.pageAnimation && !_disableAnimations,
      widget.settings.ebook.columnSeparator && !widget.settings.ebook.scroll,
      _imageEnhancement,
    );
    if (!force && _lastPresentation == value) return;
    try {
      if (await EbookPresentation.configure(
        animations: value.$1,
        separator: value.$2,
        imageEnhancement: value.$3,
      )) {
        _lastPresentation = value;
      }
    } catch (_) {
      _showError('Unable to apply ebook settings.');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.disableAnimationsOf(context);
    final enhancement = ImageEnhancementScope.levelOf(context);
    if (_disableAnimations != reduced || _imageEnhancement != enhancement) {
      _disableAnimations = reduced;
      _imageEnhancement = enhancement;
      if (_publication != null) unawaited(_configurePresentation());
    }
  }

  @override
  void didUpdateWidget(EbookReaderScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings != widget.settings && !_epub && _pdfPath != null) {
      setState(() => _surface = _pdfSurface());
    }
    if (oldWidget.settings != widget.settings && _publication != null) {
      _preferences = _preferences
          .then((_) => _applyPreferences())
          .catchError(
            (Object _) => _showError('Unable to apply ebook settings.'),
          );
    }
  }

  void _locationChanged(Locator locator) {
    if (!mounted || _backgrounded) return;
    if (!_presentationReady) {
      _presentationReady = true;
      unawaited(_configurePresentation(force: true));
    }
    if (_epub && !_bookmarkDecorationsReady) {
      _bookmarkDecorationsReady = true;
      unawaited(_decorateBookmarks());
    }
    try {
      _current = locator;
      final raw =
          jsonDecode(jsonEncode(locator.toJson())) as Map<String, dynamic>;
      int page;
      String? exact;
      double fraction = 0;
      if (_epub) {
        final (index, mapped) = _positionMap!.map(EbookLocator(raw));
        page = index;
        fraction = mapped.progression;
        exact = mapped.encode();
      } else {
        page = ((locator.locations?.position ?? 1) - 1).clamp(
          0,
          _manifest.pages.length - 1,
        );
      }
      final position = (page, fraction);
      _position.value = position;
      final next = ReaderLocator(page, fraction, exact);
      if (_pending?.pageIndex == page &&
          _pending?.fraction == fraction &&
          _pending?.documentLocator == exact) {
        return;
      }
      _lastLocator = next;
      if (_savingSuppressed) return;
      _pending = next;
      _saveTimer?.cancel();
      _saveTimer = Timer(const Duration(milliseconds: 350), _flush);
    } catch (_) {
      _showError('Unable to save reading position.');
    }
  }

  void _flush() {
    _saveTimer?.cancel();
    _saveTimer = null;
    final locator = _pending;
    _pending = null;
    if (locator == null) return;
    final rewind = _rewind;
    _rewind = false;
    _writes = _writes
        .then(
          (_) =>
              ProgressStore(
                widget.repository.store.database,
                _manifest.accountId,
              ).save(
                _manifest,
                locator,
                operation: rewind
                    ? ProgressOperation.rewind
                    : ProgressOperation.advance,
              ),
        )
        .catchError(
          (Object _) => _showError('Unable to save reading position.'),
        );
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.maybeOf(context)
          ?.showSnackBar(SnackBar(content: LText(message)));
    }
  }

  Future<void> _jump(Locator locator) async {
    try {
      _flush();
      _rewind = true;
      if (_epub) {
        if (!await _engine.goToLocator(locator)) _rewind = false;
      } else if (_pdfController.isReady) {
        final page = (locator.locations?.position ?? 1).clamp(
          1,
          _manifest.pages.length,
        );
        final bookmark = EbookLocator(
          jsonDecode(jsonEncode(locator.toJson())) as Map<String, dynamic>,
        );
        final rect = bookmark.pdfRectangle;
        if (rect == null) {
          await _pdfController.goToPage(
            pageNumber: page,
            duration: Duration.zero,
          );
        } else {
          final zoom = _pdfController.currentZoom;
          // Set the engine's page hint, then restore scale before the next frame.
          await _pdfController.goToPage(
            pageNumber: page,
            duration: Duration.zero,
          );
          final target = _pdfController.calcRectForRectInsidePage(
            pageNumber: page,
            rect: PdfRect(rect[0], rect[1], rect[2], rect[3]),
          );
          // goToPage fits the page; the text jump restores the captured zoom.
          await _pdfController.goToPosition(
            documentOffset: Offset(
              target.left - 24 / zoom,
              target.top - 48 / zoom,
            ),
            zoom: zoom,
          );
        }
      }
    } catch (_) {
      _rewind = false;
      _showError('Unable to navigate to this position.');
    }
  }

  Future<void> _toc() async {
    final publication = _publication;
    final entries = <(String, Locator)>[];
    if (publication != null) {
      for (final link in publication.tocFlattened) {
        final locator = publication.locatorFromLink(link);
        if (locator != null) entries.add((link.title ?? link.href, locator));
      }
    } else if (_pdfController.isReady) {
      void add(List<PdfOutlineNode> nodes) {
        for (final node in nodes) {
          if (node.dest != null) {
            entries.add((
              node.title,
              Locator(
                href: 'document.pdf',
                type: 'application/pdf',
                locations: Locations(position: node.dest!.pageNumber),
              ),
            ));
          }
          add(node.children);
        }
      }

      add(await _pdfController.document.loadOutline());
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      sheetAnimationStyle: InkoraMotion.sheetStyle(context),
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .7,
          child: Column(
            children: [
              const ListTile(title: LText('Table of contents')),
              Expanded(
                child: entries.isEmpty
                    ? const Center(
                        child: LText('No table of contents available.'),
                      )
                    : ListView.builder(
                        itemCount: entries.length,
                        itemBuilder: (context, i) => ListTile(
                          title: Text(entries[i].$1),
                          onTap: () {
                            Navigator.pop(context);
                            unawaited(_jump(entries[i].$2));
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _bookmarkList() async {
    await showModalBottomSheet<void>(
      context: context,
      sheetAnimationStyle: InkoraMotion.sheetStyle(context),
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .7,
            child: Column(
              children: [
                ListTile(
                  title: const LText('Bookmarks'),
                  trailing: IconButton(
                    tooltip: context.tr('Add bookmark'),
                    icon: const Icon(Icons.add),
                    onPressed: _current == null
                        ? null
                        : () async {
                            await _addBookmark(_current!);
                            if (context.mounted) update(() {});
                          },
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: LText(
                    'Hold a word or line, then choose Add bookmark.',
                  ),
                ),
                Expanded(
                  child: _saved.isEmpty
                      ? const Center(child: LText('No bookmarks yet.'))
                      : ListView.builder(
                          itemCount: _saved.length,
                          itemBuilder: (context, i) {
                            final bookmark = _saved[i];
                            return ListTile(
                              title: Text(
                                bookmark.value['title'] as String? ??
                                    context.tr('Bookmark {0}', [i + 1]),
                              ),
                              subtitle: bookmark.excerpt.isEmpty
                                  ? null
                                  : Text(
                                      bookmark.excerpt,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                              onTap: () async {
                                final route = ModalRoute.of(context);
                                final locator = Locator.fromJson(
                                  bookmark.value,
                                );
                                Navigator.pop(context);
                                // Native layout restoration during sheet dismissal
                                // can overwrite a jump within the same chapter.
                                await route?.completed;
                                if (mounted && locator != null) {
                                  await _jump(locator);
                                }
                              },
                              trailing: IconButton(
                                tooltip: context.tr('Remove bookmark'),
                                icon: const Icon(Icons.close),
                                onPressed: () async {
                                  await _mutateBookmarks(
                                    () => _bookmarks.remove(bookmark),
                                  );
                                  if (context.mounted) update(() {});
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<List<TextSearchResult>> _searchBook(
    String query,
    CancellationSignal cancellation,
  ) async {
    if (_epub) return _engine.searchInPublication(query);
    if (!_pdfController.isReady) return [];
    final results = <TextSearchResult>[];
    for (final page in _pdfController.document.pages) {
      if (cancellation.isCancelled) break;
      final text = await page.loadText();
      if (cancellation.isCancelled || !mounted) break;
      if (text == null) continue;
      final snippet = await ebookSearchSnippet(text.fullText, query);
      if (cancellation.isCancelled || !mounted) break;
      if (snippet == null) continue;
      results.add(
        TextSearchResult(
          chapterTitle: context.tr('Page {0}', [page.pageNumber]),
          locator: Locator(
            href: 'document.pdf',
            type: 'application/pdf',
            locations: Locations(position: page.pageNumber),
            text: LocatorText(highlight: snippet),
          ),
        ),
      );
      if (results.length >= 200) break;
    }
    return results;
  }

  Future<void> _turn(int delta) async {
    try {
      if (_epub) {
        final handled = await EbookPresentation.turn(
          delta,
          animated: widget.settings.pageAnimation && !_disableAnimations,
        );
        if (!handled) {
          await (delta < 0 ? _engine.goBackward() : _engine.goForward());
        }
      } else if (_pdfController.isReady) {
        await _pdfController.goToPage(
          duration: widget.settings.pageAnimation && !_disableAnimations
              ? const Duration(milliseconds: 220)
              : Duration.zero,
          pageNumber: (_position.value.$1 + delta + 1).clamp(
            1,
            _manifest.pages.length,
          ),
        );
      }
    } catch (_) {
      _showError('Unable to navigate to this position.');
    }
  }

  Future<void> _seek(int index) async {
    final locator = _epub
        ? Locator.fromJson(_manifest.positions[index])
        : Locator(
            href: 'document.pdf',
            type: 'application/pdf',
            locations: Locations(position: index + 1),
          );
    if (locator == null) {
      _showError('Unable to navigate to this position.');
      return;
    }
    await _jump(locator);
  }

  Future<void> _search() async {
    final locator = await showModalBottomSheet<Locator>(
      context: context,
      sheetAnimationStyle: InkoraMotion.sheetStyle(context),
      isScrollControlled: true,
      builder: (context) => EbookSearchSheet(search: _searchBook),
    );
    if (locator != null && mounted) await _jump(locator);
  }

  Future<void> _progress() async {
    _flush();
    await _writes;
    if (!mounted) return;
    final changed = await showModalBottomSheet<bool>(
      context: context,
      sheetAnimationStyle: InkoraMotion.sheetStyle(context),
      isScrollControlled: true,
      builder: (context) => ProgressSheet(
        manifest: _manifest,
        currentLocator: _lastLocator ?? widget.reader.locator,
        onChanging: () {
          _savingSuppressed = true;
          _pending = null;
          _saveTimer?.cancel();
        },
      ),
    );
    if (!mounted) return;
    if (changed == true) {
      ref.invalidate(openReaderProvider(_manifest.bookId));
    } else {
      _savingSuppressed = false;
    }
  }

  Future<void> _settings() async {
    await showModalBottomSheet<void>(
      context: context,
      sheetAnimationStyle: InkoraMotion.sheetStyle(context),
      isScrollControlled: true,
      builder: (context) => ReaderSettingsSheet(
        store: widget.repository.store,
        manifest: _manifest,
        modal: true,
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Native view/keyboard focus changes can make a visible reader inactive.
    // Only an actually hidden/paused app stops accepting location events.
    _backgrounded =
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached;
    if (state != AppLifecycleState.resumed) {
      _flush();
    } else {
      _chromeChanged();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _flush();
    unawaited(_locations?.cancel());
    unawaited(_errors?.cancel());
    unawaited(_downloadWatch?.cancel());
    final done = _downloadDone;
    if (done != null && !done.isCompleted) {
      done.completeError(const FormatException('Reader closed'));
    }
    _controls.removeListener(_chromeChanged);
    _controls.dispose();
    _position.dispose();
    if (_epub) unawaited(_native(_engine.closePublication));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    body: Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: ReaderGestureGuard(
            zones: widget.gestureZones,
            child:
                (_surface == null
                    ? null
                    : _epub
                    ? ColoredBox(
                        color: widget.settings.background.paperColor,
                        child: Padding(
                          key: const Key('ebook-page-margins'),
                          padding: EdgeInsets.symmetric(
                            vertical: widget.settings.ebook.margins * 24,
                          ),
                          child: _surface,
                        ),
                      )
                    : _surface) ??
                Center(
                  child: _message == null
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 16),
                            const LText('Preparing ebook for offline reading…'),
                            TextButton(
                              onPressed: () => context.push('/downloads'),
                              child: const LText('Downloads'),
                            ),
                          ],
                        )
                      : Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              LText(_message!),
                              const SizedBox(height: 16),
                              TextButton(
                                onPressed: () => context.pop(),
                                child: const LText('Back'),
                              ),
                            ],
                          ),
                        ),
                ),
          ),
        ),
        ValueListenableBuilder<bool>(
          valueListenable: _controls,
          builder: (context, visible, _) => visible || _surface == null
              ? Align(
                  alignment: Alignment.topCenter,
                  child: ReaderTopBar(
                    title: _manifest.title,
                    onBack: () => context.pop(),
                    actions: [
                      ReaderDetailsButton(manifest: _manifest),
                      if (_surface != null) ...[
                        IconButton(
                          tooltip: context.tr('Search in book'),
                          icon: const Icon(InkIcons.magnifyingGlass),
                          onPressed: _search,
                        ),
                        PopupMenuButton<String>(
                          tooltip: context.tr('Reading controls'),
                          icon: const Icon(InkIcons.dotsThreeVertical),
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'progress',
                              child: LText('Reading progress'),
                            ),
                          ],
                          onSelected: (_) => unawaited(_progress()),
                        ),
                      ],
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
        ValueListenableBuilder<bool>(
          valueListenable: _controls,
          builder: (context, visible, _) => !visible || _surface == null
              ? const SizedBox.shrink()
              : Align(
                  alignment: Alignment.bottomCenter,
                  child: ReaderPanel(
                    child: ValueListenableBuilder<(int, double)>(
                      valueListenable: _position,
                      builder: (context, position, _) {
                        final count = _epub
                            ? _manifest.positions.length
                            : _manifest.pages.length;
                        String progressLabel(int index) => _epub
                            ? context.tr('{0}% read', [
                                (EbookLocator(_manifest.positions[index])
                                            .total *
                                        100)
                                    .round(),
                              ])
                            : context.tr('Page {0}/{1}', [index + 1, count]);
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _current?.title ??
                                          context.tr('Reading progress'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium,
                                    ),
                                  ),
                                  Text(
                                    count == 0
                                        ? context.tr('Reading progress')
                                        : progressLabel(position.$1),
                                    key: const Key('reader-position'),
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium,
                                  ),
                                ],
                              ),
                            ),
                            ReaderSeekBar(
                              position: position.$1,
                              count: count,
                              previewLabel: count == 0 ? null : progressLabel,
                              onPrevious: position.$1 > 0 || position.$2 > 0
                                  ? () => _turn(-1)
                                  : null,
                              onNext: _epub || position.$1 < count - 1
                                  ? () => _turn(1)
                                  : null,
                              onSeek: _seek,
                            ),
                            const Divider(height: 1),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: ReaderQuickAction(
                                    label: 'Table of contents',
                                    icon: InkIcons.list,
                                    onPressed: _toc,
                                  ),
                                ),
                                Expanded(
                                  child: ReaderQuickAction(
                                    label: 'Bookmarks',
                                    icon: InkIcons.bookmarks,
                                    onPressed: _bookmarkList,
                                  ),
                                ),
                                Expanded(
                                  child: ReaderQuickAction(
                                    label: 'Reading preferences',
                                    icon: InkIcons.slidersHorizontal,
                                    onPressed: _settings,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
        ),
      ],
    ),
  );
}

// Keep worker captures separate from reader state, services and platform views.
Future<EbookLocator> _selectedBookmark(Locator locator, String? selectedText) =>
    Isolate.run(
      () => EbookLocator.bookmark(
        jsonDecode(jsonEncode(locator.toJson())) as Map<String, dynamic>,
        selectedText: selectedText,
      ),
    );
