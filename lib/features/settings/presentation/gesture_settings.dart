import '../../../app/widgets/ink_settings_section.dart';
import '../../../app/widgets/inkora_widgets.dart';
import 'preference_labels.dart';
import '../../../app/l10n/app_strings.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../reader/domain/gesture_zones.dart';
import '../application/ui_preferences_provider.dart';

class GestureSettings extends ConsumerStatefulWidget {
  const GestureSettings({super.key, this.showTitle = true});
  final bool showTitle;
  @override
  ConsumerState<GestureSettings> createState() => _GestureSettingsState();
}

class _GestureSettingsState extends ConsumerState<GestureSettings> {
  final _preset = GlobalKey<FormFieldState<GesturePreset>>();
  @override
  Widget build(BuildContext context) {
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
        if (widget.showTitle)
          const InkSettingsHeading(title: 'Gestures', first: true),
        const SizedBox(height: 12),
        const LText(
          'Reserve screen edges for system back. Swipes and zoom start only inside the reading area.',
        ),
        const SizedBox(height: 20),
        DropdownButtonFormField<GesturePreset>(
          key: _preset,
          initialValue: zones.preset,
          decoration: InputDecoration(labelText: context.tr('Mode')),
          isExpanded: true,
          itemHeight: null,
          items: [
            for (final preset in GesturePreset.values)
              DropdownMenuItem(
                key: ValueKey('gesture-preset-${preset.name}'),
                value: preset,
                child: LText(gesturePresetLabel(preset)),
              ),
          ],
          onChanged: (preset) async {
            if (preset == null) return;
            if (preset != GesturePreset.custom) {
              if (preset != zones.preset) {
                await save(GestureZones.forPreset(preset));
              }
              return;
            }
            final value = await showInkPopup<GestureZones>(
              context: context,
              title: 'Custom',
              child: _CustomGestureSheet(initial: zones),
            );
            if (!context.mounted) return;
            if (value != null) await save(value);
            if (context.mounted) {
              // Cancel, unchanged Save and failed persistence all restore the
              // actual stored preset rather than the form's temporary Custom.
              _preset.currentState?.didChange(
                ref.read(uiPreferencesProvider).asData?.value.gestures.preset ??
                    zones.preset,
              );
            }
          },
        ),
        if (zones.preset == GesturePreset.custom)
          TextButton.icon(
            key: const Key('gesture-custom-edit'),
            icon: const Icon(Icons.tune),
            label: const LText('Custom'),
            onPressed: () async {
              final value = await showInkPopup<GestureZones>(
                context: context,
                title: 'Custom',
                child: _CustomGestureSheet(initial: zones),
              );
              if (value != null && context.mounted) await save(value);
            },
          ),
      ],
    );
  }
}

/// Only the sheet draft rebuilds during a drag; persistence happens on Save.
class _CustomGestureSheet extends StatefulWidget {
  const _CustomGestureSheet({required this.initial});
  final GestureZones initial;
  @override
  State<_CustomGestureSheet> createState() => _CustomGestureSheetState();
}

class _CustomGestureSheetState extends State<_CustomGestureSheet> {
  late GestureZones _zones = widget.initial.copyWith();

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
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
                ColoredBox(color: Theme.of(context).colorScheme.errorContainer),
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
            semanticFormatterCallback: (value) =>
                context.tr('{0}: {1} px', [context.tr(edge.$1), value.round()]),
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
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 12,
          children: [
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
        ),
      ],
    ),
  );
}
