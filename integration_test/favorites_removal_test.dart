import 'package:integration_test/integration_test.dart';

import '../test/features/library/favorites_removal_migration_test.dart'
    as migration;
import '../test/features/library/favorites_removal_widget_test.dart'
    as navigation;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  migration.main();
  navigation.main();
}
