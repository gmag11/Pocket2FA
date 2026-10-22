import 'package:flutter_test/flutter_test.dart';
import 'package:pocket2fa/services/log_service.dart';
import 'package:pocket2fa/services/settings_service.dart';

import '../helpers/reset.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('resetLogService clears entries between cases', () {
    LogService.instance.enabled = true;
    LogService.instance.log('first case');
    expect(LogService.instance.entries, hasLength(1));

    resetLogService();

    expect(LogService.instance.entries, isEmpty);
    expect(LogService.instance.capturing, isFalse);
  });

  test('resetSettingsService restores defaults after a change', () async {
    final changed = await resetSettingsService();
    await changed.setFormat(CodeFormat.compact);
    expect(SettingsService.instance.format, CodeFormat.compact);

    final fresh = await resetSettingsService();

    expect(fresh.format, CodeFormat.spaced3);
    expect(SettingsService.instance.format, CodeFormat.spaced3);
  });
}
