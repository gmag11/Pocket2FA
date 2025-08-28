import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import '../models/account_entry.dart';
import '../services/settings_storage.dart';

class OtpService {
  // Generate an OTP for the given account entry and a time offset (in seconds).
  // If timeOffsetSeconds is 0, generate for "now"; for the "next" period pass period seconds.
  static String generateOtp(AccountEntry acct,
      {int timeOffsetSeconds = 0,
      SettingsStorage? storage,
      int? hotpCounterOverride}) {
    final type = (acct.otpType ?? 'totp').toLowerCase();

    // if (type == 'hotp') {
    //   return _hotp(acct);
    // }

    // if (type == 'otp') {
    //   return _steam(acct);
    // }

    if (type == 'totp') {
      return _totp(acct,
          timeOffsetSeconds: timeOffsetSeconds, storage: storage);
    }

    return "";
  }

  static Uint8List _decodeSecret(String secret) {
    // Remove spaces and padding
    final s = secret.replaceAll(' ', '').replaceAll('=', '');
    // Try Base32 decode
    try {
      return base32Decode(s);
    } catch (_) {}
    // Try hex
    try {
      final cleaned = s.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
      if (cleaned.length % 2 == 0) {
        return Uint8List.fromList(List<int>.generate(cleaned.length ~/ 2,
            (i) => int.parse(cleaned.substring(i * 2, i * 2 + 2), radix: 16)));
      }
    } catch (_) {}
    // Fallback: utf8 bytes
    return Uint8List.fromList(utf8.encode(s));
  }

  /// Generate a TOTP code for [acct]. This is an independent implementation
  /// (HMAC + dynamic truncation) so it does not share control flow with HOTP
  /// generation. [timeOffsetSeconds] allows testing future/previous time steps.
  static String _totp(AccountEntry acct,
      {int timeOffsetSeconds = 0, SettingsStorage? storage}) {
    final seed = acct.seed;
    final digits = acct.digits ?? 6;
    final alg = (acct.algorithm ?? 'sha1').toLowerCase();
    final period = acct.period ?? 30;

    final key = _decodeSecret(seed);

    final ts = ((DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000) +
            timeOffsetSeconds) ~/
        period;

    // 8-byte big-endian counter (time-step)
    final counterBytes = ByteData(8)..setUint64(0, ts, Endian.big);
    final msg = counterBytes.buffer.asUint8List();

    Hmac hmac;
    switch (alg) {
      case 'sha256':
        hmac = Hmac(sha256, key);
        break;
      case 'sha512':
        hmac = Hmac(sha512, key);
        break;
      case 'md5':
        hmac = Hmac(md5, key);
        break;
      case 'sha1':
      default:
        hmac = Hmac(sha1, key);
    }

    final digest = hmac.convert(msg).bytes;
    final offset = digest[digest.length - 1] & 0x0f;
    final binary = ((digest[offset] & 0x7f) << 24) |
        ((digest[offset + 1] & 0xff) << 16) |
        ((digest[offset + 2] & 0xff) << 8) |
        (digest[offset + 3] & 0xff);

    final otp = binary % (pow10(digits));
    return otp.toString().padLeft(digits, '0');
  }

  // ignore: unused_element
  static String _hotp(AccountEntry acct) {
    // HOTP is disabled — return placeholder so UI can indicate it's unavailable.
    return 'HOTP';
  }

  // ignore: unused_element
  static String _steam(AccountEntry acct) {
    // Steam codes disabled — return placeholder so UI can indicate it's unavailable.
    return 'STEAM';
  }

  static int pow10(int digits) {
    var r = 1;
    for (var i = 0; i < digits; i++) {
      r *= 10;
    }
    return r;
  }

  // Minimal Base32 decode (RFC4648) supporting uppercase/lowercase and no padding
  static Uint8List base32Decode(String input) {
    final alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    final cleaned = input.toUpperCase().replaceAll(RegExp(r'[^A-Z2-7]'), '');
    final output = <int>[];
    var buffer = 0;
    var bitsLeft = 0;
    for (var i = 0; i < cleaned.length; i++) {
      final val = alphabet.indexOf(cleaned[i]);
      if (val < 0) continue;
      buffer = (buffer << 5) | val;
      bitsLeft += 5;
      if (bitsLeft >= 8) {
        bitsLeft -= 8;
        output.add((buffer >> bitsLeft) & 0xFF);
      }
    }
    return Uint8List.fromList(output);
  }

  // // HOTP persistence helpers: store per-account counter in the encrypted Hive box
  // static int? _getPersistedHotpCounter(
  //     String accountId, SettingsStorage? storage) {
  //   try {
  //     if (storage == null) return null;
  //     final box = storage.box;
  //     final key = 'hotp_counter:$accountId';
  //     final v = box.get(key);
  //     if (v == null) return null;
  //     if (v is int) return v;
  //     return int.tryParse(v.toString());
  //   } catch (_) {
  //     return null;
  //   }
  // }

  // // Public getter wrapper
  // static int? getPersistedHotpCounter(
  //         String accountId, SettingsStorage? storage) =>
  //     _getPersistedHotpCounter(accountId, storage);

  // static Future<int> incrementPersistedHotpCounter(
  //     String accountId, SettingsStorage? storage) async {
  //   if (storage == null) return Future.value(0);
  //   final box = storage.box;
  //   final key = 'hotp_counter:$accountId';
  //   final cur = _getPersistedHotpCounter(accountId, storage) ?? 0;
  //   final next = cur + 1;
  //   await box.put(key, next);
  //   return next;
  // }
}
