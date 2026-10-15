import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Reader-only system bars; never changes the application's SDK or theme.
abstract final class ReaderSystemUi {
  static const channel = MethodChannel('inkora/reader_system_ui');

  static Future<void> setImmersive(bool immersive) async {
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        // WindowInsetsController is required on current Android SDK targets.
        final handled = await channel.invokeMethod<bool>(
          'setImmersive',
          immersive,
        );
        if (handled == true) return;
      }
      await SystemChrome.setEnabledSystemUIMode(
        immersive ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
      );
    } on MissingPluginException {
      await SystemChrome.setEnabledSystemUIMode(
        immersive ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
      );
    } on PlatformException {
      // Application controls remain usable if the OS refuses system-bar changes.
    }
  }
}
