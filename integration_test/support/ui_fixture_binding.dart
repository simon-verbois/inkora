import 'package:integration_test/integration_test.dart';

/// Reused widget fixtures inject editing values through TestTextInput. Keep the
/// real Android IME from sending its stale value back over that injected text.
/// Native keyboard/autofill verification uses the normal integration binding.
class UiFixtureIntegrationBinding extends IntegrationTestWidgetsFlutterBinding {
  @override
  bool get registerTestTextInput => true;
}
