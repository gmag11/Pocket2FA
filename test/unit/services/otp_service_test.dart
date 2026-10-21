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
}) =>
    AccountEntry(
      id: 1,
      service: 'RFC',
      account: 'vector',
      seed: seed,
      group: '',
      otpType: 'totp',
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
          seed: 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ'
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
            _account(
              seed: 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ',
              algorithm: 'sha1',
            ),
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
}
