import 'support/ui_fixture_binding.dart';
import '../test/features/library/resume_carousel_test.dart' as resume;
import '../test/app/predictive_back_widget_test.dart' as predictive;
import '../test/features/library/ebook_titles_widget_test.dart' as ebooks;

void main() {
  UiFixtureIntegrationBinding();
  resume.main();
  predictive.main();
  ebooks.main();
}
