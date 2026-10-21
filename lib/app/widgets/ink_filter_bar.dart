import 'package:flutter/material.dart';

import '../icons/inkora_icons.dart';
import '../l10n/app_strings.dart';
import '../theme/inkora_theme.dart';

/// The shared browse tools of catalogue, Home, Downloads and series volumes:
/// an optional [leading] control (library selector or item count) beside a
/// expandable local [search] control, then one horizontally scrollable row of
/// filter [chips] followed by the active [sort], the advanced-filters button
/// with its active [filterCount] badge and extra [actions] (view toggles).
///
/// Windows at least 1000 logical pixels wide (after text scaling) fit both
/// rows into one. Owners keep their state; the bar only lays controls out, so
/// it rebuilds only when its owner does.
class InkFilterBar extends StatelessWidget {
  const InkFilterBar({
    super.key,
    required this.controlPrefix,
    this.leading,
    this.search,
    this.chips = const [],
    this.sort,
    this.filterCount,
    this.onFilters,
    this.actions = const [],
    this.padding = const EdgeInsets.fromLTRB(
      InkSpace.md,
      InkSpace.xs,
      InkSpace.sm,
      InkSpace.xs,
    ),
  });

  /// Prefix of the stable control keys (`<prefix>-chips`, `<prefix>-filters`).
  final String controlPrefix;
  final Widget? leading, search, sort;
  final List<Widget> chips, actions;

  /// Active advanced filters; the button is omitted when [onFilters] is null.
  final int? filterCount;
  final VoidCallback? onFilters;
  final EdgeInsetsGeometry padding;

  /// Effective width from which the two rows share one line.
  static const wideWidth = 1000.0;

  @override
  Widget build(BuildContext context) => Padding(
    padding: padding,
    child: LayoutBuilder(
      builder: (context, bounds) {
        final effectiveWidth =
            bounds.maxWidth / MediaQuery.textScalerOf(context).scale(1);
        final wide =
            effectiveWidth >= wideWidth ||
            (leading == null && search == null && effectiveWidth >= 600);
        final chipRow = chips.isEmpty
            ? const SizedBox.shrink()
            : InkChipRow(key: Key('$controlPrefix-chips'), children: chips);
        // The sort label may shrink (ellipsis) so the chips keep most of the
        // row; the chip row always takes the remaining width.
        final sortButton = sort == null
            ? null
            : ConstrainedBox(
                constraints: BoxConstraints(maxWidth: bounds.maxWidth * .35),
                child: sort,
              );
        final buttons = <Widget>[
          if (onFilters != null)
            InkFilterButton(
              key: Key('$controlPrefix-filters'),
              count: filterCount ?? 0,
              onPressed: onFilters!,
            ),
          ...actions,
        ];
        if (wide) {
          // Equal side slots keep filters centered on the whole toolbar,
          // independently of the selector and trailing action widths.
          return Row(
            children: [
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    if (leading != null) Flexible(child: leading!),
                    if (leading != null && search != null)
                      const SizedBox(width: InkSpace.sm),
                    if (search != null) Flexible(child: search!),
                  ],
                ),
              ),
              Expanded(flex: 4, child: chipRow),
              Expanded(
                flex: 3,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [?sortButton, ...buttons],
                ),
              ),
            ],
          );
        }
        // Compact windows give filters a full-width centered row. Search,
        // sort and actions share the other row so they cannot offset it.
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null ||
                search != null ||
                sortButton != null ||
                buttons.isNotEmpty)
              Row(
                children: [
                  if (leading != null)
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: bounds.maxWidth * .4,
                      ),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        widthFactor: 1,
                        child: leading,
                      ),
                    ),
                  if (leading != null && search != null)
                    const SizedBox(width: InkSpace.xs),
                  if (search != null)
                    Expanded(child: search!)
                  else
                    const Spacer(),
                  if (sortButton != null) Flexible(child: sortButton),
                  ...buttons,
                ],
              ),
            if (chips.isNotEmpty) chipRow,
          ],
        );
      },
    ),
  );
}

