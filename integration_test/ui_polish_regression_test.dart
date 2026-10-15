import 'support/ui_fixture_binding.dart';
import '../test/app/ui_test.dart' as ui;
import '../test/app/transition_surface_widget_test.dart' as transitions;

void main() {
  UiFixtureIntegrationBinding();
  ui.registerCatalogueRetentionTest();
  transitions.main();
}
