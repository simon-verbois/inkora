import 'package:integration_test/integration_test.dart';

import '../test/reader/presentation/webtoon_readiness_test.dart' as readiness;
import '../test/reader/presentation/webtoon_decode_admission_test.dart'
    as admission;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  readiness.main();
  admission.main();
}
