// Unit tests for the secure-storage dead-end fix (GitHub issue #20).
//
// NOTE: these tests are intentionally NOT wired into the build yet, mirroring
// test/shared_account_otp_test.dart. Running them requires adding `flutter_test`
// (sdk: flutter) to `dev_dependencies` in pubspec.yaml, which is deliberately
// out of scope for this change.
//
// Run once the dependency exists with:
//   flutter test test/secure_storage_dead_end_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:pocket2fa/l10n/app_localizations_en.dart';
import 'package:pocket2fa/l10n/app_localizations_es.dart';
import 'package:pocket2fa/l10n/app_localizations_fr.dart';
import 'package:pocket2fa/services/settings_storage.dart';

void main() {
  group('classifyStorageLock', () {
    test('a storage failure is never reported as biometric', () {
      // The Linux scenario from the issue: the keyring read failed while
      // biometrics are not even available.
      final reason = classifyStorageLock(
        hasStorageError: true,
        isBiometricLocked: false,
        biometricsSupported: false,
      );

      expect(reason, StorageLockReason.storageFailure);
      expect(reason, isNot(StorageLockReason.biometricPrompt));
    });

    test('a storage failure wins even when biometrics are supported', () {
      final reason = classifyStorageLock(
        hasStorageError: true,
        isBiometricLocked: true,
        biometricsSupported: true,
      );

      expect(reason, StorageLockReason.storageFailure);
    });

    test('a pending biometric prompt on an unsupported platform', () {
      final reason = classifyStorageLock(
        hasStorageError: false,
        isBiometricLocked: true,
        biometricsSupported: false,
      );

      expect(reason, StorageLockReason.biometricUnavailable);
      expect(reason, isNot(StorageLockReason.biometricPrompt));
    });

    test('a pending biometric prompt on a supported platform', () {
      final reason = classifyStorageLock(
        hasStorageError: false,
        isBiometricLocked: true,
        biometricsSupported: true,
      );

      expect(reason, StorageLockReason.biometricPrompt);
    });
  });

  group('SettingsStorage lock state', () {
    test('a fresh instance is locked but has no recorded error', () {
      final storage = SettingsStorage();

      expect(storage.isUnlocked, isFalse);
      expect(storage.isBiometricLocked, isFalse);
      expect(storage.hasStorageError, isFalse);
      expect(storage.storageError, isNull);
    });

    test('accessing the box while locked throws a clear StateError', () {
      final storage = SettingsStorage();

      expect(() => storage.box, throwsA(isA<StateError>()));
    });
  });

  group('locked-screen messages', () {
    test('the storage message exists in every shipped locale', () {
      expect(AppLocalizationsEn().storageUnlockFailed, isNotEmpty);
      expect(AppLocalizationsEs().storageUnlockFailed, isNotEmpty);
      expect(AppLocalizationsFr().storageUnlockFailed, isNotEmpty);
    });

    test('the storage message is distinct from the biometric message', () {
      final en = AppLocalizationsEn();

      expect(en.storageUnlockFailed, isNot(en.biometricAuthFailed));
      expect(en.storageUnlockFailed.toLowerCase(), contains('secure storage'));
    });
  });
}
