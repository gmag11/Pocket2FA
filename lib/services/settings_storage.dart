import 'dart:convert';
import 'dart:io' show Platform, File, Directory;
import 'dart:math' show Random;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'log_service.dart';

/// Minimum number of digits accepted for the app PIN.
const int kPinMinLength = 4;

/// Maximum number of digits accepted for the app PIN.
const int kPinMaxLength = 8;

/// PBKDF2 iteration count used when a PIN is first stored. The count is
/// persisted with the PIN so it can be raised for new installs without
/// invalidating existing ones.
const int kPinDefaultIterations = 50000;

/// Whether [pin] is a valid PIN: 4 to 8 decimal digits and nothing else.
bool isValidPin(String pin) =>
    pin.length >= kPinMinLength &&
    pin.length <= kPinMaxLength &&
    RegExp(r'^[0-9]+$').hasMatch(pin);

/// Derives a key from [pin] with PBKDF2-HMAC-SHA256.
///
/// `crypto` ships HMAC-SHA256 but no PBKDF2 helper, so the (small, well
/// specified) algorithm is implemented here. The salt defeats precomputed
/// tables and [iterations] makes every guess expensive.
List<int> derivePinHash({
  required String pin,
  required List<int> salt,
  required int iterations,
  int keyLength = 32,
}) {
  final hmac = Hmac(sha256, utf8.encode(pin));
  final blocks = (keyLength + 31) ~/ 32;
  final derived = <int>[];

  for (var block = 1; block <= blocks; block++) {
    final blockSalt = <int>[
      ...salt,
      (block >> 24) & 0xff,
      (block >> 16) & 0xff,
      (block >> 8) & 0xff,
      block & 0xff,
    ];
    var u = hmac.convert(blockSalt).bytes;
    final t = List<int>.from(u);
    for (var i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < t.length; j++) {
        t[j] ^= u[j];
      }
    }
    derived.addAll(t);
  }

  return derived.sublist(0, keyLength);
}

/// Compares two byte sequences without short-circuiting on the first mismatch.
bool constantTimeEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var difference = 0;
  for (var i = 0; i < a.length; i++) {
    difference |= a[i] ^ b[i];
  }
  return difference == 0;
}

/// Why the local storage is locked. The UI uses this to show an honest message
/// instead of always blaming biometric authentication (GitHub issue #20).
enum StorageLockReason {
  /// Biometric protection is enabled and supported: a prompt is pending.
  biometricPrompt,

  /// Biometric protection is enabled but this platform has no biometrics.
  biometricUnavailable,

  /// The platform secure storage could not be read (e.g. a keyring failure).
  storageFailure,
}

/// Classifies the locked-storage state from the flags reported by
/// [SettingsStorage].
///
/// A storage failure always wins: it is the one reason that is *not* biometric,
/// and misreporting it as a biometric failure is exactly the bug this guards
/// against.
StorageLockReason classifyStorageLock({
  required bool hasStorageError,
  required bool isBiometricLocked,
  required bool biometricsSupported,
}) {
  if (hasStorageError) return StorageLockReason.storageFailure;
  if (isBiometricLocked && !biometricsSupported) {
    return StorageLockReason.biometricUnavailable;
  }
  return StorageLockReason.biometricPrompt;
}

/// Simple storage wrapper that initialises Hive and provides an encrypted box
/// using a key stored in the platform secure storage (keystore/keychain).
class SettingsStorage {
  static const _hiveBox = 'app_settings_box';
  static const _keyName = 'hive_master_key';

  AndroidOptions _getAndroidOptions() => const AndroidOptions();

  static const _biometricFlagKey = 'biometric_protection_flag';

  static const _pinHashKey = 'pin_hash';
  static const _pinSaltKey = 'pin_salt';
  static const _pinIterationsKey = 'pin_iterations';
  static const _pinLengthKey = 'pin_length';

  /// Failed PIN attempts tolerated before a delay is applied.
  static const _pinFreeAttempts = 5;

  /// First throttle delay, doubled for every further failure.
  static const _pinBaseDelaySeconds = 30;

