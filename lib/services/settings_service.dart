import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'settings_storage.dart';

enum CodeFormat { compact, spaced3, spaced2 }

class SettingsService extends ChangeNotifier {
  static const _key = 'otp_format';
  static const _enabledKey = 'otp_format_enabled';
  static const _biometricKey = 'biometric_protection_enabled';
  static const _hideOtpsKey = 'hide_otps_enabled';
  static const _syncOnOpenKey = 'sync_on_home_open';
  static const _autoSyncEnabledKey = 'auto_sync_enabled';
  static const _autoSyncIntervalKey = 'auto_sync_interval_minutes';

  CodeFormat _format = CodeFormat.spaced3;
  CodeFormat get format => _format;

  bool _enabled = true;
  bool get enabled => _enabled;

  final SettingsStorage? storage;
  bool _biometricsSupported = false;
  bool get biometricsSupported => _biometricsSupported;

  SettingsService({this.storage}) {
    _load();
  }

  Future<void> _load() async {
    if (storage != null) {
      // Query support for biometrics once and cache the result for the UI
      _biometricsSupported = await storage!.supportsBiometrics();
      final box = storage!.box;
      final v = box.get(_key, defaultValue: 'spaced3') as String;
      _format = _fromString(v);
      _enabled = box.get(_enabledKey, defaultValue: true) as bool;
      _biometricEnabled = box.get(_biometricKey, defaultValue: false) as bool;
      _hideOtps = box.get(_hideOtpsKey, defaultValue: false) as bool;
  _syncOnOpen = box.get(_syncOnOpenKey, defaultValue: true) as bool;
  _autoSyncEnabled = box.get(_autoSyncEnabledKey, defaultValue: false) as bool;
  _autoSyncIntervalMinutes = box.get(_autoSyncIntervalKey, defaultValue: 30) as int;
      notifyListeners();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_key) ?? 'spaced3';
    _format = _fromString(v);
    _enabled = prefs.getBool(_enabledKey) ?? true;
    _hideOtps = prefs.getBool(_hideOtpsKey) ?? false;
  _syncOnOpen = prefs.getBool(_syncOnOpenKey) ?? true;
  _autoSyncEnabled = prefs.getBool(_autoSyncEnabledKey) ?? false;
  _autoSyncIntervalMinutes = prefs.getInt(_autoSyncIntervalKey) ?? 30;
    notifyListeners();
  }

  Future<void> setFormat(CodeFormat f) async {
    _format = f;
    if (storage != null) {
      final box = storage!.box;
      await box.put(_key, _toString(f));
      notifyListeners();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, _toString(f));
    notifyListeners();
  }

  Future<void> setEnabled(bool on) async {
    _enabled = on;
    if (storage != null) {
      final box = storage!.box;
      await box.put(_enabledKey, on);
      notifyListeners();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, on);
    notifyListeners();
  }

  Future<void> setHideOtps(bool on) async {
    _hideOtps = on;
    if (storage != null) {
      final box = storage!.box;
      await box.put(_hideOtpsKey, on);
      notifyListeners();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hideOtpsKey, on);
    notifyListeners();
  }

  // New: Sync-on-open setting (default: true)
  bool _syncOnOpen = true;
  bool get syncOnOpen => _syncOnOpen;

  Future<void> setSyncOnOpen(bool on) async {
    _syncOnOpen = on;
    if (storage != null) {
      final box = storage!.box;
      await box.put(_syncOnOpenKey, on);
      notifyListeners();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_syncOnOpenKey, on);
    notifyListeners();
  }

  // New: Automatic sync toggle and interval (minutes)
  bool _autoSyncEnabled = false;
  bool get autoSyncEnabled => _autoSyncEnabled;

  int _autoSyncIntervalMinutes = 30;
  int get autoSyncIntervalMinutes => _autoSyncIntervalMinutes;

  Future<void> setAutoSyncEnabled(bool on) async {
    _autoSyncEnabled = on;
    if (storage != null) {
      final box = storage!.box;
      await box.put(_autoSyncEnabledKey, on);
      notifyListeners();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoSyncEnabledKey, on);
    notifyListeners();
  }

  Future<void> setAutoSyncIntervalMinutes(int mins) async {
    if (mins <= 0) return;
    _autoSyncIntervalMinutes = mins;
    if (storage != null) {
      final box = storage!.box;
      await box.put(_autoSyncIntervalKey, mins);
      notifyListeners();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_autoSyncIntervalKey, mins);
    notifyListeners();
  }

  bool _biometricEnabled = false;
  bool get biometricEnabled => _biometricEnabled;

  bool _hideOtps = false;
  bool get hideOtps => _hideOtps;

  /// Toggle biometric protection for local Hive key. This will call into
  /// SettingsStorage to rewrap the key; no data should be lost during toggling.
  Future<bool> setBiometricEnabled(bool on) async {
    if (storage == null) return false;
    final s = storage!;
    bool ok = false;
    if (on) {
      ok = await s.enableBiometricProtection();
    } else {
      ok = await s.disableBiometricProtection();
    }
    if (ok) {
      _biometricEnabled = on;
      await s.box.put(_biometricKey, on);
      notifyListeners();
      return true;
    } else {
      // No change if operation failed.
      notifyListeners();
      return false;
    }
  }

  static String _toString(CodeFormat f) {
    switch (f) {
      case CodeFormat.compact:
        return 'compact';
      case CodeFormat.spaced3:
        return 'spaced3';
      case CodeFormat.spaced2:
        return 'spaced2';
    }
  }

  static CodeFormat _fromString(String s) {
    switch (s) {
      case 'spaced3':
        return CodeFormat.spaced3;
      case 'spaced2':
        return CodeFormat.spaced2;
      case 'compact':
      default:
        return CodeFormat.compact;
    }
  }
}
