import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/l10n/app_strings.dart';
import '../../../app/widgets/inkora_widgets.dart';
import '../../../core/images/image_enhancement.dart';
import '../application/ui_preferences_provider.dart';

class ImageEnhancementControl extends ConsumerStatefulWidget {
  const ImageEnhancementControl({super.key});
  @override
  ConsumerState<ImageEnhancementControl> createState() =>
      _ImageEnhancementControlState();
}

class _ImageEnhancementControlState
    extends ConsumerState<ImageEnhancementControl> {
  bool _saving = false;
  Future<void> _save(ImageEnhancement value) async {
    setState(() => _saving = true);
    try {
      await (await ref.read(uiPreferencesStoreProvider))
          .update((current) => current.copyWith(imageEnhancement: value));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: LText('Unable to save appearance settings. Try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(
      uiPreferencesProvider.select(
        (state) => state.asData?.value.imageEnhancement ?? ImageEnhancement.off,
      ),
    );
    return InkPanel(
      title: context.tr('Upscaling and sharpening'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const LText(
            'Sharpen enlarged images and covers on this device. Missing detail cannot be reconstructed.',
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<ImageEnhancement>(
            key: ValueKey(('image-enhancement', value)),
            initialValue: value,
            isExpanded: true,
            itemHeight: null,
            decoration: InputDecoration(labelText: context.tr('Strength')),
            items: [
              for (final level in ImageEnhancement.values)
                DropdownMenuItem(
                  value: level,
                  child: LText(switch (level) {
                    ImageEnhancement.off => 'Off',
                    ImageEnhancement.gentle => 'Gentle',
                    ImageEnhancement.balanced => 'Balanced',
                    ImageEnhancement.strong => 'Strong',
                  }),
                ),
            ],
            onChanged: _saving
                ? null
                : (next) {
                    if (next != null) _save(next);
                  },
          ),
        ],
      ),
    );
  }
}
