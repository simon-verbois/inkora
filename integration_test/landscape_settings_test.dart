import 'support/ui_fixture_binding.dart';

import '../test/features/settings/landscape_settings_widget_test.dart'
    as landscape;
import '../test/features/settings/setup_wrapper_widget_test.dart' as setup;
import '../test/app/predictive_back_widget_test.dart' as predictive;

void main() {
  UiFixtureIntegrationBinding();
  if (!const bool.fromEnvironment('LANDSCAPE_SETUP_ONLY')) landscape.main();
  setup.main();
  if (!const bool.fromEnvironment('LANDSCAPE_SETUP_ONLY')) predictive.main();
}
