import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/l10n/app_strings.dart';
import '../domain/ebook_settings.dart';
import 'ebook_page_insets.dart';
import 'ebook_page_numbers.dart';

/// Secondary ink stays quieter than body text while retaining readable contrast.
Color ebookPageNumberInk(Color paper) {
  final luminance = paper.computeLuminance();
  final target = luminance > .179 ? Colors.black : Colors.white;
  for (var mix = 46; mix <= 100; mix++) {
    final ink = Color.lerp(paper, target, mix / 100)!;
    final inkLuminance = ink.computeLuminance();
    final ratio =
        (math.max(luminance, inkLuminance) + .05) /
        (math.min(luminance, inkLuminance) + .05);
    if (ratio >= 4.5) return ink;
  }
  return target;
}

/// Keeps the native publication above the always-visible, noninteractive folio.
/// Page updates rebuild only the numbers, retaining the publication child.
class EbookPageFrame extends StatefulWidget {
  const EbookPageFrame({
    super.key,
    required this.settings,
    required this.paper,
    required this.numbers,
    required this.onGeometryChanged,
    required this.child,
  });
  final EbookSettings settings;
  final Color paper;
  final ValueListenable<EbookPagination?> numbers;
  final VoidCallback onGeometryChanged;
  final Widget child;

  @override
  State<EbookPageFrame> createState() => _EbookPageFrameState();
}

class _EbookPageFrameState extends State<EbookPageFrame> {
  (Size, EdgeInsets, double)? _geometry;

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.viewPaddingOf(context);
    final scaler = MediaQuery.textScalerOf(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final height = scaler.scale(12) + 12;
    // Muted secondary ink, independent of possibly low-contrast custom body ink.
    final ink = ebookPageNumberInk(widget.paper);
    final strings = AppStrings.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final base = ebookPublicationInsets(
          widget.settings,
          safe,
          size,
          devicePixelRatio: dpr,
        );
        final bottom = (widget.settings.scroll || !widget.settings.pageNumbers)
            ? base.bottom
            : math.max(base.bottom, safe.bottom + height);
        final insets = base.copyWith(
          bottom: (bottom * dpr).ceilToDouble() / dpr,
        );
        final geometry = (size, insets, height);
        if (_geometry != geometry) {
          _geometry = geometry;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) widget.onGeometryChanged();
          });
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            Padding(
              key: const Key('ebook-page-margins'),
              padding: insets,
              child: widget.child,
            ),
            if (!widget.settings.scroll && widget.settings.pageNumbers)
              Positioned(
                left: insets.left,
                right: insets.right,
                bottom:
                    safe.bottom +
                    math.max(0, (insets.bottom - safe.bottom - height) / 2),
                height: height,
                child: IgnorePointer(
                  child: ValueListenableBuilder<EbookPagination?>(
                    valueListenable: widget.numbers,
                    builder: (context, numbers, _) => Row(
                      key: const Key('ebook-page-numbers'),
                      textDirection: TextDirection.ltr,
                      children: [
                        for (var i = 0; i < (numbers?.pages.length ?? 0); i++)
                          Expanded(
                            child: Center(
                              child: Text(
                                '${strings.number(numbers!.pages[i])} / ${strings.number(numbers.total)}',
                                key: ValueKey('ebook-page-number-$i'),
                                maxLines: 1,
                                style: TextStyle(
                                  color: ink,
                                  fontSize: 12,
                                  height: 1,
                                  fontWeight: FontWeight.w300,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
