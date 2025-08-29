import 'package:flutter/material.dart';

/// Maneja la lógica de animaciones para AccountTile
class AccountTileAnimations {
  AnimationController? _animController;
  final TickerProvider vsync;

  AccountTileAnimations({required this.vsync});

  /// Detiene y elimina la animación actual
  void stopAnimation() {
    try {
      _animController?.stop();
    } catch (_) {}
    try {
      _animController?.dispose();
    } catch (_) {}
    _animController = null;
  }

  /// Inicia la animación para un período específico
  void startAnimation(int periodSec) {
    final periodMs = (periodSec > 0 ? periodSec : 30) * 1000;
    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    final remMs = nowMs % periodMs;
    var progress = remMs / periodMs;
    if (progress < 0) progress = 0;
    if (progress > 1) progress = 0;

    // Recrear controller para reflejar posibles cambios de período
    try {
      _animController?.dispose();
    } catch (_) {}
    _animController = AnimationController(
        vsync: vsync, duration: Duration(milliseconds: periodMs));
    // Establecer progreso inicial; animaremos hasta el final y luego repetiremos
    _animController!.value = progress;

    // Capturar controller localmente. Animar hasta el final de este ciclo, luego
    // comenzar a repetir ciclos completos usando repeat(period: ...).
    final ctrl = _animController!;
    final remaining = (periodMs - remMs).clamp(0, periodMs);
    if (remaining == 0) {
      try {
        ctrl.repeat(period: Duration(milliseconds: periodMs));
      } catch (_) {}
    } else {
      try {
        ctrl
            .animateTo(1.0, duration: Duration(milliseconds: remaining))
            .then((_) {
          // Si el controller sigue siendo el activo, comenzar a repetir
          if (identical(ctrl, _animController)) {
            try {
              ctrl.repeat(period: Duration(milliseconds: periodMs));
            } catch (_) {}
          }
        });
      } catch (_) {
        // ignorar
      }
    }
  }

  /// Obtiene el controlador de animación
  AnimationController? get animController => _animController;

  /// Elimina los recursos de animación
  void dispose() {
    stopAnimation();
  }
}