import 'package:flutter/services.dart';

/// Native adapters stage files only. Dart revalidates account/revision/length/hash
/// before publication. URLSession/JobScheduler own execution while suspended.
final class BackgroundTransfer {
  static const channel = MethodChannel('inkora/download_background');
  Future<void> foreground() async {
    try {
      await channel.invokeMethod<void>('foreground');
    } on MissingPluginException {
      /* Host tests have no native scheduler. */
    }
  }

  Future<void> enqueue(
    List<Map<String, Object?>> tasks, {
    required Map<String, String> headers,
    required bool wifiOnly,
  }) async {
    if (tasks.isEmpty) return;
    await channel.invokeMethod<void>('enqueue', {
      'tasks': tasks,
      'headers': headers,
      'wifiOnly': wifiOnly,
    });
  }

  Future<List<Map<String, dynamic>>> results() async {
    try {
      final rows = await channel.invokeListMethod<Object?>('results') ?? [];
      return rows.map((r) => Map<String, dynamic>.from(r as Map)).toList();
    } on MissingPluginException {
      return [];
    }
  }

  Future<List<String>> accounts() async {
    try {
      return await channel.invokeListMethod<String>('accounts') ?? [];
    } on MissingPluginException {
      return [];
    }
  }

  Future<void> excludeFromBackup(List<String> paths) async {
    try {
      await channel.invokeMethod<void>('excludeFromBackup', paths);
    } on MissingPluginException {
      /* Host test. */
    }
  }

  Future<void> acknowledge(String id) async {
    await channel.invokeMethod<void>('acknowledge', id);
  }

  Future<void> cancelAccount(String account) async {
    try {
      await channel.invokeMethod<void>('cancelAccount', account);
    } on MissingPluginException {
      /* Host test. */
    }
  }
}
