import 'support/ui_fixture_binding.dart';

import '../test/reader/presentation/ebook_settings_test.dart' as margins;
import '../test/features/settings/setup_wrapper_widget_test.dart' as setup;
import '../test/features/library/catalogue_detail_widget_test.dart' as series;
import '../test/app/predictive_back_widget_test.dart' as predictive;

void main() {
  UiFixtureIntegrationBinding();
  margins.main();
  setup.main();
  series.main();
  predictive.main();
}
