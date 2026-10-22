import 'dart:convert';
import 'dart:typed_data';
import 'package:clock/clock.dart';
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

    if (type == 'steamtotp' || type == 'steam') {
      // The original implementation decodes the secret from Base32 and then
      // passes a Base64-encoded binary secret to the Steam TOTP generator.
      // Reproduce that behavior: decode with _decodeSecret and then base64-encode.
      final secretBytes = _decodeSecret(acct.seed);
      final sharedSecretBase64 = base64.encode(secretBytes);
      return generateSteamTotp(sharedSecretBase64,
          forUnixTime: (clock.now().toUtc().millisecondsSinceEpoch ~/ 1000) +
              timeOffsetSeconds);
    }

    return "";
  }

  /// Decodes the account secret as Base32. [base32Decode] ignores spaces,
  /// padding and characters outside the Base32 alphabet.
  static Uint8List _decodeSecret(String secret) => base32Decode(secret);

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

    final ts = ((clock.now().toUtc().millisecondsSinceEpoch ~/ 1000) +
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

  // Implement Steam TOTP generation (5-character codes using Steam charset).
  // Reimplementation of the user's Steam TOTP generator example.
  // Usage: generateSteamTotp(sharedSecretBase64, forUnixTime: unixSeconds)
  static String generateSteamTotp(String sharedSecretBase64,
      {int? forUnixTime}) {
    if (sharedSecretBase64.isEmpty) return '';

    try {
      // 1) Decode the secret (Steam uses base64 for shared_secret).
      final secret = base64.decode(sharedSecretBase64);

      // 2) Compute time counter (step = 30s). Use forUnixTime if provided.
      final unixTime = forUnixTime ??
          (clock.now().toUtc().millisecondsSinceEpoch ~/ 1000);
      final timeStep = 30;
      final counter = unixTime ~/ timeStep;

      // 3) Build 8-byte big-endian buffer with the counter.
      final counterBuf = Uint8List(8);
      final bd = ByteData.view(counterBuf.buffer);
      bd.setUint64(0, counter, Endian.big);

      // 4) HMAC-SHA1(secret, counterBuf)
      final hmac = Hmac(sha1, secret);
      final digest = hmac.convert(counterBuf).bytes;

      // 5) Dynamic truncation (RFC 4226 style)
      final offset = digest[19] & 0x0f;
      final codeInt = ((digest[offset] & 0x7f) << 24) |
          ((digest[offset + 1] & 0xff) << 16) |
          ((digest[offset + 2] & 0xff) << 8) |
          (digest[offset + 3] & 0xff);

      // 6) Steam charset
      const steamCharset = '23456789BCDFGHJKMNPQRTVWXY';
      final base = steamCharset.length; // 26

      // 7) Convert integer to 5 characters using charset
      var value = codeInt;
      final chars = StringBuffer();
      for (var i = 0; i < 5; i++) {
        final idx = value % base;
        chars.write(steamCharset[idx]);
        value = value ~/ base;
      }

      // 8) Return as generated (no reversal)
      return chars.toString();
    } catch (_) {
      return '';
    }
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
}
