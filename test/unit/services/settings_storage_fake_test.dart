import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes/fake_settings_storage.dart';

void main() {
  test('reads and writes through the in-memory box without Hive', () async {
    final storage = FakeSettingsStorage(initialValues: {'existing': 1});

    expect(storage.isUnlocked, isTrue);
    expect(storage.box.get('existing'), 1);
    expect(storage.box.get('missing', defaultValue: 'fallback'), 'fallback');

    await storage.box.put('new', 2);
    expect(storage.box.get('new'), 2);
    expect(storage.values['new'], 2);
  });

  test('reports PIN and biometric metadata from the fake', () async {
    final storage = FakeSettingsStorage(
      pinEnabled: true,
      pinDigits: 6,
      biometricsSupported: true,
    );

    expect(await storage.hasPin(), isTrue);
    expect(storage.pinLength, 6);
    expect(await storage.supportsBiometrics(), isTrue);
  });

  test('a locked fake storage throws the same error as the real accessor', () {
    final storage = FakeSettingsStorage(unlocked: false);

    expect(storage.isUnlocked, isFalse);
    expect(() => storage.box, throwsStateError);
  });

  test('reports a configured storage error', () {
    final failing = FakeSettingsStorage(storageError: 'keyring unavailable');
    final healthy = FakeSettingsStorage();

    expect(failing.hasStorageError, isTrue);
    expect(failing.storageError, 'keyring unavailable');
    expect(healthy.hasStorageError, isFalse);
    expect(healthy.storageError, isNull);
  });
}
