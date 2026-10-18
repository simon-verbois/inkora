import 'support/ui_fixture_binding.dart';

import '../test/app/app_chrome_test.dart' as chrome;
import '../test/app/predictive_back_widget_test.dart' as predictive;
import '../test/features/settings/setup_wrapper_widget_test.dart' as setup;

void main() {
  UiFixtureIntegrationBinding();
  chrome.main();
  predictive.main();
  setup.main();
}
