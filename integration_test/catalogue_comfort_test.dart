import 'support/ui_fixture_binding.dart';
import '../test/features/library/catalogue_filters_widget_test.dart' as filters;
import '../test/features/settings/comfort_controls_widget_test.dart' as comfort;
import '../test/features/settings/setup_wrapper_widget_test.dart' as setup;
import '../test/offline/offline_widget_test.dart' as downloads;
import '../test/reader/presentation/ebook_settings_test.dart' as ebooks;

void main() {
  UiFixtureIntegrationBinding();
  filters.main();
  comfort.main();
  setup.main();
  downloads.main();
  ebooks.main();
}
