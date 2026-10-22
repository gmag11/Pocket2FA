import 'package:pocket2fa/services/log_service.dart';
import 'package:pocket2fa/services/settings_service.dart';

import 'fakes/fake_settings_storage.dart';

/// Clears every piece of mutable state a test can leave behind in the log
/// service singleton.
void resetLogService() {
  LogService.instance
    ..clear()
    ..enabled = false
    ..forceCapture = false;
}

/// Replaces [SettingsService.instance] with a fresh service backed by an
/// in-memory storage, and waits for its initial load to finish.
Future<SettingsService> resetSettingsService({
  Map<dynamic, dynamic>? initialValues,
}) async {
  final service = SettingsService(
    storage: FakeSettingsStorage(initialValues: initialValues),
  );
  await service.reloadFromStorage();
  return service;
}
