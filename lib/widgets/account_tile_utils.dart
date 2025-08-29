import 'package:flutter/material.dart';
import '../services/settings_service.dart';

/// Utilidades y helpers para AccountTile
class AccountTileUtils {
  /// Formatea un código según la configuración
  static String formatCode(String code, SettingsService? settings) {
    // Si el tile muestra un indicador offline, devolverlo literalmente para que
    // no se agrupe/espacie como OTPs numéricos (arregla "off lin e").
    if (code.toLowerCase() == 'offline') return code;

    final digits = code.replaceAll(RegExp(r'\s+'), '');
    // Si el formato está deshabilitado, siempre devolver dígitos compactos
    if (settings != null && settings.enabled == false) return digits;

    final fmt = settings?.format ?? CodeFormat.compact;
    switch (fmt) {
      case CodeFormat.spaced3:
        return _group(digits, [3, 3]);
      case CodeFormat.spaced2:
        return _group(digits, [2, 2, 2]);
      case CodeFormat.compact:
        return digits;
    }
  }

  /// Agrupa una cadena según los patrones especificados
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

  /// Obtiene un color basado en el nombre del servicio
  static Color getServiceColor(String serviceName) {
    final index = serviceName.length % Colors.primaries.length;
    return Colors.primaries[index];
  }
}