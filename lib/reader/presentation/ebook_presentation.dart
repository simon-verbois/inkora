import 'package:flutter/foundation.dart';

import 'package:flutter/services.dart';

import '../../core/images/image_enhancement.dart';

/// Small typed adapter for the pinned Android EPUB navigator. No document
/// scripts, metadata or credentials cross this channel.
abstract final class EbookPresentation {
  static const channel = MethodChannel('inkora/ebook_presentation');
  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<Uint8List> paperTile() async {
    final bytes = await channel.invokeMethod<Uint8List>('paperTile');
    if (bytes == null || bytes.isEmpty || bytes.length > 256 * 1024) {
      throw const FormatException('Invalid paper tile');
    }
    return bytes;
  }

  static Future<void> trimMemory() async {
    if (!supported) return;
    try {
      await channel.invokeMethod<void>('trimMemory');
    } on MissingPluginException {
      // Reader may never have been initialized in the current process.
    } on PlatformException {
      // Memory-pressure handling must not interrupt the active view.
    }
  }

  static Future<bool> configure({
    required bool animations,
    required bool separator,
    bool tapToTurnPages = false,
    int dividerColor = 0xff252320,
    bool paperTexture = false,
    ImageEnhancement imageEnhancement = ImageEnhancement.off,
  }) async {
    if (!supported) return false;
    try {
      return await channel.invokeMethod<bool>('configure', {
            'animations': animations,
            'separator': separator,
            'dividerColor': dividerColor,
            'paperTexture': paperTexture,
            'tapToTurnPages': tapToTurnPages,
            'imageEnhancement': imageEnhancement.index,
          }) ??
          false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<bool> turn(int delta, {required bool animated}) async {
    assert(delta == -1 || delta == 1);
    if (!supported) return false;
    try {
      return await channel.invokeMethod<bool>('turn', {
            'forward': delta > 0,
            'animated': animated,
          }) ??
          false;
    } on MissingPluginException {
      return false;
    }
  }
}
