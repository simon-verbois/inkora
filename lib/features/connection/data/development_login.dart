import 'dart:convert';
import 'dart:io';

import '../../../core/network/server_endpoint.dart';
import '../domain/session.dart';

/// Takes a one-use file from the debug application's private files directory.
/// Call only from the development entry point; never log the file or its errors.
Future<StartupLogin?> takeDevelopmentLogin(File file) async {
  try {
    if (!await file.exists()) return null;
    final encoded = await file.readAsString();
    await file.delete();
    final json = jsonDecode(encoded);
    if (json is! Map<String, dynamic>) return null;
    final url = json['url'];
    if (url is! String) return null;
    final endpoint = ServerEndpoint(url);
    final key = json['apiKey'];
    if (key is String) {
      return StartupLogin(endpoint.uri.toString(), Credentials.apiKey(key));
    }
    final username = json['username'];
    final password = json['password'];
    if (username is! String || password is! String) return null;
    return StartupLogin(
      endpoint.uri.toString(),
      Credentials.basic(username, password),
    );
  } catch (_) {
    // Malformed/unreadable local configuration leaves the normal login usable.
    return null;
  }
}
