import 'package:flutter_test/flutter_test.dart';
import 'package:pocket2fa/services/log_service.dart';

import '../../helpers/clock.dart';

void main() {
  // LogService schedules its notifier through SchedulerBinding, so the
  // framework services need a test binding. This is not a platform channel.
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    LogService.instance.clear();
    LogService.instance.enabled = true;
  });

  tearDown(() {
    LogService.instance.clear();
    LogService.instance.enabled = false;
  });

  test('captured log entries use the fixed clock', () {
    final fixed = DateTime.utc(2026, 10, 21, 12, 0, 0);

    withFixedTime(fixed, () {
      LogService.instance.log('deterministic timestamp');
    });

    expect(LogService.instance.entries, hasLength(1));
    expect(LogService.instance.entries.single.timestamp, fixed);
  });

  test('logging is a no-op when capture is disabled', () {
    LogService.instance.enabled = false;
    LogService.instance.forceCapture = false;

    LogService.instance.log('dropped');

    expect(LogService.instance.entries, isEmpty);
  });
}
