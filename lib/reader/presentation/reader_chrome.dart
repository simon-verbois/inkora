import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/icons/inkora_icons.dart';
import '../../app/widgets/ink_surface.dart';
import '../../app/l10n/app_strings.dart';

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

class ReaderTopBar extends StatelessWidget {
  const ReaderTopBar({
    super.key,
    required this.title,
    required this.onBack,
    required this.actions,
  });
  final String title;
  final VoidCallback onBack;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => ReaderPanel(
    top: true,
    child: Row(
      children: [
        BackButton(onPressed: onBack),
        Expanded(
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        ...actions,
      ],
    ),
  );
}

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
      onPressed: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22),
          const SizedBox(height: 4),
          LText(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
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
