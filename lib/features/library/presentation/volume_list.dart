import 'package:flutter/material.dart';

/// Lazy name-only rows. Wide windows show up to three volumes per row.
class VolumeList extends StatefulWidget {
  const VolumeList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
  });
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  @override
  State<VolumeList> createState() => _VolumeListState();
}

class _VolumeListState extends State<VolumeList> {
  /// SliverLayoutBuilder re-runs on every scroll frame; reusing the identical
  /// sliver while the cross-axis extent is unchanged keeps visible rows (and
  /// their download actions) from rebuilding per frame.
  ({double extent, Widget sliver})? _cached;

  @override
  Widget build(BuildContext context) {
    _cached = null;
    // Read inherited values here so their changes rebuild this State.
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final dividerColor = Theme.of(context).dividerColor.withValues(alpha: .25);
    return SliverLayoutBuilder(
      builder: (_, constraints) {
        final cached = _cached;
        if (cached != null && cached.extent == constraints.crossAxisExtent) {
          return cached.sliver;
        }
        final sliver = _sliver(
          constraints.crossAxisExtent,
          scale,
          dividerColor,
        );
        _cached = (extent: constraints.crossAxisExtent, sliver: sliver);
        return sliver;
      },
    );
  }

  Widget _sliver(double extent, double scale, Color dividerColor) {
    final itemCount = widget.itemCount;
    final itemBuilder = widget.itemBuilder;
    final columns = extent >= 840 * scale
        ? 3
        : extent >= 640 * scale
        ? 2
        : 1;
    return SliverList.separated(
      itemCount: (itemCount / columns).ceil(),
      separatorBuilder: (_, _) => const Divider(),
      itemBuilder: (context, row) => columns == 1
          ? itemBuilder(context, row)
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var column = 0; column < columns; column++) ...[
                  if (column > 0)
                    SizedBox(
                      width: 24,
                      height: 56,
                      child: row * columns + column < itemCount
                          ? VerticalDivider(
                              thickness: 1,
                              indent: 8,
                              endIndent: 8,
                              color: dividerColor,
                            )
                          : null,
                    ),
                  Expanded(
                    child: row * columns + column < itemCount
                        ? itemBuilder(context, row * columns + column)
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
    );
  }
}
