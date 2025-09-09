import 'package:flutter/material.dart';
import '../services/settings_service.dart';

/// Utilities and helpers for AccountTile
class AccountTileUtils {
  /// Formats a code according to settings
  static String formatCode(String code, SettingsService? settings,
      {bool forceVisible = false}) {
    // If the tile shows an 'offline' indicator, return it as-is so it
    // is not grouped/spaced like numeric OTPs (fixes "off lin e").
    if (code.toLowerCase() == 'offline') return code;

    final digits = code.replaceAll(RegExp(r'\s+'), '');
    // If formatting is disabled, always return compact digits
    if (settings != null && settings.enabled == false) return digits;

    final fmt = settings?.format ?? CodeFormat.compact;
    String result;
    switch (fmt) {
      case CodeFormat.spaced3:
        result = _group(digits, [3, 3]);
        break;
      case CodeFormat.spaced2:
        result = _group(digits, [2, 2, 2]);
        break;
      case CodeFormat.compact:
        result = digits;
        break;
    }

    // If the user has chosen to hide OTPs and we are not forcing visibility,
    // mask all non-space characters with a bullet while preserving spacing.
    if (!forceVisible && settings != null && settings.hideOtps) {
      return result.replaceAll(RegExp(r'[^\s]'), '•');
    }

    return result;
  }

  /// Groups a string according to the specified patterns
  static String _group(String s, List<int> groups) {
    final parts = <String>[];
    var i = 0;
    for (final g in groups) {
      if (i + g > s.length) break;
      parts.add(s.substring(i, i + g));
      i += g;
    }
    if (i < s.length) parts.add(s.substring(i));
    return parts.join(' ');
  }

  /// Returns a color based on the service name
  static Color getServiceColor(String serviceName) {
    final index = serviceName.length % Colors.primaries.length;
    return Colors.primaries[index];
  }
}
