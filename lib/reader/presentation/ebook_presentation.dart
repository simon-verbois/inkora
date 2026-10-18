import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../core/images/image_enhancement.dart';

/// Small typed adapter for the pinned Android EPUB navigator. No document
/// scripts, metadata or credentials cross this channel.
abstract final class EbookPresentation {
  static const channel = MethodChannel('inkora/ebook_presentation');
  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<bool> configure({
    required bool animations,
    required bool separator,
    ImageEnhancement imageEnhancement = ImageEnhancement.off,
  }) async {
    if (!supported) return false;
    try {
      return await channel.invokeMethod<bool>('configure', {
            'animations': animations,
            'separator': separator,
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
