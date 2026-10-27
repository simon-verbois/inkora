import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/icons/inkora_icons.dart';
import '../../app/l10n/app_strings.dart';
import '../domain/ebook_settings.dart';
import 'ebook_fonts.dart';

/// A content-height field and anchored, scrollable font list. Selection stays
/// with the existing scoped settings owner, including changes from templates.
class EbookFontPicker extends StatelessWidget {
  const EbookFontPicker({
    super.key,
    required this.font,
    required this.onSelected,
  });
  final EbookFont font;
  final ValueChanged<EbookFont> onSelected;

  Widget _label(BuildContext context, EbookFont value) => Text(
    context.tr(value.label),
    softWrap: true,
    style: Theme.of(context).textTheme.bodyLarge
        ?.copyWith(fontFamily: value.previewFamily),
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) => Align(
      alignment: AlignmentDirectional.centerStart,
      child: SizedBox(
        width: math.min(bounds.maxWidth, 340),
        child: PopupMenuButton<EbookFont>(
          key: const Key('ebook-font-picker'),
          tooltip: context.tr('Font'),
          position: PopupMenuPosition.under,
          useRootNavigator: true,
          constraints: BoxConstraints(
            minWidth: math.min(240, MediaQuery.sizeOf(context).width - 32),
            maxWidth: math.min(340, MediaQuery.sizeOf(context).width - 32),
            maxHeight: math.min(320, MediaQuery.sizeOf(context).height * .45),
          ),
          onSelected: (value) {
            if (value != font) onSelected(value);
          },
          itemBuilder: (context) => [
            for (final value in EbookFont.values)
              CheckedPopupMenuItem(
                key: ValueKey('ebook-font-option-${value.id}'),
                value: value,
                checked: value == font,
                child: _label(context, value),
              ),
          ],
          child: Semantics(
            button: true,
            child: InputDecorator(
              decoration: InputDecoration(labelText: context.tr('Font')),
              child: Row(
                children: [
                  Expanded(child: _label(context, font)),
                  const SizedBox(width: 8),
                  const Icon(InkIcons.caretDown, size: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
