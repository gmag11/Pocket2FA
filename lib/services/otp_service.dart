import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import '../models/account_entry.dart';
import '../services/settings_storage.dart';

class OtpService {
  // Generate an OTP for the given account entry and a time offset (in seconds).
  // If timeOffsetSeconds is 0, generate for "now"; for the "next" period pass period seconds.
  static String generateOtp(AccountEntry acct, {int timeOffsetSeconds = 0, SettingsStorage? storage, int? hotpCounterOverride}) {
    final seed = acct.seed;
    final type = (acct.otpType ?? 'totp').toLowerCase();
    final digits = acct.digits ?? 6;
    final alg = (acct.algorithm ?? 'sha1').toLowerCase();
    final period = acct.period ?? 30;

    // Normalize seed: accept Base32 or raw hex/base64. Try base32 first (common for TOTP).
    final key = _decodeSecret(seed);

    if (type == 'hotp') {
      // Prefer the locally persisted HOTP counter. Fallback to server-provided
      // counter (acct.counter) and finally to 0 if none available. An optional
      // hotpCounterOverride can force a specific counter for testing.
  // HOTP is disabled until we implement reliable bidirectional
  // synchronization of counters. Returning a placeholder so the UI can
  // indicate HOTP isn't available.
  return 'HOTP';
    }

    if (type == 'steam') {
      // Steam uses a custom alphabet and HMAC-SHA1 over time//30 like TOTP but output different format
      final ts = ((DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000) + timeOffsetSeconds) ~/ period;
      final code = _steam(key, ts, digits: digits);
      //developer.log('generateOtp id=${acct.id} type=STEAM seed=${_maskSecret(acct.seed)} seedLen=${acct.seed.length} digits=$digits alg=$alg period=$period timeChunk=$ts storage=${storage!=null}', name: 'OtpService');
      return code;
    }

    // Default: TOTP
    final ts = ((DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000) + timeOffsetSeconds) ~/ period;
    final code = _hotp(key, ts, digits: digits, algorithm: alg);
    //developer.log('generateOtp id=${acct.id} type=TOTP seed=${_maskSecret(acct.seed)} seedLen=${acct.seed.length} digits=$digits alg=$alg period=$period timeChunk=$ts storage=${storage!=null}', name: 'OtpService');
    return code;
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
        return Uint8List.fromList(List<int>.generate(cleaned.length ~/ 2, (i) => int.parse(cleaned.substring(i * 2, i * 2 + 2), radix: 16)));
      }
    } catch (_) {}
    // Fallback: utf8 bytes
    return Uint8List.fromList(utf8.encode(s));
  }

  static String _hotp(Uint8List key, int counter, {int digits = 6, String algorithm = 'sha1'}) {
    // 8-byte counter big-endian
    final counterBytes = ByteData(8)..setUint64(0, counter, Endian.big);
    final msg = counterBytes.buffer.asUint8List();

    Hmac hmac;
    switch (algorithm) {
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

  static String _steam(Uint8List key, int ts, {int digits = 5}) {
    // Steam codes are 5 chars from the Steam alphabet (base32-like). We'll implement
    // algorithm as used by Steam: HMAC-SHA1(time) then map 5 bytes -> 5 chars.
    final counterBytes = ByteData(8)..setUint64(0, ts, Endian.big);
    final msg = counterBytes.buffer.asUint8List();
    final hmac = Hmac(sha1, key);
    final digest = hmac.convert(msg).bytes;
    final offset = digest[digest.length - 1] & 0x0f;
    final value = digest.sublist(offset, offset + 4);
    int full = ((value[0] & 0x7f) << 24) |
        ((value[1] & 0xff) << 16) |
        ((value[2] & 0xff) << 8) |
        (value[3] & 0xff);

    const steamChars = '23456789BCDFGHJKMNPQRTVWXY';
    final codeChars = <String>[];
    for (var i = 0; i < 5; i++) {
      final idx = full % steamChars.length;
      codeChars.add(steamChars[idx]);
      full ~/= steamChars.length;
    }
    return codeChars.join();
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

  // HOTP persistence helpers: store per-account counter in the encrypted Hive box
  static int? _getPersistedHotpCounter(String accountId, SettingsStorage? storage) {
    try {
      if (storage == null) return null;
      final box = storage.box;
      final key = 'hotp_counter:$accountId';
      final v = box.get(key);
      if (v == null) return null;
      if (v is int) return v;
      return int.tryParse(v.toString());
    } catch (_) {
      return null;
    }
  }

  // Public getter wrapper
  static int? getPersistedHotpCounter(String accountId, SettingsStorage? storage) => _getPersistedHotpCounter(accountId, storage);

  static Future<int> incrementPersistedHotpCounter(String accountId, SettingsStorage? storage) async {
    if (storage == null) return Future.value(0);
    final box = storage.box;
    final key = 'hotp_counter:$accountId';
    final cur = _getPersistedHotpCounter(accountId, storage) ?? 0;
    final next = cur + 1;
    await box.put(key, next);
    return next;
  }
}
