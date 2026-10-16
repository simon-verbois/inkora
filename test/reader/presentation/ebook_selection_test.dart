import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/reader/presentation/ebook_selection.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('inkora/ebook_selection');
  final calls = <MethodCall>[];
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return true;
        });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  test(
    'Android cleanup sends one fixed command without document/user data',
    () async {
      await clearEbookSelection();
      expect(calls, hasLength(1));
      expect(calls.single.method, 'clear');
      expect(calls.single.arguments, isNull);
    },
  );
  test('other platforms keep the engine selection behavior', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await clearEbookSelection();
    expect(calls, isEmpty);
  });
  test(
    'unavailable native cleanup cannot reject bookmark persistence',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (_) async => throw PlatformException(code: 'closed'),
          );
      await expectLater(clearEbookSelection(), completes);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      await expectLater(clearEbookSelection(), completes);
    },
  );
}
