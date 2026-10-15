import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../connection/application/session_controller.dart';
import '../data/ui_preferences_store.dart';
import '../domain/ui_preferences.dart';

final uiPreferencesStoreProvider = Provider<Future<UiPreferencesStore>>((
  ref,
) async {
  return UiPreferencesStore(await ref.watch(databaseProvider));
});

final uiPreferencesProvider = StreamProvider<UiPreferences>((ref) async* {
  final store = await ref.watch(uiPreferencesStoreProvider);
  yield* store.watch();
}, retry: (_, _) => null);
