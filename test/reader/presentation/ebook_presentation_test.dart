import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/reader/presentation/ebook_presentation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <MethodCall>[];
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(EbookPresentation.channel, (call) async {
          calls.add(call);
          return true;
        });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(EbookPresentation.channel, null);
  });
  test(
    'presentation and page turns carry only fixed boolean arguments',
    () async {
      expect(
        await EbookPresentation.configure(animations: false, separator: true),
        isTrue,
      );
      expect(await EbookPresentation.turn(1, animated: false), isTrue);
      expect(await EbookPresentation.turn(-1, animated: true), isTrue);
      expect(calls.map((call) => call.method), ['configure', 'turn', 'turn']);
      expect(calls[0].arguments, {'animations': false, 'separator': true});
      expect(calls[1].arguments, {'forward': true, 'animated': false});
      expect(calls[2].arguments, {'forward': false, 'animated': true});
    },
  );
  test('unsupported platforms do not receive a native command', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(
      await EbookPresentation.configure(animations: true, separator: false),
      isFalse,
    );
    expect(await EbookPresentation.turn(1, animated: true), isFalse);
    expect(calls, isEmpty);
  });
  test('missing bridge keeps existing engine navigation available', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(EbookPresentation.channel, null);
    expect(await EbookPresentation.turn(1, animated: false), isFalse);
    expect(
      await EbookPresentation.configure(animations: false, separator: false),
      isFalse,
    );
  });
}
