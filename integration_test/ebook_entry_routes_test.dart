import 'support/ui_fixture_binding.dart';
import '../test/features/library/ebook_titles_widget_test.dart' as ebooks;
import '../test/features/library/catalogue_detail_widget_test.dart' as details;
import '../test/app/predictive_back_widget_test.dart' as predictive;

void main() {
  UiFixtureIntegrationBinding();
  details.main();
  predictive.main();
  ebooks.main();
}
