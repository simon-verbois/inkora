import 'dart:convert';
import 'dart:io';

import 'package:inkora/features/settings/data/settings_transfer.dart';

/// Recreates the retired portable QR format to verify legacy import support.
Future<String> legacySettingsQr(SettingsTransfer transfer) async {
  final backup = await transfer.inspect(await transfer.export());
  final portable = {
    ...backup,
    'portable': true,
    'preferences': [
      for (final preference in backup['preferences'] as List)
        if (preference['scope'] == 'global') preference,
    ],
    'bookmarks': <Object>[],
  }..remove('account');
  return '${SettingsTransfer.qrPrefix}${base64Url.encode(gzip.encode(utf8.encode(jsonEncode(portable))))}';
}
