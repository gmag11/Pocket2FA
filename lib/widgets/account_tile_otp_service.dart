import 'dart:async';
import 'package:flutter/material.dart';
import '../services/otp_service.dart';
import '../services/api_service.dart';
import '../models/account_entry.dart';
import '../services/settings_service.dart';

/// Manages generation and refresh logic for OTP codes used by AccountTile
class AccountTileOtpService {
  final AccountEntry account;
  final SettingsService? settings;
  final VoidCallback refreshUi;
  final VoidCallback? startAnimationCallback;

  Timer? _timer;
  Timer? _hotpTimer;
  String? _hotpCode;
  int? _hotpCounter;
  bool _disposed = false;

  AccountTileOtpService({
    required this.account,
    required this.settings,
    required this.refreshUi,
    this.startAnimationCallback,
  });

  /// Current OTP code
  String currentCode = '------';

  /// Next OTP code
  String nextCode = '------';

  /// Transient HOTP code
  String? get hotpCode => _hotpCode;

  /// HOTP counter
  int? get hotpCounter => _hotpCounter;

  /// Cancels all timers
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _hotpTimer?.cancel();
  }

  /// Whether this account's code must be obtained from the server because its
  /// secret is not available locally (accounts shared with the user by another
  /// user of the same instance). HOTP is excluded: it already uses the manual
  /// server-backed flow in [requestHotp].
  bool get _requiresServerCode {
    final type = (account.otpType ?? 'totp').toLowerCase();
    if (type == 'hotp') return false;
    return account.isBorrowed || account.seed.trim().isEmpty;
  }

  /// Refreshes OTP codes and schedules the next refresh
  Future<void> refreshCodes() async {
    // Compute current and next codes, then schedule next refresh at the
    // period boundary using AccountEntry.period (seconds).
    final acct = account;
    final type = (acct.otpType ?? 'totp').toLowerCase();

    // Cancel any pending timer so we only have one scheduled refresh at a time.
    _timer?.cancel();
    _timer = null;

    // Accounts shared with the user have no local secret: fetching the code
    // from the server is the only way to show the correct value.
    if (_requiresServerCode) {
      await _refreshFromServer();
      return;
    }

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

  /// Fetches the current (and next) code from the server for an account whose
  /// secret is not available locally, then schedules the next fetch aligned to
  /// the server-reported period.
  Future<void> _refreshFromServer() async {
    if (_disposed) return;

    // Without a valid server id we cannot ask the server for a code. Never
    // fall back to local generation: the seed is empty and would produce a
    // wrong code shared by every account.
    if (account.id <= 0) {
      _setOffline();
      _scheduleRetry();
      return;
    }

    try {
      final resp = await ApiService.instance.fetchAccountOtp(account.id);
      if (_disposed) return;

      final pwd = resp['password']?.toString() ?? '';
      if (pwd.isEmpty) {
        _setOffline();
        _scheduleRetry();
        return;
      }

      final next = resp['next_password']?.toString();
      currentCode = pwd;
      nextCode = (next != null && next.isNotEmpty) ? next : '------';
      refreshUi();

      _scheduleServerRefresh(_periodFromResponse(resp), resp['generated_at']);
      startAnimationCallback?.call();
    } catch (_) {
      if (_disposed) return;
      _setOffline();
      _scheduleRetry();
    }
  }

  int _periodFromResponse(Map<String, dynamic> resp) {
    final fromServer = resp['period'];
    if (fromServer is int && fromServer > 0) return fromServer;
    final local = account.period;
    if (local != null && local > 0) return local;
    return 30;
  }

  void _setOffline() {
    // Sentinel understood by the tile UI and copy handlers; deliberately not a
    // computable code.
    currentCode = 'offline';
    nextCode = '';
    refreshUi();
  }

  void _scheduleServerRefresh(int periodSec, Object? generatedAt) {
    if (_disposed) return;
    var delayMs = periodSec * 1000;
    // Prefer the server-reported boundary (generation time + period). Fall back
    // to the epoch-aligned boundary when the computed delay is not plausible
    // (e.g. client clock skew).
    if (generatedAt is int) {
      final nowS = DateTime.now().millisecondsSinceEpoch / 1000.0;
      final targetS = generatedAt + periodSec;
      final candidateMs = ((targetS - nowS) * 1000).round();
      if (candidateMs > 0 && candidateMs <= periodSec * 2000) {
        delayMs = candidateMs;
      }
    }
    // Small epsilon so the server has advanced past the boundary.
    _timer = Timer(Duration(milliseconds: delayMs + 250), () {
      if (!_disposed) refreshCodes();
    });
  }

  void _scheduleRetry() {
    if (_disposed) return;
    _timer = Timer(const Duration(seconds: 30), () {
      if (!_disposed) refreshCodes();
    });
  }

  /// Requests a HOTP code from the server
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