  /// Upper bound for the throttle delay.
  static const _pinMaxDelaySeconds = 300;

  FlutterSecureStorage get _secure =>
      FlutterSecureStorage(aOptions: _getAndroidOptions());

  final LocalAuthentication _localAuth = LocalAuthentication();

  /// Check whether the device supports biometric or credential-based auth.
  /// Returns true if either biometrics or device credentials are available.
  ///
  /// On platforms without a biometric implementation (e.g. Linux) the plugin
  /// channel is missing and throws a [MissingPluginException]; that is reported
  /// as "not supported" rather than being treated as a storage failure.
  Future<bool> supportsBiometrics() => _biometricsAvailable();

  Future<bool> _biometricsAvailable() async {
    try {
      return await _localAuth.canCheckBiometrics ||
          await _localAuth.isDeviceSupported();
    } catch (e) {
      debugPrint('SettingsStorage: biometric support check failed: $e');
      return false;
    }
  }

  /// Show the platform biometric prompt.
  ///
  /// Cancellation and platform errors are reported as a failed verification
  /// rather than propagating: `local_auth` may throw (for example
  /// `auth_in_progress` or `auth_canceled`) instead of returning false, and an
  /// uncaught error used to leave the lock screen stuck on its biometric state.
  Future<bool> _promptBiometric(String reason) async {
    try {
      return await _localAuth.authenticate(localizedReason: reason);
    } catch (e) {
      debugPrint('SettingsStorage: biometric prompt failed: $e');
      return false;
    }
  }

  /// Initialise Hive and the encrypted box. Call this early (before runApp)
  Future<void> init() async {
    // Store the Hive data in a per-app, always-writable location instead of the
    // user's Documents folder. On desktop, Hive.initFlutter() would default to
    // getApplicationDocumentsDirectory(), which can be redirected to a network
    // share (e.g. an SMB-mapped drive) that the process cannot write to,
    // producing "Access is denied" errors. getApplicationSupportDirectory()
    // resolves to %APPDATA%\<app> on Windows and ~/.local/share/<app> on Linux.
    if (!kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
      final supportDir = await getApplicationSupportDirectory();
      // One-time migration: if a box already exists in the legacy Documents
      // location (used by previous versions on Windows/macOS), copy it over so
      // existing users don't lose their servers and settings.
      await _migrateLegacyBoxIfNeeded(supportDir);
      Hive.init(supportDir.path);
    } else {
      await Hive.initFlutter();
    }
    // Behaviour: if biometric protection is enabled, require authentication
    // before reading the stored key and opening the box. Any failure (secure
    // storage/keyring read, an unavailable biometric plugin, or opening the
    // box) is recorded by [_openSecureStorage] so the UI can show the real
    // cause and offer a retry that can actually succeed.
    await _openSecureStorage();
  }

