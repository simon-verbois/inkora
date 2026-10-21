import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/icons/inkora_icons.dart';
import '../../app/widgets/ink_surface.dart';
import '../../app/l10n/app_strings.dart';
import '../../app/theme/inkora_theme.dart';
import '../../app/widgets/inkora_widgets.dart';

/// Retained publication surfaces sit behind these small, opaque control panels.
/// No blur, screenshot, shadow or surface animation is needed to reveal them.
class ReaderPanel extends StatelessWidget {
  const ReaderPanel({super.key, required this.child, this.top = false});
  final Widget child;
  final bool top;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: top,
    bottom: !top,
    child: Padding(
      padding: EdgeInsets.fromLTRB(12, top ? 8 : 0, 12, top ? 0 : 12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: InkSurface(padding: const EdgeInsets.all(8), child: child),
      ),
    ),
  );
}

/// Top reader bar: Back, the publication [title], an optional position
/// [subtitle] (for example "Vol. 01 · p. 169/184") and trailing [actions].
class ReaderTopBar extends StatelessWidget {
  const ReaderTopBar({
    super.key,
    required this.title,
    required this.onBack,
    required this.actions,
    this.subtitle,
  });
  final String title;
  final Widget? subtitle;
  final VoidCallback onBack;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ReaderPanel(
      top: true,
      child: Row(
        children: [
          BackButton(onPressed: onBack),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  key: const Key('reader-title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleSmall,
                ),
                if (subtitle != null)
                  DefaultTextStyle.merge(
                    style: text.meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    child: subtitle!,
                  ),
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

/// Position above the slider: "p. 169" and "92 % · 15 pages left".
class ReaderProgressLine extends StatelessWidget {
  const ReaderProgressLine({
    super.key,
    required this.position,
    required this.detail,
  });
  final String position;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: InkSpace.md),
      child: Row(
        children: [
          Flexible(
            child: Text(
              position,
              key: const Key('reader-position'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
          const SizedBox(width: InkSpace.md),
          Expanded(
            child: Text(
              detail,
              key: const Key('reader-progress-detail'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: style,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReaderActionFace extends StatelessWidget {
  const _ReaderActionFace({required this.label, required this.icon});
  final String label;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: InkSpace.xs),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 22),
        const SizedBox(height: InkSpace.xs),
        LText(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    ),
  );
}

/// One labelled action of the reader's bottom action row.
class ReaderQuickAction extends StatelessWidget {
  const ReaderQuickAction({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: context.tr(label),
    child: TextButton(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: InkSpace.xs),
      ),
      onPressed: onPressed,
      child: _ReaderActionFace(label: label, icon: icon),
    ),
  );
}

/// The single row of reader actions (Pages/Contents, Bookmarks, Settings,
/// More). Every action keeps an equal share of the panel width.
class ReaderActionRow extends StatelessWidget {
  const ReaderActionRow({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Row(
    key: const Key('reader-action-row'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [for (final child in children) Expanded(child: child)],
  );
}

/// One entry of the reader's More menu; a null [onSelected] disables it.
final class ReaderMenuEntry {
  const ReaderMenuEntry({
    required this.label,
    required this.icon,
    required this.onSelected,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onSelected;
}

/// The More action: a menu of less frequent reader commands.
class ReaderMoreAction extends StatelessWidget {
  const ReaderMoreAction({super.key, required this.entries});
  final List<ReaderMenuEntry> entries;
  @override
  Widget build(BuildContext context) => PopupMenuButton<int>(
    key: const Key('reader-more'),
    tooltip: context.tr('More'),
    itemBuilder: (_) => [
      for (var i = 0; i < entries.length; i++)
        PopupMenuItem(
          value: i,
          enabled: entries[i].onSelected != null,
          child: Row(
            children: [
              Icon(entries[i].icon, size: 20),
              const SizedBox(width: InkSpace.md),
              Flexible(child: LText(entries[i].label)),
            ],
          ),
        ),
    ],
    onSelected: (index) => entries[index].onSelected?.call(),
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: const Center(
        child: _ReaderActionFace(label: 'More', icon: InkIcons.dotsThree),
      ),
    ),
  );
}

/// Shared reader loading state (raster and ebook).
class ReaderLoadingView extends StatelessWidget {
  const ReaderLoadingView({
    super.key,
    this.message,
    this.actionLabel,
    this.onAction,
  });
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(InkSpace.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            semanticsLabel: message == null ? context.tr('Opening book') : null,
          ),
          if (message != null) ...[
            const SizedBox(height: InkSpace.lg),
            LText(message!, textAlign: TextAlign.center),
          ],
          if (actionLabel != null)
            TextButton(onPressed: onAction, child: LText(actionLabel!)),
        ],
      ),
    ),
  );
}

/// Shared reader error state (raster and ebook) with one recovery action.
class ReaderErrorView extends StatelessWidget {
  const ReaderErrorView({
    super.key,
    required this.message,
    this.actionLabel,
    this.onAction,
  });
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      child: InkEmptyState(
        icon: InkIcons.warningCircle,
        title: message,
        label: actionLabel,
        action: onAction,
      ),
    ),
  );
}

/// Drag state belongs only to the slider, never to the publication viewport.
class ReaderSeekBar extends StatefulWidget {
  const ReaderSeekBar({
    super.key,
    required this.position,
    required this.count,
    required this.onSeek,
    required this.onPrevious,
    required this.onNext,
    this.previewLabel,
    this.previewBuilder,
    this.trailing,
  });
  final int position, count;
  final ValueChanged<int> onSeek;
  final VoidCallback? onPrevious, onNext;
  final String Function(int)? previewLabel;
  final Widget Function(int)? previewBuilder;
  final Widget? trailing;

  @override
  State<ReaderSeekBar> createState() => _ReaderSeekBarState();
}

class _ReaderSeekBarState extends State<ReaderSeekBar> {
  int? _draft, _preview;
  Widget? _previewWidget;
  Timer? _previewTimer;
  void _drag(double value) {
    setState(() => _draft = value.round());
    _previewTimer ??= Timer(const Duration(milliseconds: 160), () {
      _previewTimer = null;
      if (mounted && _draft != null && _preview != _draft) {
        setState(() {
          _preview = _draft;
          _previewWidget = widget.previewBuilder?.call(_draft!);
        });
      }
    });
  }

  @override
  void dispose() {
    _previewTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (_draft != null && _preview != null && widget.previewBuilder != null)
        _previewWidget!,
      Row(
        children: [
          IconButton(
            tooltip: context.tr('Previous page'),
            onPressed: widget.onPrevious,
            icon: const Icon(InkIcons.caretLeft),
          ),
          Expanded(
            child: Slider(
              key: const Key('reader-page-slider'),
              min: 0,
              max: (widget.count > 1 ? widget.count - 1 : 1).toDouble(),
              value: (_draft ?? widget.position)
                  .clamp(0, widget.count > 1 ? widget.count - 1 : 1)
                  .toDouble(),
              label: widget.previewLabel?.call(_draft ?? widget.position),
              onChanged: widget.count > 1 ? _drag : null,
              onChangeEnd: widget.count > 1
                  ? (value) {
                      _previewTimer?.cancel();
                      _previewTimer = null;
                      setState(() {
                        _draft = null;
                        _preview = null;
                        _previewWidget = null;
                      });
                      widget.onSeek(value.round());
                    }
                  : null,
            ),
          ),
          if (widget.trailing != null) widget.trailing!,
          IconButton(
            tooltip: context.tr('Next page'),
            onPressed: widget.onNext,
            icon: const Icon(InkIcons.caretRight),
          ),
        ],
      ),
    ],
  );
}
