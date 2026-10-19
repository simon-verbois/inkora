import 'support/ui_fixture_binding.dart';

import '../test/features/settings/system_themes_widget_test.dart' as system;
import '../test/features/settings/appearance_layout_widget_test.dart'
    as palettes;

void main() {
  UiFixtureIntegrationBinding();
  system.main();
  palettes.main();
}
