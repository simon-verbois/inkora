import '../../../app/widgets/inkora_widgets.dart';
import '../../../app/theme/inkora_theme.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/l10n/app_strings.dart';
import '../../../app/icons/inkora_icons.dart';
import '../application/ui_preferences_provider.dart';

class LanguageSettings extends ConsumerWidget {
  const LanguageSettings({super.key, this.showTitle = true});
  final bool showTitle;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(uiPreferencesProvider).asData?.value;
    if (preferences == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showTitle)
          LText('Language', style: Theme.of(context).textTheme.screenTitle),
        const LText(
          'Use your device language, or choose an application language. Book titles and server metadata stay unchanged.',
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          icon: const Icon(InkIcons.caretDown, size: 20),
          isExpanded: true,
          itemHeight: null,
          key: ValueKey(preferences.locale),
          initialValue: languageNames.containsKey(preferences.locale)
              ? preferences.locale
              : 'system',
          items: [
            const DropdownMenuItem(
              value: 'system',
              child: LText('System language'),
            ),
            for (final language in languageNames.entries)
              DropdownMenuItem(
                value: language.key,
                child: Text(language.value),
              ),
          ],
          onChanged: (value) async {
            if (value == null) return;
            try {
              await (await ref.read(uiPreferencesStoreProvider)).update(
                (current) => current.copyWith(
                  locale: value == 'system' ? null : value,
                  systemLocale: value == 'system',
                ),
              );
            } catch (_) {
              if (context.mounted) {
                notifyInk(context, 'Unable to save language.');
              }
            }
          },
        ),
      ],
    );
  }
}
