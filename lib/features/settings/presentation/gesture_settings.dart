import '../../../app/widgets/inkora_widgets.dart';
import '../../../app/theme/inkora_theme.dart';
import 'preference_labels.dart';
import 'settings_reset_button.dart';
import '../../../app/l10n/app_strings.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../reader/domain/gesture_zones.dart';
import '../application/ui_preferences_provider.dart';

class GestureSettings extends ConsumerWidget {
  const GestureSettings({
    super.key,
    this.showTitle = true,
    this.showReset = true,
  });
  final bool showTitle;
  final bool showReset;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(uiPreferencesProvider).asData?.value;
    if (preferences == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final zones = preferences.gestures;
    Future<void> save(GestureZones value) async {
      try {
        await (await ref.read(uiPreferencesStoreProvider))
            .update((current) => current.copyWith(gestures: value));
      } catch (_) {
        if (context.mounted) {
          notifyInk(context, 'Unable to save gesture settings.');
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showReset)
          SettingsResetButton(onReset: () => save(const GestureZones())),
        if (showTitle)
          LText('Gestures', style: Theme.of(context).textTheme.screenTitle),
        const SizedBox(height: 12),
        const LText(
          'Reserve screen edges for system back. Swipes and zoom start only inside the reading area.',
        ),
        for (final preset in GesturePreset.values)
          Semantics(
            checked: zones.preset == preset,
            inMutuallyExclusiveGroup: true,
            child: ListTile(
              key: ValueKey('gesture-preset-${preset.name}'),
              title: LText(gesturePresetLabel(preset)),
              subtitle: preset == GesturePreset.custom
                  ? null
                  : LText(switch (preset) {
                      GesturePreset.systemNavigation =>
                        'Wide edge bands and visible system navigation',
                      GesturePreset.fullPage =>
                        'Use the entire page for swipes and zoom',
                      _ => 'Small edge bands with fullscreen reading',
                    }),
              leading: ExcludeSemantics(
                child: Icon(
                  zones.preset == preset
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                ),
              ),
              onTap: () async {
                if (preset != GesturePreset.custom) {
                  await save(GestureZones.forPreset(preset));
                  return;
                }
                final value = await showDialog<GestureZones>(
                  context: context,
                  builder: (_) => _CustomGestureDialog(initial: zones),
                );
                if (value != null && context.mounted) await save(value);
              },
            ),
          ),
      ],
    );
  }
}

/// Only the dialog draft rebuilds during a drag; persistence happens on Save.
class _CustomGestureDialog extends StatefulWidget {
  const _CustomGestureDialog({required this.initial});
  final GestureZones initial;
  @override
  State<_CustomGestureDialog> createState() => _CustomGestureDialogState();
}

class _CustomGestureDialogState extends State<_CustomGestureDialog> {
  late GestureZones _zones = widget.initial.copyWith();

  @override
  Widget build(BuildContext context) => InkDialog(
    title: 'Custom',
    scrollable: true,
    content: SizedBox(
      width: 480,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 200,
            child: LayoutBuilder(
              builder: (_, bounds) => Stack(
                key: const Key('gesture-preview'),
                fit: StackFit.expand,
                children: [
                  ColoredBox(
                    color: Theme.of(context).colorScheme.errorContainer,
                  ),
                  Positioned(
                    left: _zones.left.clamp(0, bounds.maxWidth * .4),
                    right: _zones.right.clamp(0, bounds.maxWidth * .4),
                    top: _zones.top.clamp(0, bounds.maxHeight * .4),
                    bottom: _zones.bottom.clamp(0, bounds.maxHeight * .4),
                    child: ColoredBox(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: LText(
                            'Swipe and zoom area',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          for (final edge in [
            ('Left edge', _zones.left),
            ('Right edge', _zones.right),
            ('Top edge', _zones.top),
            ('Bottom edge', _zones.bottom),
          ]) ...[
            LText(
              '{0}: {1} px',
              arguments: [context.tr(edge.$1), edge.$2.round()],
            ),
            Slider(
              key: ValueKey('gesture-edge-${edge.$1}'),
              value: edge.$2,
              min: 0,
              max: 96,
              divisions: 24,
              label: context.tr('{0} px', [edge.$2.round()]),
              semanticFormatterCallback: (value) => context.tr('{0}: {1} px', [
                context.tr(edge.$1),
                value.round(),
              ]),
              onChanged: (value) => setState(() {
                _zones = switch (edge.$1) {
                  'Left edge' => _zones.copyWith(left: value),
                  'Right edge' => _zones.copyWith(right: value),
                  'Top edge' => _zones.copyWith(top: value),
                  _ => _zones.copyWith(bottom: value),
                };
              }),
            ),
          ],
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const LText('Show system navigation while reading'),
            value: _zones.showSystemBars,
            onChanged: (value) =>
                setState(() => _zones = _zones.copyWith(showSystemBars: value)),
          ),
          const LText(
            'Your device controls the physical back gesture. These bands keep reader gestures away from its edges.',
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        key: const Key('gesture-custom-cancel'),
        onPressed: () => Navigator.of(context).pop(),
        child: const LText('Cancel'),
      ),
      FilledButton(
        key: const Key('gesture-custom-save'),
        onPressed: () => Navigator.of(context).pop(_zones),
        child: const LText('Save'),
      ),
    ],
  );
}
