import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'settings_storage.dart';

enum CodeFormat { compact, spaced3, spaced2 }

class SettingsService extends ChangeNotifier {
  static const _key = 'otp_format';
  static const _enabledKey = 'otp_format_enabled';

  CodeFormat _format = CodeFormat.compact;
  CodeFormat get format => _format;

  bool _enabled = true;
  bool get enabled => _enabled;

  final SettingsStorage? storage;

  SettingsService({this.storage}) {
    _load();
  }

  Future<void> _load() async {
    if (storage != null) {
      final box = storage!.box;
      final v = box.get(_key, defaultValue: 'compact') as String;
      _format = _fromString(v);
      _enabled = box.get(_enabledKey, defaultValue: true) as bool;
      notifyListeners();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_key) ?? 'compact';
    _format = _fromString(v);
    _enabled = prefs.getBool(_enabledKey) ?? true;
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
