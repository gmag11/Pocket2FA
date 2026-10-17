// Unit tests for the shared-account OTP fix (GitHub issue #18).
//
// NOTE: these tests are intentionally NOT wired into the build yet. Running
// them requires adding `flutter_test` (sdk: flutter) to `dev_dependencies` in
// pubspec.yaml, which is deliberately out of scope for this change.
//
// Run once the dependency exists with:
//   flutter test test/shared_account_otp_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:pocket2fa/models/account_entry.dart';
import 'package:pocket2fa/services/otp_service.dart';
import 'package:pocket2fa/widgets/account_tile_otp_service.dart';

void main() {
  group('AccountEntry sharing fields', () {
    test('parses is_borrowed and shared_by from the API payload', () {
      final acct = AccountEntry.fromMap({
        'id': 25,
        'service': 'AnotherSite',
        'account': 'jane.doe',
        'secret': '',
        'otp_type': 'totp',
        'period': 30,
        'is_borrowed': true,
        'shared_by': 'Jane',
      });

      expect(acct.isBorrowed, isTrue);
      expect(acct.sharedBy, 'Jane');
      expect(acct.seed, isEmpty);
    });

    test('owned account defaults to not borrowed', () {
      final acct = AccountEntry.fromMap({
        'id': 2,
        'service': 'MySite',
        'account': 'john.doe',
        'secret': 'JBSWY3DPEHPK3PXP',
      });

      expect(acct.isBorrowed, isFalse);
      expect(acct.sharedBy, isNull);
    });

    test('round-trips through toMap/fromMap', () {
      final original = AccountEntry(
        id: 25,
        service: 'AnotherSite',
        account: 'jane.doe',
        seed: '',
        group: '',
        isBorrowed: true,
        sharedBy: 'Jane',
      );

      final restored = AccountEntry.fromMap(original.toMap());
      expect(restored.isBorrowed, isTrue);
      expect(restored.sharedBy, 'Jane');
    });

    test('copyWith preserves sharing fields', () {
      final original = AccountEntry(
        id: 25,
        service: 'AnotherSite',
        account: 'jane.doe',
        seed: '',
        group: '',
        isBorrowed: true,
        sharedBy: 'Jane',
      );

      final copy = original.copyWith(group: 'Work');
      expect(copy.isBorrowed, isTrue);
      expect(copy.sharedBy, 'Jane');
      expect(copy.group, 'Work');
    });
  });

  group('root cause: empty seeds collide', () {
    test('two accounts with empty seeds generate the same local code', () {
      final a =
          AccountEntry(id: 1, service: 'A', account: 'a', seed: '', group: '');
      final b =
          AccountEntry(id: 2, service: 'B', account: 'b', seed: '', group: '');

      expect(OtpService.generateOtp(a), OtpService.generateOtp(b));
    });

    test('distinct seeds generate distinct codes', () {
      final a = AccountEntry(
          id: 1,
          service: 'A',
          account: 'a',
          seed: 'JBSWY3DPEHPK3PXP',
          group: '');
      final b = AccountEntry(
          id: 2,
          service: 'B',
          account: 'b',
          seed: 'KRSXG5CTMVRXEZLU',
          group: '');

      expect(OtpService.generateOtp(a), isNot(OtpService.generateOtp(b)));
    });
  });

  group('AccountTileOtpService routing', () {
    test('borrowed account does not fall back to local generation', () async {
      final acct = AccountEntry(
        id: 42,
        service: 'Shared',
        account: 'jane.doe',
        seed: '',
        group: '',
        isBorrowed: true,
      );
      final svc = AccountTileOtpService(
        account: acct,
        settings: null,
        refreshUi: () {},
      );

      // No server configured in the test environment, so the fetch fails.
      await svc.refreshCodes();

      // The old behaviour produced a wrong (but well-formed) code here.
      expect(svc.currentCode, 'offline');
      svc.dispose();
    });

    test('owned TOTP account is still generated locally', () async {
      final acct = AccountEntry(
        id: 7,
        service: 'Owned',
        account: 'john.doe',
        seed: 'JBSWY3DPEHPK3PXP',
        group: '',
      );
      final svc = AccountTileOtpService(
        account: acct,
        settings: null,
        refreshUi: () {},
      );

      await svc.refreshCodes();

      expect(svc.currentCode, matches(RegExp(r'^\d{6}$')));
      svc.dispose();
    });
  });
}
