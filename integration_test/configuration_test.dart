import '../test/app/predictive_back_widget_test.dart' as predictive;

import 'package:integration_test/integration_test.dart';

import '../test/features/settings/configuration_widget_test.dart'
    as configuration;
import '../test/features/settings/localization_widget_test.dart'
    as localization;
import '../test/features/settings/setup_wrapper_widget_test.dart' as setup;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Synthetic lifecycle transitions are host-only; live engines own frame delivery.
  configuration.main(includeLifecycle: false);
  localization.main();
  setup.main();
  predictive.main();
}
