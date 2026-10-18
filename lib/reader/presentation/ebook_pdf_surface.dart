import '../domain/ebook_locator.dart';
import 'reading_colors.dart';
import '../../app/l10n/app_strings.dart';
import '../../app/widgets/image_enhancement.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../domain/reading_settings.dart';

/// PDFium renders visible tiles at display/zoom size with a bounded image cache.
class EbookPdfSurface extends StatefulWidget {
  const EbookPdfSurface({
    super.key,
    required this.path,
    required this.controller,
    required this.initialPage,
    required this.settings,
    required this.onPage,
    required this.onToggleControls,
    this.onBookmark,
    this.onTextSelected,
    this.bookmarks = const [],
  });
  final String path;
  final PdfViewerController controller;
  final int initialPage;
  final ReadingSettings settings;
  final ValueChanged<int> onPage;
  final VoidCallback onToggleControls;
  final Future<void> Function(EbookLocator)? onBookmark;
  final VoidCallback? onTextSelected;
  final List<EbookLocator> bookmarks;
  @override
  State<EbookPdfSurface> createState() => _EbookPdfSurfaceState();
}

class _EbookPdfSurfaceState extends State<EbookPdfSurface>
    with WidgetsBindingObserver {
  bool _trimmed = false;
  final _bookmarkRects = <int, List<PdfRect>>{};

  void _indexBookmarks() {
    _bookmarkRects.clear();
    for (final bookmark in widget.bookmarks) {
      final rect = bookmark.pdfRectangle;
      final page = bookmark.locations['position'];
      if (page is int && rect != null) {
        (_bookmarkRects[page] ??= []).add(
          PdfRect(rect[0], rect[1], rect[2], rect[3]),
        );
      }
    }
  }

  @override
  void didUpdateWidget(EbookPdfSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.bookmarks, widget.bookmarks)) _indexBookmarks();
  }

  Future<void> _bookmarkSelection(
    PdfViewerContextMenuBuilderParams params,
  ) async {
    final ranges = await params.textSelectionDelegate.getSelectedTextRanges();
    if (!mounted || ranges.isEmpty) return;
    final first = ranges.first;
    final bounded = PdfPageTextRange(
      pageText: first.pageText,
      start: first.start,
      end: math.min(first.end, first.start + 512),
    );
    final rect = bounded.bounds;
    final bookmark = EbookLocator.bookmark({
      'href': 'document.pdf',
      'type': 'application/pdf',
      'locations': {
        'position': first.pageNumber,
        'inkoraPdfRect': [rect.left, rect.top, rect.right, rect.bottom],
      },
      'text': {'highlight': bounded.text},
    });
    await params.textSelectionDelegate.clearTextSelection();
    if (!mounted) return;
    await widget.onBookmark?.call(bookmark);
  }

  void _paintBookmarks(Canvas canvas, Rect pageRect, PdfPage page) {
    final paint = Paint()
      ..color = const Color(0xffb47d20)
      ..strokeWidth = 2;
    for (final rect in _bookmarkRects[page.pageNumber] ?? const <PdfRect>[]) {
      final marker = rect.toRectInDocument(page: page, pageRect: pageRect);
      canvas.drawLine(marker.bottomLeft, marker.bottomRight, paint);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _indexBookmarks();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didHaveMemoryPressure() {
    if (mounted) setState(() => _trimmed = true);
  }

  PdfPageLayout _horizontal(List<PdfPage> pages, PdfViewerParams params) {
    final height = pages.fold<double>(1, (h, p) => math.max(h, p.height));
    final width = pages.fold<double>(1, (w, p) => math.max(w, p.width));
    final rects = <Rect>[];
    for (var i = 0; i < pages.length; i++) {
      final page = pages[i];
      rects.add(
        Rect.fromLTWH(
          i * (width + params.margin) + (width - page.width) / 2,
          (height - page.height) / 2,
          page.width,
          page.height,
        ),
      );
    }
    return PdfPageLayout(
      pageLayouts: rects,
      documentSize: Size(pages.length * (width + params.margin), height),
    );
  }

  @override
  Widget build(BuildContext context) => EnhancedDocumentSurface(
    child: PdfViewer.file(
      widget.path,
      controller: widget.controller,
      initialPageNumber: widget.initialPage,
      params: PdfViewerParams(
        backgroundColor: widget.settings.background.paperColor,
        layoutPages: widget.settings.ebook.scroll ? null : _horizontal,
        pageDropShadow: null,
        margin: 12,
        limitRenderingCache: true,
        maxImageBytesCachedOnMemory: _trimmed
            ? 16 * 1024 * 1024
            : 64 * 1024 * 1024,
        horizontalCacheExtent: .5,
        verticalCacheExtent: .5,
        sizeDelegateProvider: PdfViewerSizeDelegateProviderSmart(
          maxPagesVisible: 1,
        ),
        errorBannerBuilder: (context, error, stack, document) =>
            const Center(child: LText('Unable to read this ebook.')),
        textSelectionParams: PdfTextSelectionParams(
          onTextSelectionChange: (selection) {
            if (selection.hasSelectedText) widget.onTextSelected?.call();
          },
        ),
        pagePaintCallbacks: [_paintBookmarks],
        customizeContextMenuItems: (params, items) {
          if (widget.onBookmark != null &&
              params.textSelectionDelegate.hasSelectedText &&
              params.textSelectionDelegate.isCopyAllowed) {
            items.insert(
              0,
              ContextMenuButtonItem(
                label: context.tr('Add bookmark'),
                onPressed: () => _bookmarkSelection(params),
              ),
            );
          }
        },
        onViewerReady: (document, controller) {
          final page = controller.pageNumber ?? widget.initialPage;
          final matrix = widget.settings.fit == ReadingFit.width
              ? controller.calcMatrixFitWidthForPage(pageNumber: page)
              : controller.calcMatrixForFit(pageNumber: page);
          if (matrix != null) controller.value = matrix;
        },
        onPageChanged: (page) {
          if (page != null) widget.onPage(page);
        },
        onGeneralTap: (context, controller, details) {
          if (details.type == PdfViewerGeneralTapType.tap &&
              details.tapOn != PdfViewerPart.selectedText) {
            widget.onToggleControls();
            return true;
          }
          return false;
        },
      ),
    ),
  );
}
