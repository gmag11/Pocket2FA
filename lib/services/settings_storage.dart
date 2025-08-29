import 'dart:typed_data';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Simple storage wrapper that initialises Hive and provides an encrypted box
/// using a key stored in the platform secure storage (keystore/keychain).
class SettingsStorage {
  static const _hiveBox = 'app_settings_box';
  static const _keyName = 'hive_master_key';

  AndroidOptions _getAndroidOptions() => const AndroidOptions(
        encryptedSharedPreferences: true,
      );

  FlutterSecureStorage get _secure => FlutterSecureStorage(aOptions: _getAndroidOptions());

  /// Initialise Hive and the encrypted box. Call this early (before runApp)
  Future<void> init() async {
    await Hive.initFlutter();

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
    await Hive.openBox(_hiveBox, encryptionCipher: HiveAesCipher(encryptionKey));
  }

  Box<dynamic> get box => Hive.box(_hiveBox);
}
