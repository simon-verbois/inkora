import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const _channel = MethodChannel('inkora/ebook_selection');

/// Android's custom selection action ends the menu but retains the word range.
/// Cleanup is optional UI work and must never prevent durable bookmark saving.
Future<void> clearEbookSelection() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  try {
    await _channel.invokeMethod<bool>('clear');
  } on MissingPluginException {
    // Host fixtures and an engine being torn down have no native reader.
  } on PlatformException {
    // Closing a publication can race this transient cleanup.
  }
}
