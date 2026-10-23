import '../../../app/widgets/inkora_widgets.dart';
import '../../../app/theme/inkora_theme.dart';
import 'settings_adaptive_layout.dart';
import 'preference_labels.dart';
import 'settings_reset_button.dart';
import '../../../app/l10n/app_strings.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../reader/domain/gesture_zones.dart';
import '../application/ui_preferences_provider.dart';

class GestureSettings extends ConsumerWidget {
  const GestureSettings({super.key, this.showTitle = true});
  final bool showTitle;
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
        SettingsResetButton(onReset: () => save(const GestureZones())),
        if (showTitle)
          LText('Gestures', style: Theme.of(context).textTheme.screenTitle),
        const SizedBox(height: 12),
        const LText(
          'Reserve screen edges for system back. Swipes and zoom start only inside the reading area.',
        ),
        SettingsColumns(
          first: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final preset in GesturePreset.values.where(
                (p) => p != GesturePreset.custom,
              ))
                ListTile(
                  title: LText(gesturePresetLabel(preset)),
                  subtitle: LText(switch (preset) {
                    GesturePreset.systemNavigation =>
                      'Wide edge bands and visible system navigation',
                    GesturePreset.fullPage =>
                      'Use the entire page for swipes and zoom',
                    _ => 'Small edge bands with fullscreen reading',
                  }),
                  leading: Icon(
                    zones.preset == preset
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                  ),
                  onTap: () => save(GestureZones.forPreset(preset)),
                ),
              const SizedBox(height: 12),
              SizedBox(
                height: 180,
                child: LayoutBuilder(
                  builder: (_, bounds) => Stack(
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(
                        color: Theme.of(context).colorScheme.errorContainer,
                      ),
                      Positioned(
                        left: zones.left.clamp(0, bounds.maxWidth * .4),
                        right: zones.right.clamp(0, bounds.maxWidth * .4),
                        top: zones.top.clamp(0, bounds.maxHeight * .4),
                        bottom: zones.bottom.clamp(0, bounds.maxHeight * .4),
                        child: ColoredBox(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          child: const Center(
                            child: LText('Swipe and zoom area'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
          second: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final edge in [
                ('Left edge', zones.left),
                ('Right edge', zones.right),
                ('Top edge', zones.top),
                ('Bottom edge', zones.bottom),
              ]) ...[
                LText(
                  "{0}: {1} px",
                  arguments: [context.tr(edge.$1), edge.$2.round()],
                ),
                _EdgeSlider(
                  value: edge.$2,
                  onCommit: (value) => save(switch (edge.$1) {
                    'Left edge' => zones.copyWith(left: value),
                    'Right edge' => zones.copyWith(right: value),
                    'Top edge' => zones.copyWith(top: value),
                    _ => zones.copyWith(bottom: value),
                  }),
                ),
              ],
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const LText('Show system navigation while reading'),
                value: zones.showSystemBars,
                onChanged: (value) =>
                    save(zones.copyWith(showSystemBars: value)),
              ),
              const LText(
                'Your device controls the physical back gesture. These bands keep reader gestures away from its edges.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EdgeSlider extends StatefulWidget {
  const _EdgeSlider({required this.value, required this.onCommit});
  final double value;
  final ValueChanged<double> onCommit;
  @override
  State<_EdgeSlider> createState() => _EdgeSliderState();
}

class _EdgeSliderState extends State<_EdgeSlider> {
  late double _value = widget.value;
  @override
  void didUpdateWidget(_EdgeSlider old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) _value = widget.value;
  }

  @override
  Widget build(BuildContext context) => Slider(
    value: _value,
    min: 0,
    max: 96,
    divisions: 24,
    label: context.tr('{0} px', [_value.round()]),
    onChanged: (value) => setState(() => _value = value),
    onChangeEnd: widget.onCommit,
  );
}