  /// Read the secure values, satisfy biometric protection when it is enabled,
  /// and open the encrypted box.
  ///
  /// Never throws: a failure leaves the store locked and is classified as
  /// either a pending biometric prompt ([isBiometricLocked]) or a secure-storage
  /// error ([storageError]). This is shared by [init] and [attemptUnlock] so a
  /// failure at startup can be retried from the unlock screen.
  Future<bool> _openSecureStorage() async {
    _storageError = null;
    _biometricLocked = false;
    _pinLocked = false;
    try {
      // Read both the biometric flag and the encryption key in a single
      // platform-channel round trip instead of two sequential reads. Each
      // flutter_secure_storage call has fixed overhead on Android
      // (EncryptedSharedPreferences / Keystore cipher init), so halving the
      // number of calls measurably helps cold-start latency there.
      final secureStopwatch = Stopwatch()..start();
      final secureValues = await _secure.readAll();
      LogService.instance.info(
          'SettingsStorage.init: secure storage readAll took '
          '${secureStopwatch.elapsedMilliseconds}ms',
          name: 'SettingsStorage');
      final biometricFlag = secureValues[_biometricFlagKey];
      _biometricEnabled = biometricFlag == '1';

      // PIN material is read here (before the encrypted box) so the lock
      // screen knows whether a PIN is configured and how many digits it has.
      final pinHash = secureValues[_pinHashKey];
      _pinEnabled = pinHash != null && pinHash.isNotEmpty;
      _pinLength = int.tryParse(secureValues[_pinLengthKey] ?? '');
      _pinIterations =
          int.tryParse(secureValues[_pinIterationsKey] ?? '') ??
              kPinDefaultIterations;

      // When a PIN is configured, authentication (PIN or biometric) is owned
      // by the lock screen, which releases the key through [unlockWithPin] or
      // [attemptUnlock]; do not prompt here.
      if (_pinEnabled) {
        _unlocked = false;
        _pinLocked = true;
        return false;
      }

      if (biometricFlag == '1') {
        _biometricLocked = true;
        if (!await _biometricsAvailable()) {
          // No biometrics available — leave locked but not as a storage error.
          _unlocked = false;
          return false;
        }

        final ok = await _promptBiometric(
          'Authenticate to unlock local data',
        );
        if (!ok) {
          _unlocked = false;
          return false;
        }
      }

      return await _openBoxWithEncodedKey(secureValues[_keyName]);
    } catch (e, stack) {
      _recordStorageFailure(e, stack);
      return false;
    }
  }

  /// Read the master key from secure storage and open the encrypted box.
  ///
  /// Only call this after the PIN or biometric gate has been satisfied.
  Future<bool> _releaseKeyAndOpenBox() async {
    try {
      final encoded = await _secure.read(key: _keyName);
      return await _openBoxWithEncodedKey(encoded);
    } catch (e, stack) {
      _recordStorageFailure(e, stack);
      return false;
    }
  }

  /// Open the encrypted Hive box with [encoded] (a base64 encryption key), or
  /// generate and persist a new key when none is stored yet.
  Future<bool> _openBoxWithEncodedKey(String? encoded) async {
    try {
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
      final boxStopwatch = Stopwatch()..start();
      await Hive.openBox(_hiveBox,
          encryptionCipher: HiveAesCipher(encryptionKey));
      LogService.instance.info(
          'SettingsStorage.init: Hive.openBox took '
          '${boxStopwatch.elapsedMilliseconds}ms',
          name: 'SettingsStorage');
      _unlocked = true;
      _biometricLocked = false;
      _pinLocked = false;
      _storageError = null;
      return true;
    } catch (e, stack) {
      _recordStorageFailure(e, stack);
      return false;
    }
  }

  /// Record a failure to read secure storage or open the box, leaving the
  /// store locked and the reason available to the UI.
  void _recordStorageFailure(Object e, StackTrace stack) {
    debugPrint('SettingsStorage.init: failed to initialise storage: $e');
    _unlocked = false;
    _biometricLocked = false;
    _storageError = e.toString();
    // The debug-logging preference lives in the storage that just failed, so
    // it cannot be read. Force capture on so this failure (and any retry)
    // stays inspectable in the in-app debug log.
    LogService.instance.forceCapture = true;
    LogService.instance.error(
        'SettingsStorage: failed to read secure storage: $e\n$stack',
        name: 'SettingsStorage');
  }

  /// Copy an existing Hive box from the legacy Documents-based location into
  /// [supportDir] when no box exists there yet. This preserves data for users
  /// upgrading from versions that stored the box in the Documents folder.
  /// Any failure (e.g. the legacy location is on an unreadable network share)
  /// is ignored so the app can continue with a fresh box.
  Future<void> _migrateLegacyBoxIfNeeded(Directory supportDir) async {
    try {
      final sep = Platform.pathSeparator;
      final newBox = File('${supportDir.path}$sep$_hiveBox.hive');
      if (await newBox.exists()) return; // already migrated or already in use

      final docsDir = await getApplicationDocumentsDirectory();
      final oldBox = File('${docsDir.path}$sep$_hiveBox.hive');
      if (!await oldBox.exists()) return; // nothing to migrate

      await supportDir.create(recursive: true);
      await oldBox.copy(newBox.path);
      debugPrint(
          'SettingsStorage.init: migrated legacy box from ${oldBox.path} to ${newBox.path}');
    } catch (e) {
      debugPrint('SettingsStorage.init: legacy box migration skipped: $e');
    }
  }

