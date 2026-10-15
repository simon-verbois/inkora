import '../../app/l10n/app_strings.dart';

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
  });
  final String path;
  final PdfViewerController controller;
  final int initialPage;
  final ReadingSettings settings;
  final ValueChanged<int> onPage;
  final VoidCallback onToggleControls;
  @override
  State<EbookPdfSurface> createState() => _EbookPdfSurfaceState();
}

class _EbookPdfSurfaceState extends State<EbookPdfSurface>
    with WidgetsBindingObserver {
  bool _trimmed = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
  Widget build(BuildContext context) => PdfViewer.file(
    widget.path,
    controller: widget.controller,
    initialPageNumber: widget.initialPage,
    params: PdfViewerParams(
      backgroundColor: switch (widget.settings.background) {
        ReadingBackground.black => Colors.black,
        ReadingBackground.white => const Color(0xfffaf8f4),
        ReadingBackground.sepia => const Color(0xfff4ecd8),
      },
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
      textSelectionParams: const PdfTextSelectionParams(),
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
  );
}
