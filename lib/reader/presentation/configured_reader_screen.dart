import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/application/ui_preferences_provider.dart';
import '../domain/gesture_zones.dart';
import 'reader_screen.dart';

/// App composition stays outside the reader so embedding/tests need no device DB.
class ConfiguredReaderScreen extends ConsumerWidget {
  const ConfiguredReaderScreen({super.key, required this.bookId});
  final String bookId;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ReaderScreen(
    bookId: bookId,
    gestureZones:
        ref.watch(
          uiPreferencesProvider.select((value) => value.asData?.value.gestures),
        ) ??
        const GestureZones(),
  );
}
