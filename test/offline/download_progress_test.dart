import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/offline/data/download_progress.dart';

void main() {
  test('byte progress is bounded/throttled, verified parts restore and stale account/job callbacks are ignored', () async {
    final progress = DownloadProgress();
    addTearDown(progress.close);
    final values = <double?>[];
    final subscription = progress.watch('job').listen(values.add);
    addTearDown(subscription.cancel);
    progress.begin('job', 4, [0]);
    await Future<void>.delayed(Duration.zero);
    expect(values.last, .25);
    final before = values.length;
    for (var i = 1; i <= 1000; i++) {
      progress.received('job', 1, i, 1000);
    }
    await Future<void>.delayed(Duration.zero);
    expect(values.length - before, lessThanOrEqualTo(1));
    progress.verified('job', 1);
    await Future<void>.delayed(Duration.zero);
    expect(values.last, .5);
    progress.begin('other', 1, []);
    final count = values.length;
    progress.received('job', 2, 1000, 1000);
    progress.verified('job', 2);
    await Future<void>.delayed(Duration.zero);
    expect(values, hasLength(count));
    progress.begin('job', 1, []);
    await Future<void>.delayed(const Duration(milliseconds: 210));
    progress.received('job', 0, 50, 100);
    await Future<void>.delayed(Duration.zero);
    expect(values.last, closeTo(.49, .001));
    progress.verified('job', 0);
    await Future<void>.delayed(Duration.zero);
    expect(values.last, 1);
  });
}