  bool _unlocked = false;
  bool get isUnlocked => _unlocked;

  /// True while the app is waiting for a biometric prompt that is enabled and
  /// supported. Distinguishes a pending prompt from an actual failure.
  bool _biometricLocked = false;
  bool get isBiometricLocked => _biometricLocked;

  /// Description of the last secure-storage failure, or null when none has been
  /// recorded. Set whenever reading the platform secure storage or opening the
  /// encrypted box fails, so the UI can show the real cause instead of a
  /// biometric message.
  String? _storageError;
  String? get storageError => _storageError;
  bool get hasStorageError => _storageError != null;

  /// True when a PIN hash is stored, i.e. the PIN lock is enabled. Derived
  /// from the secure storage read in [_openSecureStorage].
  bool _pinEnabled = false;
  bool get isPinEnabled => _pinEnabled;

  /// Number of digits of the configured PIN, or null when no PIN is set.
  int? _pinLength;
  int? get pinLength => _pinLength;

  /// PBKDF2 iteration count persisted with the PIN (so it can be raised for
  /// new PINs without invalidating existing ones).
  int _pinIterations = kPinDefaultIterations;

  /// True while the app is waiting for the PIN lock screen to authenticate.
  bool _pinLocked = false;
  bool get isPinLocked => _pinLocked;

  /// Whether biometric protection is enabled. Read from secure storage so it
  /// is available before the encrypted box (and its settings) is unlocked.
  bool _biometricEnabled = false;
  bool get isBiometricEnabled => _biometricEnabled;

  /// Consecutive failed unlock attempts and the end of the current throttle
  /// window. Kept in memory: restarting the app clears them, like the design.
  int _failedPinAttempts = 0;
  DateTime? _pinLockoutUntil;

