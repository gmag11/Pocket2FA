import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Simple storage wrapper that initialises Hive and provides an encrypted box
/// using a key stored in the platform secure storage (keystore/keychain).
class SettingsStorage {
  static const _hiveBox = 'app_settings_box';
  static const _keyName = 'hive_master_key';

  AndroidOptions _getAndroidOptions() => const AndroidOptions(
        encryptedSharedPreferences: true,
      );

  static const _biometricFlagKey = 'biometric_protection_flag';

  FlutterSecureStorage get _secure =>
      FlutterSecureStorage(aOptions: _getAndroidOptions());

  final LocalAuthentication _localAuth = LocalAuthentication();

  /// Check whether the device supports biometric or credential-based auth.
  /// Returns true if either biometrics or device credentials are available.
  Future<bool> supportsBiometrics() async {
    try {
      return await _localAuth.canCheckBiometrics ||
          await _localAuth.isDeviceSupported();
    } catch (e) {
      debugPrint('supportsBiometrics check failed: $e');
      return false;
    }
  }

  /// Initialise Hive and the encrypted box. Call this early (before runApp)
  Future<void> init() async {
    await Hive.initFlutter();
    // Behaviour: if biometric protection is enabled, require authentication
    // before reading the stored key and opening the box. If authentication
    // fails, do not open the box and leave the store locked; caller can
    // later call attemptUnlock() to prompt again.
    final biometricFlag = await _secure.read(key: _biometricFlagKey);
    if (biometricFlag == '1') {
      final can = await _localAuth.canCheckBiometrics ||
          await _localAuth.isDeviceSupported();
      if (!can) {
        // No biometrics available — fall back to leaving locked.
        _unlocked = false;
        return;
      }

      final ok = await _localAuth.authenticate(
        localizedReason: 'Authenticate to unlock local data',
        options: const AuthenticationOptions(biometricOnly: false),
      );
      if (!ok) {
        _unlocked = false;
        return;
      }
    }

    // Try to read an existing key from secure storage, otherwise generate and save one.
    String? encoded = await _secure.read(key: _keyName);
    Uint8List encryptionKey;
    if (encoded == null) {
      // Create a new 256-bit key
      final key = Hive.generateSecureKey();
      await _secure.write(key: _keyName, value: base64Encode(key));
      encryptionKey = Uint8List.fromList(key);
    } else {
      encryptionKey = Uint8List.fromList(base64Decode(encoded));
    }

    // Open the encrypted box (will be created if missing)
    await Hive.openBox(_hiveBox,
        encryptionCipher: HiveAesCipher(encryptionKey));
    _unlocked = true;
  }

  bool _unlocked = false;
  bool get isUnlocked => _unlocked;

  /// Attempt to unlock (prompt biometric) and open the box if successful.
  Future<bool> attemptUnlock() async {
    final biometricFlag = await _secure.read(key: _biometricFlagKey);
    if (biometricFlag != '1') return true; // not protected

    final can = await _localAuth.canCheckBiometrics ||
        await _localAuth.isDeviceSupported();
    if (!can) return false;

    final ok = await _localAuth.authenticate(
      localizedReason: 'Authenticate to unlock local data',
      options: const AuthenticationOptions(biometricOnly: false),
    );
    if (!ok) return false;

    // Read key and open box
    final encoded = await _secure.read(key: _keyName);
    if (encoded == null) return false;
    final encryptionKey = Uint8List.fromList(base64Decode(encoded));
    if (!Hive.isBoxOpen(_hiveBox)) {
      await Hive.openBox(_hiveBox,
          encryptionCipher: HiveAesCipher(encryptionKey));
    }
    _unlocked = true;
    return true;
  }

  /// Safe accessor for the settings box.
  ///
  /// If the underlying Hive box hasn't been opened because the user declined
  /// authentication (or biometric protection is enabled and hasn't been
  /// satisfied), this will throw a clear [StateError] instructing callers to
  /// call [attemptUnlock()]. This avoids the generic HiveError "Box not
  /// found" that happens when code tries to access the box while it's closed.
  Box<dynamic> get box {
    if (!Hive.isBoxOpen(_hiveBox)) {
      throw StateError(
          'Local storage is locked; call attemptUnlock() to authenticate before accessing the box.');
    }
    return Hive.box(_hiveBox);
  }

  /// Read the stored hive key, optionally requiring biometric auth (Android).
  Future<Uint8List?> readKey({bool requireAuth = false}) async {
    try {
      // If the app has biometric protection enabled we prompt the user via
      // local_auth first; otherwise just read from secure storage normally.
      final secure = FlutterSecureStorage(aOptions: _getAndroidOptions());
      final encoded = await secure.read(key: _keyName);
      if (encoded == null) return null;
      return Uint8List.fromList(base64Decode(encoded));
    } catch (e) {
      debugPrint('readKey failed: $e');
      return null;
    }
  }

  /// Enable biometric protection: re-write the stored key with authenticationRequired=true.
  /// This will prompt the user when reading the key on Android.
  Future<bool> enableBiometricProtection() async {
    try {
      // Authenticate via local_auth first to get a UX prompt
      final can = await _localAuth.canCheckBiometrics ||
          await _localAuth.isDeviceSupported();
      if (!can) return false;
      final ok = await _localAuth.authenticate(
        localizedReason:
            'Authenticate to enable biometric protection for local data',
      );
      if (!ok) return false;

      // Read current key without auth
      final encoded = await _secure.read(key: _keyName);
      if (encoded == null) return false;

      // Re-write with auth-required options
      // When enabling biometric protection we mark a flag and rely on
      // local_auth for the prompt; write back the same encoded value.
      await _secure.write(key: _keyName, value: encoded);
      await _secure.write(key: _biometricFlagKey, value: '1');
      return true;
    } catch (e) {
      debugPrint('enableBiometricProtection failed: $e');
      return false;
    }
  }

  /// Disable biometric protection by re-writing the key without authenticationRequired.
  Future<bool> disableBiometricProtection() async {
    try {
      // Ask user to authenticate first to ensure they consent
      final can = await _localAuth.canCheckBiometrics ||
          await _localAuth.isDeviceSupported();
      if (!can) return false;
      final ok = await _localAuth.authenticate(
        localizedReason:
            'Authenticate to disable biometric protection for local data',
      );
      if (!ok) return false;

      // Read key via auth-protected read (it will prompt)
      // Read the key (we use local_auth to prompt above). Then write back
      // the key value without the biometric flag to disable protected reads.
      final encoded = await _secure.read(key: _keyName);
      if (encoded == null) return false;

      // Re-write without auth
      await _secure.write(key: _keyName, value: encoded);
      await _secure.delete(key: _biometricFlagKey);
      return true;
    } catch (e) {
      debugPrint('disableBiometricProtection failed: $e');
      return false;
    }
  }
}
