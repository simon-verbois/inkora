import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/features/connection/data/development_login.dart';
import 'package:inkora/features/connection/domain/session.dart';

void main() {
  late Directory directory;
  late File file;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('inkora-development-');
    file = File('${directory.path}/development-login.json');
  });
  tearDown(() => directory.delete(recursive: true));

  test('takes Basic credentials once and deletes the transient file', () async {
    await file.writeAsString(
      '{"url":"https://example.test/komga","username":"reader","password":"fixture"}',
    );
    final login = await takeDevelopmentLogin(file);
    expect(login!.serverUrl, 'https://example.test/komga/');
    expect(login.credentials.method, AuthenticationMethod.basic);
    expect(login.credentials.username, 'reader');
    expect(await file.exists(), isFalse);
    expect(await takeDevelopmentLogin(file), isNull);
  });

  test('takes API key credentials', () async {
    await file.writeAsString(
      '{"url":"https://example.test","apiKey":"fixture"}',
    );
    final login = await takeDevelopmentLogin(file);
    expect(login!.credentials.method, AuthenticationMethod.apiKey);
    expect(await file.exists(), isFalse);
  });

  test(
    'malformed, incomplete and non-HTTPS files are consumed safely',
    () async {
      for (final encoded in [
        'invalid JSON',
        '{}',
        '{"url":"http://example.test","apiKey":"fixture"}',
      ]) {
        await file.writeAsString(encoded);
        expect(await takeDevelopmentLogin(file), isNull);
        expect(await file.exists(), isFalse);
      }
    },
  );
}