  /// Remaining throttle time before another PIN attempt is accepted.
  Duration get pinLockoutRemaining {
    final until = _pinLockoutUntil;
    if (until == null) return Duration.zero;
    final remaining = until.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Attempt to unlock by (re-)reading the secure storage and opening the box,
  /// prompting for biometric authentication when protection is enabled and
  /// supported. Returns true once the box is open.
  ///
  /// When a PIN is configured, the PIN itself is required through
  /// [unlockWithPin]; this method only succeeds through biometrics (when those
  /// are also enabled) so it can never bypass the PIN. Unlike the one-shot
  /// startup path, this can be called repeatedly from the unlock screen so a
  /// failure at startup is not a dead end.
  Future<bool> attemptUnlock() async {
    if (_unlocked) return true;
    if (!_pinEnabled) return _openSecureStorage();

    // PIN lock active: the only factor this path accepts is biometrics.
    if (!_biometricEnabled) return false;
    if (!await _biometricsAvailable()) return false;
    final ok = await _promptBiometric('Authenticate to unlock local data');
    if (!ok) return false;
    return _releaseKeyAndOpenBox();
  }

  /// Prompt for biometric verification. Returns false when biometrics are not
  /// available or the prompt fails/is cancelled.
  Future<bool> authenticateWithBiometrics({required String reason}) async {
    if (!await _biometricsAvailable()) return false;
    return _promptBiometric(reason);
  }

  /// Whether a PIN is configured. Reads secure storage, so it also works
  /// before the encrypted box is unlocked.
  Future<bool> hasPin() async {
    try {
      final hash = await _secure.read(key: _pinHashKey);
      final enabled = hash != null && hash.isNotEmpty;
      _pinEnabled = enabled;
      return enabled;
    } catch (e) {
      debugPrint('SettingsStorage: failed to check PIN: $e');
      return _pinEnabled;
    }
  }

  /// Store a new PIN. Only the salt, iteration count, digit count and derived
  /// hash are persisted; the raw PIN never touches storage.
  ///
  /// Returns false when [pin] is not 4–8 digits.
  Future<bool> setPin(String pin) async {
    if (!isValidPin(pin)) return false;
    try {
      final random = Random.secure();
      final salt = List<int>.generate(16, (_) => random.nextInt(256));
      final iterations =
          _pinIterations >= 1000 ? _pinIterations : kPinDefaultIterations;
      final hash =
          derivePinHash(pin: pin, salt: salt, iterations: iterations);

      // Write the material needed to verify the hash before the hash itself,
      // so an interrupted write can never leave an unverifiable PIN behind.
      await _secure.write(key: _pinSaltKey, value: base64Encode(salt));
      await _secure.write(key: _pinIterationsKey, value: iterations.toString());
      await _secure.write(key: _pinLengthKey, value: pin.length.toString());
      await _secure.write(key: _pinHashKey, value: base64Encode(hash));

      _pinEnabled = true;
      _pinLength = pin.length;
      _pinIterations = iterations;
      _pinLocked = false;
      _resetPinAttempts();
      return true;
    } catch (e) {
      debugPrint('SettingsStorage: failed to store PIN: $e');
      return false;
    }
  }

  /// Verify [pin] against the stored salted hash in constant time.
  Future<bool> verifyPin(String pin) async {
    try {
      final values = await _secure.readAll();
      final encodedHash = values[_pinHashKey];
      final encodedSalt = values[_pinSaltKey];
      if (encodedHash == null || encodedSalt == null) return false;

      final expected = base64Decode(encodedHash);
      final salt = base64Decode(encodedSalt);
      final iterations =
          int.tryParse(values[_pinIterationsKey] ?? '') ?? kPinDefaultIterations;
      final actual = derivePinHash(
        pin: pin,
        salt: salt,
        iterations: iterations,
        keyLength: expected.length,
      );
      return constantTimeEquals(actual, expected);
    } catch (e) {
      debugPrint('SettingsStorage: failed to verify PIN: $e');
      return false;
    }
  }

  /// Verify [pin] and, on success, release the Hive key and open the box.
  ///
  /// Repeated failures are throttled with a growing delay (see
  /// [pinLockoutRemaining]); a success resets the counter.
  Future<bool> unlockWithPin(String pin) async {
    if (_unlocked) return true;
    if (!_pinEnabled) return false;
    if (pinLockoutRemaining > Duration.zero) return false;

    if (!await verifyPin(pin)) {
      _registerFailedPinAttempt();
      return false;
    }

    _resetPinAttempts();
    return _releaseKeyAndOpenBox();
  }

  /// Remove the stored PIN material, disabling the PIN lock.
  Future<bool> clearPin() async {
    try {
      await _secure.delete(key: _pinHashKey);
      await _secure.delete(key: _pinSaltKey);
      await _secure.delete(key: _pinIterationsKey);
      await _secure.delete(key: _pinLengthKey);
      _pinEnabled = false;
      _pinLength = null;
      _pinLocked = false;
      _resetPinAttempts();
      return true;
    } catch (e) {
      debugPrint('SettingsStorage: failed to clear PIN: $e');
      return false;
    }
  }

  void _registerFailedPinAttempt() {
    _failedPinAttempts++;
    if (_failedPinAttempts < _pinFreeAttempts) return;

    final exponent = (_failedPinAttempts - _pinFreeAttempts).clamp(0, 10);
    final seconds = _pinBaseDelaySeconds * (1 << exponent);
    final capped =
        seconds > _pinMaxDelaySeconds ? _pinMaxDelaySeconds : seconds;
    _pinLockoutUntil = DateTime.now().add(Duration(seconds: capped));
  }

  void _resetPinAttempts() {
    _failedPinAttempts = 0;
    _pinLockoutUntil = null;
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
      _biometricEnabled = true;
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
      _biometricEnabled = false;
      return true;
    } catch (e) {
      debugPrint('disableBiometricProtection failed: $e');
      return false;
    }
  }
}