/// Horizontally scrollable chips with the shared spacing. Never wraps or
/// scales labels; overflowing chips scroll.
class InkChipRow extends StatelessWidget {
  const InkChipRow({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: bounds.maxWidth),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(width: InkSpace.xs + 2),
              children[i],
            ],
          ],
        ),
      ),
    ),
  );
}

/// One filter choice. Exclusive choices ([toggle] false) show no checkmark;
/// independent toggles (Downloaded) show one when selected. [label] is a
/// source message.
class InkFilterChip extends StatelessWidget {
  const InkFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.toggle = false,
    this.translate = true,
    this.icon,
  });
  final String label;
  final IconData? icon;
  final bool selected, toggle;

  /// False for server-owned values (genres, authors) that are never translated.
  final bool translate;
  final VoidCallback onSelected;
  @override
  Widget build(BuildContext context) {
    final text = translate ? LText(label) : Text(label);
    if (icon != null) {
      final name = translate ? context.tr(label) : label;
      return Semantics(
        label: selected ? null : name,
        selected: selected,
        button: true,
        child: selected
            ? FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(48, InkoraLayout.controlHeight),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  tapTargetSize: MaterialTapTargetSize.padded,
                ),
                onPressed: onSelected,
                icon: Icon(icon, size: 22),
                label: text,
              )
            : IconButton.filledTonal(
                tooltip: name,
                isSelected: selected,
                onPressed: onSelected,
                style: IconButton.styleFrom(
                  minimumSize: const Size.square(InkoraLayout.controlHeight),
                  tapTargetSize: MaterialTapTargetSize.padded,
                  backgroundColor: selected
                      ? Theme.of(context).colorScheme.secondaryContainer
                      : Colors.transparent,
                ),
                icon: Icon(icon, size: 22),
              ),
      );
    }
    return toggle
        ? FilterChip(
            label: text,
            selected: selected,
            onSelected: (_) => onSelected(),
          )
        : ChoiceChip(
            label: text,
            selected: selected,
            showCheckmark: false,
            onSelected: (_) => onSelected(),
          );
  }
}

/// Thin separator between exclusive chips and independent toggles.
class InkChipDivider extends StatelessWidget {
  const InkChipDivider({super.key});
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 24,
    child: VerticalDivider(
      width: InkSpace.sm,
      thickness: 1,
      color: InkoraColors.of(context).border,
    ),
  );
}

/// A sort choice: full menu [label] and the [short] label shown on the button.
typedef InkSortOption<T> = ({T value, String label, String short});

