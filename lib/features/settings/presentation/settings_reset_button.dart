import 'package:flutter/material.dart';

import '../../../app/l10n/app_strings.dart';
import '../../../app/widgets/inkora_widgets.dart';

/// Each page supplies its own narrowly scoped reset; server data is untouched.
class SettingsResetButton extends StatefulWidget {
  const SettingsResetButton({
    super.key,
    required this.onReset,
    this.enabled = true,
  });
  final Future<void> Function() onReset;
  final bool enabled;
  @override
  State<SettingsResetButton> createState() => _SettingsResetButtonState();
}

class _SettingsResetButtonState extends State<SettingsResetButton> {
  bool _busy = false;
  Future<void> _reset() async {
    if (!await confirmInk(
          context,
          title: 'Reset to default?',
          message: 'Restore the default settings for this page?',
          confirmLabel: 'Reset to default',
        ) ||
        !mounted) {
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.onReset();
    } catch (_) {
      if (mounted) notifyInk(context, 'Unable to reset settings. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerEnd,
    child: TextButton(
      onPressed: _busy || !widget.enabled ? null : _reset,
      child: const LText('Reset to default'),
    ),
  );
}
