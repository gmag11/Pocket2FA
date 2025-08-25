import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum CodeFormat { compact, spaced3, spaced2 }

class SettingsService extends ChangeNotifier {
  static const _key = 'otp_format';
  static const _enabledKey = 'otp_format_enabled';

  CodeFormat _format = CodeFormat.compact;
  CodeFormat get format => _format;

  bool _enabled = true;
  bool get enabled => _enabled;

  SettingsService() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_key) ?? 'compact';
    _format = _fromString(v);
    _enabled = prefs.getBool(_enabledKey) ?? true;
    notifyListeners();
  }

  Future<void> setFormat(CodeFormat f) async {
  _format = f;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_key, _toString(f));
  notifyListeners();
  }

  Future<void> setEnabled(bool on) async {
  _enabled = on;
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
