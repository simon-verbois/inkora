import 'support/ui_fixture_binding.dart';
import 'support/reader_settings_capture.dart';
import '../test/reader/presentation/reader_settings_tabs_test.dart' as tabs;
import '../test/reader/presentation/webtoon_quality_sheet_test.dart' as webtoon;
import '../test/reader/presentation/quality_scope_widget_test.dart' as reset;
import '../test/app/predictive_back_widget_test.dart' as predictive;

void main() {
  UiFixtureIntegrationBinding();
  tabs.main();
  webtoon.main();
  reset.main();
  predictive.main();
  registerSettingsCaptures();
}
