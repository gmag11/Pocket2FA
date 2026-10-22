import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocket2fa/models/account_entry.dart';
import 'package:pocket2fa/services/otp_service.dart';

import '../../helpers/clock.dart';

/// RFC 6238 test vectors (Appendix B), T = 59 seconds.
///
/// The secrets are the ASCII strings from the RFC encoded as Base32:
/// - SHA-1:   "12345678901234567890"
/// - SHA-256: "12345678901234567890123456789012"
/// - SHA-512: "1234567890123456789012345678901234567890123456789012345678901234"
AccountEntry _account({
  required String seed,
  required String algorithm,
  int digits = 8,
  String? otpType = 'totp',
}) => AccountEntry(
  id: 1,
  service: 'RFC',
  account: 'vector',
  seed: seed,
  group: '',
  otpType: otpType,
  algorithm: algorithm,
  digits: digits,
  period: 30,
);

void main() {
  final fixed = utcFromUnixSeconds(59);

  test('TOTP SHA-1 matches the RFC 6238 vector at T=59', () {
    final code = withFixedTime(
      fixed,
      () => OtpService.generateOtp(
        _account(seed: 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ', algorithm: 'sha1'),
      ),
    );

    expect(code, '94287082');
  });

  test('TOTP SHA-256 matches the RFC 6238 vector at T=59', () {
    final code = withFixedTime(
      fixed,
      () => OtpService.generateOtp(
        _account(
          seed: 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZA',
          algorithm: 'sha256',
        ),
      ),
    );

    expect(code, '46119246');
  });

  test('TOTP SHA-512 matches the RFC 6238 vector at T=59', () {
    final code = withFixedTime(
      fixed,
      () => OtpService.generateOtp(
        _account(
          seed:
              'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ'
              'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNA',
          algorithm: 'sha512',
        ),
      ),
    );

    expect(code, '90693936');
  });

  test('TOTP generation is stable for a fixed clock', () {
    String generate() => withFixedTime(
      fixed,
      () => OtpService.generateOtp(
        _account(seed: 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ', algorithm: 'sha1'),
      ),
    );

    expect(generate(), generate());
  });

  test('a future time offset picks the next time step', () {
    final current = withFixedTime(
      utcFromUnixSeconds(60),
      () => OtpService.generateOtp(
        _account(
          seed: 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ',
          algorithm: 'sha1',
          digits: 6,
        ),
      ),
    );

    final offset = withFixedTime(
      utcFromUnixSeconds(60),
      () => OtpService.generateOtp(
        _account(
          seed: 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ',
          algorithm: 'sha1',
          digits: 6,
        ),
        timeOffsetSeconds: 30,
      ),
    );

    expect(offset, isNot(current));
    expect(offset.length, 6);
  });

  group('unsupported types', () {
    test('HOTP returns an empty code', () {
      final code = withFixedTime(
        fixed,
        () => OtpService.generateOtp(
          _account(
            seed: 'GEZDGNBVGY3TQOJQ',
            algorithm: 'sha1',
            otpType: 'hotp',
          ),
        ),
      );

      expect(code, '');
    });

    test('an unknown type returns an empty code', () {
      final code = withFixedTime(
        fixed,
        () => OtpService.generateOtp(
          _account(
            seed: 'GEZDGNBVGY3TQOJQ',
            algorithm: 'sha1',
            otpType: 'motp',
          ),
        ),
      );

      expect(code, '');
    });
  });

  group('secret normalization', () {
    test('a spaced and padded Base32 secret still matches the vector', () {
      final code = withFixedTime(
        fixed,
        () => OtpService.generateOtp(
          _account(
            seed: 'GEZD GNBV GY3T QOJQ GEZD GNBV GY3T QOJQ====',
            algorithm: 'sha1',
          ),
        ),
      );

      expect(code, '94287082');
    });
  });

  group('base32Decode', () {
    test('decodes the RFC secret', () {
      final decoded = OtpService.base32Decode(
        'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ',
      );

      expect(decoded, utf8.encode('12345678901234567890'));
    });

    test('folds case and ignores padding and separators', () {
      final canonical = OtpService.base32Decode('GEZDGNBVGY3TQOJQ');
      final noisy = OtpService.base32Decode('  gezd-gnbv gy3t=qojq==  ');

      expect(noisy, canonical);
    });

    test('returns no bytes for empty or padding-only input', () {
      expect(OtpService.base32Decode(''), isEmpty);
      expect(OtpService.base32Decode('===='), isEmpty);
    });
  });

  group('pow10', () {
    test('handles zero and positive exponents', () {
      expect(OtpService.pow10(0), 1);
      expect(OtpService.pow10(1), 10);
      expect(OtpService.pow10(6), 1000000);
    });
  });

  group('MD5', () {
    test('uses the MD5 HMAC path at the fixed instant', () {
      final code = withFixedTime(
        fixed,
        () => OtpService.generateOtp(
          _account(
            seed: 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ',
            algorithm: 'md5',
            digits: 6,
          ),
        ),
      );

      expect(code, '532013');
      expect(code, hasLength(6));
    });

    test('differs from SHA-1 for the same account and instant', () {
      final md5 = withFixedTime(
        fixed,
        () => OtpService.generateOtp(
          _account(
            seed: 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ',
            algorithm: 'md5',
            digits: 6,
          ),
        ),
      );
      final sha1 = withFixedTime(
        fixed,
        () => OtpService.generateOtp(
          _account(
            seed: 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ',
            algorithm: 'sha1',
            digits: 6,
          ),
        ),
      );

      expect(md5, isNot(sha1));
      expect(sha1, '287082');
    });
  });

  group('Steam TOTP', () {
    const seed = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ';
    const steamCharset = '23456789BCDFGHJKMNPQRTVWXY';
    final account = _account(
      seed: seed,
      algorithm: 'sha1',
      otpType: 'steamtotp',
    );

    test('produces the expected five-character code', () {
      final code = withFixedTime(fixed, () => OtpService.generateOtp(account));

      expect(code, 'PV9M4');
      expect(RegExp('^[$steamCharset]{5}\$').hasMatch(code), isTrue);
    });

    test('matches generateSteamTotp on the decoded secret', () {
      final sharedSecret = base64Encode(OtpService.base32Decode(seed));
      final expected = OtpService.generateSteamTotp(
        sharedSecret,
        forUnixTime: 59,
      );

      final code = withFixedTime(fixed, () => OtpService.generateOtp(account));

      expect(code, expected);
    });

    test('is deterministic and changes with a period offset', () {
      final code = withFixedTime(fixed, () => OtpService.generateOtp(account));
      final again = withFixedTime(fixed, () => OtpService.generateOtp(account));
      final next = withFixedTime(
        fixed,
        () => OtpService.generateOtp(account, timeOffsetSeconds: 30),
      );

      expect(again, code);
      expect(next, isNot(code));
      expect(next, hasLength(5));
    });

    test('uses the current clock when no time is supplied', () {
      final sharedSecret = base64Encode(OtpService.base32Decode(seed));
      final implicit = withFixedTime(
        fixed,
        () => OtpService.generateSteamTotp(sharedSecret),
      );

      expect(implicit, 'PV9M4');
    });

    test('returns empty for empty or invalid Base64 secrets', () {
      expect(OtpService.generateSteamTotp(''), '');
      expect(OtpService.generateSteamTotp('not base64!'), '');
    });
  });
}
