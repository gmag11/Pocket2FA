import 'package:flutter_test/flutter_test.dart';
import 'package:pocket2fa/services/otp_service.dart';

void main() {
  test('test harness can import the app and run a pure unit test', () {
    expect(OtpService.pow10(6), 1000000);
    expect(OtpService.base32Decode('JBSWY3DPEHPK3PXP'), isNotEmpty);
  });
}
