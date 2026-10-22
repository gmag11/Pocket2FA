import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pocket2fa/services/settings_storage.dart';

const _pathChannel = MethodChannel('plugins.flutter.io/path_provider');
const _localAuthChannel = MethodChannel('plugins.flutter.io/local_auth');

class _ThrowingMap extends MapBase<String, String> {
  final Map<String, String> _inner = {};

  @override
  String? operator [](Object? key) => throw PlatformException(
    code: 'keyring-unavailable',
    message: 'keyring unavailable',
  );

  @override
  void operator []=(String key, String value) => _inner[key] = value;

  @override
  void clear() => _inner.clear();

  @override
  Iterable<String> get keys => _inner.keys;

  @override
  String? remove(Object? key) => _inner.remove(key);

  @override
  int get length => _inner.length;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory tempDir;
  late Map<String, String> secure;
  var biometricsAvailable = true;
  var authResult = true;

  setUp(() async {
    await Hive.close();
    tempDir = Directory.systemTemp.createTempSync('pocket2fa_storage_');
    secure = {};
    FlutterSecureStorage.setMockInitialValues(secure);
    biometricsAvailable = true;
    authResult = true;

    messenger.setMockMethodCallHandler(_pathChannel, (call) async {
      return tempDir.path;
    });
    messenger.setMockMethodCallHandler(_localAuthChannel, (call) async {
      switch (call.method) {
        case 'getAvailableBiometrics':
          return biometricsAvailable ? ['fingerprint'] : [];
        case 'isDeviceSupported':
          return biometricsAvailable;
        case 'authenticate':
          return authResult;
        default:
          return null;
      }
    });
  });

  tearDown(() async {
    await Hive.close();
    messenger.setMockMethodCallHandler(_pathChannel, null);
    messenger.setMockMethodCallHandler(_localAuthChannel, null);
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('initializes, generates a key and opens the encrypted box', () async {
    final storage = SettingsStorage();
    await storage.init();

    expect(storage.isUnlocked, isTrue);
    expect(storage.hasStorageError, isFalse);
    expect(secure['hive_master_key'], isNotEmpty);

    final key = await storage.readKey();
    expect(key, hasLength(32));

    await storage.box.put('answer', 42);
    expect(storage.box.get('answer'), 42);
    expect(await storage.readKey(requireAuth: true), key);
  });

  test('reuses an existing secure key', () async {
    final key = List<int>.generate(32, (index) => index);
    secure['hive_master_key'] = base64Encode(key);

    final storage = SettingsStorage();
    await storage.init();

    expect(storage.isUnlocked, isTrue);
    expect(await storage.readKey(), key);
  });

  test('reports locked access before init and opens on retry', () async {
    final failing = SettingsStorage();

    expect(failing.isUnlocked, isFalse);
    expect(failing.isBiometricLocked, isFalse);
    expect(() => failing.box, throwsStateError);

    await failing.init();
    expect(failing.isUnlocked, isTrue);
    expect(failing.hasStorageError, isFalse);
  });

  test('records a secure-storage failure and retries', () async {
    FlutterSecureStorage.setMockInitialValues(_ThrowingMap());
    final storage = SettingsStorage();

    await storage.init();
    expect(storage.isUnlocked, isFalse);
    expect(storage.hasStorageError, isTrue);
    expect(storage.storageError, contains('keyring'));

    FlutterSecureStorage.setMockInitialValues(secure);
    expect(await storage.attemptUnlock(), isTrue);
    expect(storage.isUnlocked, isTrue);
    expect(storage.hasStorageError, isFalse);
  });

  test('sets, verifies and clears a PIN', () async {
    final storage = SettingsStorage();
    await storage.init();

    expect(await storage.hasPin(), isFalse);
    expect(await storage.setPin('12'), isFalse);
    expect(await storage.setPin('1234'), isTrue);
    expect(storage.isPinEnabled, isTrue);
    expect(storage.pinLength, 4);
    expect(await storage.verifyPin('1234'), isTrue);
    expect(await storage.verifyPin('4321'), isFalse);
    expect(await storage.hasPin(), isTrue);

    expect(await storage.clearPin(), isTrue);
    expect(storage.isPinEnabled, isFalse);
    expect(storage.pinLength, isNull);
    expect(await storage.hasPin(), isFalse);
  });

  test(
    'locks a PIN-protected store and verifies the PIN to reopen it',
    () async {
      final first = SettingsStorage();
      await first.init();
      await first.setPin('1234');
      final key = secure['hive_master_key'];
      await Hive.close();

      final locked = SettingsStorage();
      await locked.init();
      expect(locked.isUnlocked, isFalse);
      expect(locked.isPinLocked, isTrue);
      expect(locked.isPinEnabled, isTrue);

      expect(await locked.unlockWithPin('0000'), isFalse);
      expect(await locked.unlockWithPin('1234'), isTrue);
      expect(locked.isUnlocked, isTrue);
      expect(secure['hive_master_key'], key);
    },
  );

  test('throttles repeated wrong PIN attempts', () async {
    final first = SettingsStorage();
    await first.init();
    await first.setPin('1234');
    await Hive.close();

    final locked = SettingsStorage();
    await locked.init();

    for (var i = 0; i < 5; i++) {
      expect(await locked.unlockWithPin('0000'), isFalse);
    }
    expect(locked.pinLockoutRemaining, greaterThan(Duration.zero));
    expect(await locked.unlockWithPin('1234'), isFalse);
  });

  test('enables and disables biometric protection', () async {
    final storage = SettingsStorage();
    await storage.init();

    expect(await storage.enableBiometricProtection(), isTrue);
    expect(storage.isBiometricEnabled, isTrue);
    expect(secure['biometric_protection_flag'], '1');

    authResult = false;
    expect(await storage.disableBiometricProtection(), isFalse);
    expect(storage.isBiometricEnabled, isTrue);

    authResult = true;
    expect(await storage.disableBiometricProtection(), isTrue);
    expect(storage.isBiometricEnabled, isFalse);
    expect(secure.containsKey('biometric_protection_flag'), isFalse);
  });

  test(
    'biometric unlock succeeds or reports an unavailable platform',
    () async {
      final storage = SettingsStorage();
      await storage.init();
      expect(await storage.enableBiometricProtection(), isTrue);

      authResult = false;
      expect(await storage.attemptUnlock(), isTrue);

      final unsupported = SettingsStorage();
      biometricsAvailable = false;
      expect(
        await unsupported.authenticateWithBiometrics(reason: 'test'),
        isFalse,
      );
    },
  );
}