/// Sort button showing the active sort as text; its menu checks the current
/// option. Labels are source messages.
class InkSortButton<T> extends StatelessWidget {
  const InkSortButton({
    super.key,
    required this.value,
    required this.options,
    required this.onSelected,
    this.tooltip = 'Sort catalogue',
  });
  final T value;
  final List<InkSortOption<T>> options;
  final ValueChanged<T> onSelected;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final current = options
        .where((option) => option.value == value)
        .firstOrNull;
    final showLabel =
        MediaQuery.sizeOf(context).width >= 600 ||
        MediaQuery.textScalerOf(context).scale(1) <= 1.5;
    return PopupMenuButton<T>(
      tooltip: context.tr(tooltip),
      initialValue: value,
      onSelected: (selected) {
        if (selected != value) onSelected(selected);
      },
      itemBuilder: (_) => [
        for (final option in options)
          CheckedPopupMenuItem<T>(
            value: option.value,
            checked: option.value == value,
            child: LText(option.label),
          ),
      ],
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: InkoraLayout.touchTarget,
          minWidth: InkoraLayout.touchTarget,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: InkSpace.sm),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(InkIcons.sortAscending, size: 18),
              if (current != null && showLabel) ...[
                const SizedBox(width: InkSpace.xs),
                Flexible(
                  child: LText(
                    current.short,
                    key: const Key('sort-label'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Advanced filters button with a badge counting active advanced filters.
class InkFilterButton extends StatelessWidget {
  const InkFilterButton({
    super.key,
    required this.count,
    required this.onPressed,
  });
  final int count;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: context.tr('Filters'),
    isSelected: count > 0,
    onPressed: onPressed,
    icon: Badge(
      isLabelVisible: count > 0,
      label: Text('$count', key: const Key('filter-count')),
      child: const Icon(InkIcons.slidersHorizontal, size: 20),
    ),
  );
}

/// Local search starts as an icon and expands with keyboard focus. Its owner
/// keeps the debounced query; opening/closing affects only this control.
class InkSearchField extends StatefulWidget {
  const InkSearchField({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
    required this.onClear,
    this.showPrefixIcon = true,
  });
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final bool showPrefixIcon;

  @override
  State<InkSearchField> createState() => _InkSearchFieldState();
}

class _InkSearchFieldState extends State<InkSearchField> {
  final _focus = FocusNode();
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _open = widget.controller.text.isNotEmpty;
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_open) {
      _focus.unfocus();
      widget.onClear();
    }
    setState(() => _open = !_open);
    if (_open) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _open) _focus.requestFocus();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final child = !_open
        ? IconButton(
            key: const Key('open-search'),
            tooltip: context.tr(widget.hint),
            onPressed: _toggle,
            icon: const Icon(InkIcons.magnifyingGlass),
          )
        : SizedBox(
            width: 280,
            child: ListenableBuilder(
              listenable: _focus,
              builder: (context, child) => Stack(
                children: [
                  Positioned.fill(
                    top:
                        (InkoraLayout.touchTarget -
                            InkoraLayout.controlHeight) /
                        2,
                    bottom:
                        (InkoraLayout.touchTarget -
                            InkoraLayout.controlHeight) /
                        2,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Theme.of(context).inputDecorationTheme.fillColor,
                        borderRadius: InkRadius.large,
                        border: Border.all(
                          color: _focus.hasFocus
                              ? Theme.of(context).colorScheme.primary
                              : InkoraColors.of(context).border,
                          width: _focus.hasFocus ? 2 : 1,
                        ),
                      ),
                    ),
                  ),
                  child!,
                ],
              ),
              child: TextField(
                key: const Key('expanded-search'),
                controller: widget.controller,
                focusNode: _focus,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  isDense: true,
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  constraints: const BoxConstraints(
                    minHeight: InkoraLayout.touchTarget,
                  ),
                  hintText: context.tr(widget.hint),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  prefixIcon: widget.showPrefixIcon
                      ? const Icon(InkIcons.magnifyingGlass, size: 18)
                      : null,
                  suffixIcon: IconButton(
                    tooltip: context.tr('Clear search'),
                    onPressed: _toggle,
                    icon: const Icon(InkIcons.x, size: 18),
                  ),
                ),
                onChanged: widget.onChanged,
              ),
            ),
          );
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      widthFactor: 1,
      child: MediaQuery.disableAnimationsOf(context)
          ? child
          : AnimatedSize(
              duration: const Duration(milliseconds: 200),
              alignment: AlignmentDirectional.centerEnd,
              child: child,
            ),
    );
  }
}

/// Search in a screen header, bounded to leave room for its title on phones.
class InkHeaderSearch extends StatelessWidget {
  const InkHeaderSearch({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
    required this.onClear,
    this.compact = false,
  });
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final bool compact;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(end: 8),
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: (MediaQuery.sizeOf(context).width - 180).clamp(48, 280),
      ),
      child: InkSearchField(
        controller: controller,
        hint: hint,
        onChanged: onChanged,
        onClear: onClear,
        showPrefixIcon: !compact,
      ),
    ),
  );
}
