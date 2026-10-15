import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:inkora/reader/application/reader_network_policy.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android native metering and Data Saver policy is readable', (
    tester,
  ) async {
    final native = await ReaderNetworkPolicy.channel
        .invokeMapMethod<String, bool>('current');
    expect(native, containsPair('metered', isA<bool>()));
    expect(native, containsPair('dataSaver', isA<bool>()));
    final policy = await ReaderNetworkPolicy.current();
    expect(policy.constrained, native!['metered']);
    expect(policy.paused, native['dataSaver']);
  });
}
