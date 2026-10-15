import 'support/ui_fixture_binding.dart';
import '../test/features/settings/quality_settings_widget_test.dart' as quality;
import '../test/features/settings/appearance_layout_widget_test.dart'
    as appearance;
import '../test/reader/presentation/quality_scope_widget_test.dart' as scope;
import '../test/reader/presentation/image_quality_widget_test.dart'
    as rendering;
import '../test/app/predictive_back_widget_test.dart' as predictive;
import '../test/app/transition_surface_widget_test.dart' as transitions;
import '../test/features/settings/setup_wrapper_widget_test.dart' as setup;

void main() {
  UiFixtureIntegrationBinding();
  quality.main();
  appearance.main();
  scope.main();
  rendering.main();
  predictive.main();
  transitions.main();
  setup.main();
}
