import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/application/ui_preferences_provider.dart';

/// Physical hand preference is independent of the interface writing direction.
/// Only the action alignment observes changes, keeping its content stable.
class PreferredHandAlignment extends ConsumerWidget {
  const PreferredHandAlignment({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leftHanded = ref.watch(
      uiPreferencesProvider.select(
        (value) => value.asData?.value.leftHanded ?? false,
      ),
    );
    return Align(
      alignment: leftHanded ? Alignment.centerLeft : Alignment.centerRight,
      child: child,
    );
  }
}
