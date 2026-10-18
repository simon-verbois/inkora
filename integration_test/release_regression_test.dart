import 'support/ui_fixture_binding.dart';
import '../test/app/reader_shortcut_shell_test.dart' as shortcut;
import '../test/app/slow_download_navigation_test.dart' as download;
import '../test/features/settings/cold_setup_widget_test.dart' as setup;

void main() {
  UiFixtureIntegrationBinding();
  shortcut.main();
  setup.main();
  download.main();
}
