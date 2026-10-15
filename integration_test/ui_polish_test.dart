import 'support/ui_fixture_binding.dart';

import '../test/app/ui_test.dart' as ui;
import '../test/app/transition_surface_widget_test.dart' as transitions;
import '../test/app/overlay_surface_widget_test.dart' as overlays;
import '../test/app/predictive_back_widget_test.dart' as predictive;
import '../test/features/settings/localization_widget_test.dart'
    as localization;
import '../test/features/settings/setup_wrapper_widget_test.dart' as setup;

void main() {
  UiFixtureIntegrationBinding();
  ui.main();
  transitions.main();
  overlays.main();
  predictive.main();
  localization.main();
  setup.main();
}
