import '../app/l10n/app_strings.dart';

import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'memory_pressure.dart';
import 'router.dart';
import '../features/library/application/discovery_providers.dart';
import '../offline/application/offline_coordinator.dart';
import '../features/settings/application/ui_preferences_provider.dart';
import '../features/settings/domain/ui_preferences.dart';
import 'theme/inkora_theme.dart';
import 'widgets/image_enhancement.dart';
import 'widgets/inkora_widgets.dart';

class InkoraApp extends ConsumerWidget {
  const InkoraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keep app-lifetime services alive without rebuilding MaterialApp (and
    // re-creating both themes) on each coordinator state change.
    ref.listen(discoveryLaunchDateProvider, (_, _) {});
    ref.listen(offlineCoordinatorProvider, (_, _) {});
    ref.listen(memoryPressureProvider, (_, _) {});
    final preferences = ref.watch(
      uiPreferencesProvider.select((data) {
        final value = data.asData?.value ?? const UiPreferences();
        return (
          appearance: value.appearance,
          lightTheme: value.lightTheme,
          darkTheme: value.darkTheme,
          locale: value.locale,
          reduceMotion: value.reduceMotion,
          textScale: value.textScale,
        );
      }),
    );
    // Sole owner of the decoded image budget shared by covers and reader
    // pages (the setter is a no-op when unchanged).
    PaintingBinding.instance.imageCache.maximumSizeBytes = 48 * 1024 * 1024;
    return MaterialApp.router(
      title: context.tr("Inkora"),
      locale: languageNames.containsKey(preferences.locale)
          ? AppStrings.localeFor(preferences.locale!)
          : null,
      supportedLocales: AppStrings.supportedLocales,
      localizationsDelegates: const [
        AppStrings.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      debugShowCheckedModeBanner: false,
      theme: InkoraTheme.forAppearance(
        preferences.appearance.isLight
            ? preferences.appearance
            : preferences.lightTheme,
      ),
      darkTheme: InkoraTheme.forAppearance(
        preferences.appearance.isDark
            ? preferences.appearance
            : preferences.darkTheme,
      ),
      themeMode: preferences.appearance == AppAppearance.system
          ? ThemeMode.system
          : preferences.appearance.isLight
          ? ThemeMode.light
          : ThemeMode.dark,
      themeAnimationDuration: preferences.reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 180),
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            disableAnimations:
                media.disableAnimations || preferences.reduceMotion,
            textScaler: _PreferenceTextScaler(
              media.textScaler,
              preferences.textScale,
            ),
          ),
          child: InkNotificationTheme(
            child: ImageEnhancementHost(child: child!),
          ),
        );
      },
      routerConfig: ref.watch(routerProvider),
    );
  }
}

/// Keep nonlinear platform scaling, adding the user's optional multiplier.
class _PreferenceTextScaler extends TextScaler {
  _PreferenceTextScaler(this.system, this.factor)
    : _scaleSnapshot = system.scale(14) / 14 * factor;
  final TextScaler system;
  final double factor;
  // Flutter's MediaQueryData equality uses this legacy scalar. SystemTextScaler
  // reads live platform values, so a live getter would make old/new data equal
  // during a font-size change and leave adaptive frames on their old layout.
  final double _scaleSnapshot;
  @override
  double scale(double fontSize) => system.scale(fontSize) * factor;
  @override
  double get textScaleFactor => _scaleSnapshot;
}
