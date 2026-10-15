import 'package:integration_test/integration_test.dart';

import '../test/reader/presentation/paged_profiles_test.dart' as profiles;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  profiles.main();
}
