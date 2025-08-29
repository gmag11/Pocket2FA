import 'dart:async';
import 'package:flutter/material.dart';
import '../services/otp_service.dart';
import '../services/api_service.dart';
import '../models/account_entry.dart';
import '../services/settings_service.dart';

/// Maneja la lógica de generación y refresco de códigos OTP para AccountTile
class AccountTileOtpService {
  final AccountEntry account;
  final SettingsService? settings;
  final VoidCallback refreshUi;
  final VoidCallback? startAnimationCallback;

  Timer? _timer;
  Timer? _hotpTimer;
  String? _hotpCode;
  int? _hotpCounter;

  AccountTileOtpService({
    required this.account,
    required this.settings,
    required this.refreshUi,
    this.startAnimationCallback,
  });

  /// Código actual OTP
  String currentCode = '------';

  /// Código siguiente OTP
  String nextCode = '------';

  /// Código HOTP transitorio
  String? get hotpCode => _hotpCode;

  /// Contador HOTP
  int? get hotpCounter => _hotpCounter;

  /// Cancela todos los timers
  void dispose() {
    _timer?.cancel();
    _hotpTimer?.cancel();
  }

  /// Refresca los códigos OTP y programa el próximo refresco
  Future<void> refreshCodes() async {
    // compute current and next codes, then schedule next refresh at the
    // period boundary using AccountEntry.period (seconds).
    final acct = account;
    final type = (acct.otpType ?? 'totp').toLowerCase();

    // Cancel any pending timer so we only have one scheduled refresh at a time.
    _timer?.cancel();
    _timer = null;

    if (type == 'steamtotp') {
      // Generate Steam TOTP locally (no network). Use the same generateOtp
      // helper that handles 'steamtotp' via OtpService.
      final c = OtpService.generateOtp(acct,
          timeOffsetSeconds: 0, storage: settings?.storage);
      final period = acct.period ?? 30;
      final n = OtpService.generateOtp(acct,
          timeOffsetSeconds: period, storage: settings?.storage);
      
      currentCode = c;
      nextCode = n;
      refreshUi();

      // Schedule next refresh at epoch-aligned period boundary.
      try {
        final periodSec =
            (acct.period != null && acct.period! > 0) ? acct.period! : 30;
        final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
        final periodMs = periodSec * 1000;
        final remMs = nowMs % periodMs;
        final delayMs = periodMs - remMs;
        _timer = Timer(Duration(milliseconds: delayMs + 50), () {
          refreshCodes();
        });
        // Start per-period animation aligned to epoch
        startAnimationCallback?.call();
      } catch (_) {
        _timer = Timer(const Duration(seconds: 1), () {
          refreshCodes();
        });
      }
      return;
    }

    // current (non-STEAM)
    final c = OtpService.generateOtp(acct,
        timeOffsetSeconds: 0, storage: settings?.storage);
    // next period: use period or default 30
    final period = acct.period ?? 30;
    final n = OtpService.generateOtp(acct,
        timeOffsetSeconds: period, storage: settings?.storage);
    
    currentCode = c;
    nextCode = n;
    refreshUi();

    // Schedule next refresh at the period boundary. Use milliseconds to avoid
    // drift. Add a small epsilon to ensure the code has actually advanced.
    try {
      final periodSec =
          (acct.period != null && acct.period! > 0) ? acct.period! : 30;
      final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
      final periodMs = periodSec * 1000;
      final remMs = nowMs % periodMs;
      final delayMs = periodMs - remMs;
      _timer = Timer(Duration(milliseconds: delayMs + 50), () {
        refreshCodes();
      });
      // Start per-period animation aligned to epoch
      startAnimationCallback?.call();
    } catch (_) {
      // If scheduling fails for any reason, fallback to a conservative 1s tick
      _timer = Timer(const Duration(seconds: 1), () {
        refreshCodes();
      });
    }
  }

  /// Solicita un código HOTP
  Future<void> requestHotp() async {
    try {
      final resp = await ApiService.instance.fetchAccountOtp(account.id);
      final pwd = resp['password']?.toString() ?? '';
      final counter = resp['counter'] is int
          ? resp['counter'] as int
          : (resp['counter'] != null
              ? int.tryParse(resp['counter'].toString())
              : null);
      
      _hotpCode = pwd;
      _hotpCounter = counter;
      refreshUi();

      _hotpTimer?.cancel();
      _hotpTimer = Timer(const Duration(seconds: 30), () {
        _hotpCode = null;
        _hotpCounter = null;
        refreshUi();
      });
    } catch (_) {
      // On error, show 'offline' in the HOTP display area (transient)
      _hotpCode = 'offline';
      _hotpCounter = null;
      refreshUi();

      // Clear the transient offline state after 30s like a successful HOTP
      _hotpTimer?.cancel();
      _hotpTimer = Timer(const Duration(seconds: 30), () {
        _hotpCode = null;
        _hotpCounter = null;
        refreshUi();
      });
    }
  }
}