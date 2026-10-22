import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket2fa/services/log_service.dart';
import 'package:pocket2fa/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes/fake_settings_storage.dart';
import '../../helpers/reset.dart';

Future<SettingsService> _serviceFromStorage({
  Map<dynamic, dynamic>? values,
  bool unlocked = true,
  bool pin = false,
  int? pinDigits,
  bool biometrics = false,
  String? storageError,
}) async {
  final service = SettingsService(
    storage: FakeSettingsStorage(
      initialValues: values,
      unlocked: unlocked,
      pinEnabled: pin,
      pinDigits: pinDigits,
      biometricsSupported: biometrics,
      storageError: storageError,
    ),
  );
  await service.reloadFromStorage();
  return service;
}

Future<SettingsService> _serviceFromPrefs() async {
  final service = SettingsService();
  await service.reloadFromStorage();
  return service;
}

FakeSettingsStorage _fakeStorage(SettingsService service) =>
    service.storage! as FakeSettingsStorage;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    resetLogService();
  });

  tearDown(resetLogService);

  group('loading from unlocked storage', () {
    test('restores every persisted value and the PIN metadata', () async {
      final service = await _serviceFromStorage(
        values: {
          'otp_format': 'spaced2',
          'otp_format_enabled': false,
          'biometric_protection_enabled': true,
          'hide_otps_enabled': true,
          'sync_on_home_open': false,
          'auto_sync_enabled': true,
          'auto_sync_interval_minutes': 45,
          'debug_logging_enabled': true,
          'theme_mode': 'dark',
        },
        pin: true,
        pinDigits: 6,
        biometrics: true,
      );

      expect(service.format, CodeFormat.spaced2);
      expect(service.enabled, isFalse);
      expect(service.biometricEnabled, isTrue);
      expect(service.hideOtps, isTrue);
      expect(service.syncOnOpen, isFalse);
      expect(service.autoSyncEnabled, isTrue);
      expect(service.autoSyncIntervalMinutes, 45);
      expect(service.debugLoggingEnabled, isTrue);
      expect(service.themeMode, ThemeMode.dark);
      expect(service.pinEnabled, isTrue);
      expect(service.pinLength, 6);
      expect(service.biometricsSupported, isTrue);
      expect(LogService.instance.enabled, isTrue);
    });

    test('uses the compiled defaults for an empty box', () async {
      final service = await _serviceFromStorage();

      expect(service.format, CodeFormat.spaced3);
      expect(service.enabled, isTrue);
      expect(service.hideOtps, isFalse);
      expect(service.syncOnOpen, isTrue);
      expect(service.autoSyncEnabled, isFalse);
      expect(service.autoSyncIntervalMinutes, 30);
      expect(service.debugLoggingEnabled, isFalse);
      expect(service.themeMode, ThemeMode.system);
      expect(service.pinEnabled, isFalse);
      expect(service.pinLength, isNull);
      expect(LogService.instance.enabled, isFalse);
    });

    test('notifies listeners after reloading', () async {
      final service = await _serviceFromStorage();
      var notifications = 0;
      service.addListener(() => notifications++);

      await service.reloadFromStorage();

      expect(notifications, greaterThan(0));
    });
  });

  group('theme migration', () {
    test('a stored theme_mode wins over the legacy dark flag', () async {
      final service = await _serviceFromStorage(
        values: {'theme_mode': 'light', 'dark_mode_enabled': true},
      );

      expect(service.themeMode, ThemeMode.light);
    });

    test(
      'the legacy dark flag maps to dark when theme_mode is absent',
      () async {
        final service = await _serviceFromStorage(
          values: {'dark_mode_enabled': true},
        );

        expect(service.themeMode, ThemeMode.dark);
      },
    );

    test('an empty box maps to the system theme', () async {
      final service = await _serviceFromStorage();

      expect(service.themeMode, ThemeMode.system);
    });

    test('the SharedPreferences path follows the same migration', () async {
      SharedPreferences.setMockInitialValues({
        'theme_mode': 'light',
        'dark_mode_enabled': true,
      });
      expect((await _serviceFromPrefs()).themeMode, ThemeMode.light);

      SharedPreferences.setMockInitialValues({'dark_mode_enabled': true});
      expect((await _serviceFromPrefs()).themeMode, ThemeMode.dark);

      SharedPreferences.setMockInitialValues({});
      expect((await _serviceFromPrefs()).themeMode, ThemeMode.system);
    });
  });

  group('loading from locked storage', () {
    test(
      'keeps defaults, reads PIN metadata and never opens the box',
      () async {
        final service = await _serviceFromStorage(
          values: {'otp_format': 'compact'},
          unlocked: false,
          pin: true,
          pinDigits: 4,
        );

        expect(service.format, CodeFormat.spaced3);
        expect(service.enabled, isTrue);
        expect(service.hideOtps, isFalse);
        expect(service.syncOnOpen, isTrue);
        expect(service.autoSyncEnabled, isFalse);
        expect(service.autoSyncIntervalMinutes, 30);
        expect(service.themeMode, ThemeMode.system);
        expect(service.pinEnabled, isTrue);
        expect(service.pinLength, 4);
        expect(service.debugLoggingEnabled, isFalse);
        expect(LogService.instance.enabled, isFalse);
      },
    );

    test('force-enables debug logging when secure storage failed', () async {
      final service = await _serviceFromStorage(
        unlocked: false,
        storageError: 'keyring unavailable',
      );

      expect(service.debugLoggingEnabled, isTrue);
      expect(LogService.instance.enabled, isTrue);
    });
  });

  group('writes to unlocked storage', () {
    test('persists every setting and notifies listeners', () async {
      final service = await _serviceFromStorage();
      final storage = _fakeStorage(service);
      var notifications = 0;
      service.addListener(() => notifications++);

      await service.setFormat(CodeFormat.compact);
      expect(service.format, CodeFormat.compact);
      expect(storage.values['otp_format'], 'compact');

      await service.setEnabled(false);
      expect(service.enabled, isFalse);
      expect(storage.values['otp_format_enabled'], isFalse);

      await service.setHideOtps(true);
      expect(service.hideOtps, isTrue);
      expect(storage.values['hide_otps_enabled'], isTrue);

      await service.setSyncOnOpen(false);
      expect(service.syncOnOpen, isFalse);
      expect(storage.values['sync_on_home_open'], isFalse);

      await service.setAutoSyncEnabled(true);
      expect(service.autoSyncEnabled, isTrue);
      expect(storage.values['auto_sync_enabled'], isTrue);

      await service.setAutoSyncIntervalMinutes(45);
      expect(service.autoSyncIntervalMinutes, 45);
      expect(storage.values['auto_sync_interval_minutes'], 45);

      await service.setThemeMode(ThemeMode.dark);
      expect(service.themeMode, ThemeMode.dark);
      expect(storage.values['theme_mode'], 'dark');

      await service.setDebugLoggingEnabled(true);
      expect(service.debugLoggingEnabled, isTrue);
      expect(storage.values['debug_logging_enabled'], isTrue);
      expect(LogService.instance.enabled, isTrue);

      LogService.instance.info('captured before disabling');
      expect(LogService.instance.entries, hasLength(1));

      await service.setDebugLoggingEnabled(false);
      expect(service.debugLoggingEnabled, isFalse);
      expect(storage.values['debug_logging_enabled'], isFalse);
      expect(LogService.instance.enabled, isFalse);
      expect(LogService.instance.entries, isEmpty);

      expect(notifications, 9);
    });

    test('updates memory without writing while storage is locked', () async {
      final service = await _serviceFromStorage(unlocked: false);
      final storage = _fakeStorage(service);
      var notifications = 0;
      service.addListener(() => notifications++);

      await service.setFormat(CodeFormat.compact);

      expect(service.format, CodeFormat.compact);
      expect(storage.values, isNot(contains('otp_format')));
      expect(notifications, 1);
    });
  });

  group('SharedPreferences fallback', () {
    test('persists every setting and notifies listeners', () async {
      final service = await _serviceFromPrefs();
      final prefs = await SharedPreferences.getInstance();
      var notifications = 0;
      service.addListener(() => notifications++);

      await service.setFormat(CodeFormat.spaced2);
      expect(prefs.getString('otp_format'), 'spaced2');

      await service.setEnabled(false);
      expect(prefs.getBool('otp_format_enabled'), isFalse);

      await service.setHideOtps(true);
      expect(prefs.getBool('hide_otps_enabled'), isTrue);

      await service.setSyncOnOpen(false);
      expect(prefs.getBool('sync_on_home_open'), isFalse);

      await service.setAutoSyncEnabled(true);
      expect(prefs.getBool('auto_sync_enabled'), isTrue);

      await service.setAutoSyncIntervalMinutes(45);
      expect(prefs.getInt('auto_sync_interval_minutes'), 45);

      await service.setThemeMode(ThemeMode.dark);
      expect(prefs.getString('theme_mode'), 'dark');

      await service.setDebugLoggingEnabled(true);
      expect(prefs.getBool('debug_logging_enabled'), isTrue);
      expect(LogService.instance.enabled, isTrue);

      LogService.instance.info('captured before disabling');
      await service.setDebugLoggingEnabled(false);
      expect(prefs.getBool('debug_logging_enabled'), isFalse);
      expect(LogService.instance.enabled, isFalse);
      expect(LogService.instance.entries, isEmpty);

      expect(notifications, 9);
    });

    test('loads persisted values and defaults', () async {
      SharedPreferences.setMockInitialValues({
        'otp_format': 'spaced2',
        'otp_format_enabled': false,
        'debug_logging_enabled': true,
      });

      final service = await _serviceFromPrefs();

      expect(service.format, CodeFormat.spaced2);
      expect(service.enabled, isFalse);
      expect(service.debugLoggingEnabled, isTrue);
      expect(service.hideOtps, isFalse);
      expect(service.syncOnOpen, isTrue);
      expect(service.autoSyncIntervalMinutes, 30);
    });

    test('an unknown format falls back to compact', () async {
      SharedPreferences.setMockInitialValues({'otp_format': 'unknown'});

      final service = await _serviceFromPrefs();

      expect(service.format, CodeFormat.compact);
    });

    test('ignores a non-positive auto-sync interval', () async {
      final service = await _serviceFromPrefs();
      final prefs = await SharedPreferences.getInstance();
      var notifications = 0;
      service.addListener(() => notifications++);

      await service.setAutoSyncIntervalMinutes(0);
      await service.setAutoSyncIntervalMinutes(-5);

      expect(service.autoSyncIntervalMinutes, 30);
      expect(prefs.getInt('auto_sync_interval_minutes'), isNull);
      expect(notifications, 0);
    });
  });

  group('guards without storage', () {
    test('PIN and biometric operations fail safely', () async {
      final service = await _serviceFromPrefs();

      expect(await service.setBiometricEnabled(true), isFalse);
      expect(await service.enablePin('1234'), isFalse);
      expect(await service.changePin('1234', '5678'), isFalse);
      expect(await service.disablePin('1234'), isFalse);
      expect(
        await service.verifyCurrentFactorWithBiometrics(reason: 'unlock'),
        isFalse,
      );
    });
  });
}
